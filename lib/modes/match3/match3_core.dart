/// match3_core.dart — pure-ядро режима «Match-3 PvP» (поле 8×8, Model-слой).
///
/// За что отвечает файл:
///   Классическая логика «три в ряд» на сетке цветов 8×8 (ROADMAP § 5.5):
///   генерация стартового поля без готовых серий, поиск совпадений (≥3 в ряд по
///   горизонтали/вертикали), проверка легальности свопа (своп разрешён, только
///   если создаёт серию), разрешение хода с каскадами (очистка → гравитация →
///   досыпка сверху → повтор), подсчёт очков с бонусом за каскады и проверка
///   наличия ходов. Случайность — только через [makeRng] от seed (детерминизм).
///
/// Чистота: без UI/IO/DateTime; сетка — `List<List<int>>`, цвет = индекс
/// 0..[match3Colors)-1, временно -1 при гравитации. Режим не зеркалится в TS.
///
/// Соответствие ROADMAP: § 5.5 (Match-3 PvP, turn-based 8×8).
library;

import 'package:block_duel/core/core.dart';

/// Сторона поля (8×8).
const int match3Size = 8;

/// Число цветов «леденцов».
const int match3Colors = 6;

/// Очки за одну очищенную клетку (до каскад-бонуса).
const int match3CellPoints = 10;

/// Сетка цветов: `grid[r][c]` = индекс цвета (0..[match3Colors)) или -1 (пусто).
typedef Match3Grid = List<List<int>>;

/// Координата клетки сетки `(r, c)`.
typedef Cellxy = ({int r, int c});

/// Глубокая копия сетки.
Match3Grid cloneGrid(Match3Grid grid) => [for (final row in grid) [...row]];

/// Создаёт стартовую сетку 8×8 без готовых серий (любой ход потом легален лишь
/// если создаёт серию). Детерминирована от [seed].
Match3Grid generateMatch3Grid(int seed) {
  final rng = makeRng(seed);
  final grid = [
    for (int r = 0; r < match3Size; r++)
      [for (int c = 0; c < match3Size; c++) -1],
  ];
  for (int r = 0; r < match3Size; r++) {
    for (int c = 0; c < match3Size; c++) {
      int color;
      var guard = 0;
      do {
        color = (rng() * match3Colors).floor();
        guard++;
      } while (guard < 50 && _makesRunAt(grid, r, c, color));
      grid[r][c] = color;
    }
  }
  return grid;
}

/// Создал бы цвет [color] в `(r, c)` серию из 3+ с уже заполненными соседями
/// слева/сверху (используется при генерации, чтобы не было стартовых серий).
bool _makesRunAt(Match3Grid grid, int r, int c, int color) {
  if (c >= 2 && grid[r][c - 1] == color && grid[r][c - 2] == color) return true;
  if (r >= 2 && grid[r - 1][c] == color && grid[r - 2][c] == color) return true;
  return false;
}

/// Соседние ли клетки (по стороне).
bool areAdjacent(Cellxy a, Cellxy b) =>
    (a.r == b.r && (a.c - b.c).abs() == 1) ||
    (a.c == b.c && (a.r - b.r).abs() == 1);

/// Множество клеток, входящих в любую серию ≥3 (горизонталь/вертикаль).
Set<Cellxy> findMatches(Match3Grid grid) {
  final matched = <Cellxy>{};
  // Горизонтальные серии.
  for (int r = 0; r < match3Size; r++) {
    int runStart = 0;
    for (int c = 1; c <= match3Size; c++) {
      final same = c < match3Size &&
          grid[r][c] != -1 &&
          grid[r][c] == grid[r][runStart];
      if (!same) {
        if (c - runStart >= 3) {
          for (int k = runStart; k < c; k++) {
            matched.add((r: r, c: k));
          }
        }
        runStart = c;
      }
    }
  }
  // Вертикальные серии.
  for (int c = 0; c < match3Size; c++) {
    int runStart = 0;
    for (int r = 1; r <= match3Size; r++) {
      final same = r < match3Size &&
          grid[r][c] != -1 &&
          grid[r][c] == grid[runStart][c];
      if (!same) {
        if (r - runStart >= 3) {
          for (int k = runStart; k < r; k++) {
            matched.add((r: k, c: c));
          }
        }
        runStart = r;
      }
    }
  }
  return matched;
}

/// Меняет местами две клетки сетки (мутирует).
void swapCells(Match3Grid grid, Cellxy a, Cellxy b) {
  final tmp = grid[a.r][a.c];
  grid[a.r][a.c] = grid[b.r][b.c];
  grid[b.r][b.c] = tmp;
}

/// Создаёт ли своп соседних [a] и [b] хотя бы одну серию (легален ли ход).
bool wouldMatch(Match3Grid grid, Cellxy a, Cellxy b) {
  if (!areAdjacent(a, b)) return false;
  final g = cloneGrid(grid);
  swapCells(g, a, b);
  return findMatches(g).isNotEmpty;
}

/// Результат разрешения хода: сколько клеток очищено всего и за сколько каскадов.
class Match3Resolve {
  /// Всего очищено клеток за все каскады хода.
  final int clearedCells;

  /// Число каскадов (волн очистки) — для бонуса.
  final int cascades;

  /// Начисленные очки.
  final int score;

  /// Создаёт результат.
  const Match3Resolve({
    required this.clearedCells,
    required this.cascades,
    required this.score,
  });
}

/// Верхний предохранитель числа каскадов в одном [resolveBoard]: досыпка кладёт
/// случайные цвета, которые сами могут дать серию, поэтому теоретически цикл мог
/// бы не завершиться. На практике каскады затухают за единицы итераций; предел
/// заведомо недостижим в нормальной игре и лишь гарантирует завершение.
const int _maxCascades = 128;

/// Разрешает поле после свопа: пока есть серии — очищает их, роняет столбцы
/// (гравитация) и досыпает новые цвета сверху из [rng], считая каскады.
/// Мутирует [grid]. Возвращает суммарную очистку и очки.
Match3Resolve resolveBoard(Match3Grid grid, RandomSource rng) {
  var totalCleared = 0;
  var cascades = 0;
  var score = 0;
  while (cascades < _maxCascades) {
    final matches = findMatches(grid);
    if (matches.isEmpty) break;
    cascades++;
    totalCleared += matches.length;
    // Очки: клетки × база × множитель каскада (1, 1.5, 2, …).
    final cascadeMult = 1.0 + 0.5 * (cascades - 1);
    score += (matches.length * match3CellPoints * cascadeMult).round();
    for (final m in matches) {
      grid[m.r][m.c] = -1;
    }
    _applyGravity(grid, rng);
  }
  return Match3Resolve(
    clearedCells: totalCleared,
    cascades: cascades,
    score: score,
  );
}

/// Роняет непустые клетки вниз в каждом столбце и досыпает новые сверху.
void _applyGravity(Match3Grid grid, RandomSource rng) {
  for (int c = 0; c < match3Size; c++) {
    // Собираем непустые снизу вверх.
    final stack = <int>[];
    for (int r = match3Size - 1; r >= 0; r--) {
      if (grid[r][c] != -1) stack.add(grid[r][c]);
    }
    // Заполняем столбец: низ — уцелевшие, верх — новые цвета.
    for (int r = match3Size - 1, i = 0; r >= 0; r--, i++) {
      grid[r][c] = i < stack.length ? stack[i] : (rng() * match3Colors).floor();
    }
  }
}

/// Есть ли хоть один легальный своп (соседняя пара, создающая серию).
bool hasAnyValidMove(Match3Grid grid) {
  for (int r = 0; r < match3Size; r++) {
    for (int c = 0; c < match3Size; c++) {
      // Достаточно проверить свопы вправо и вниз (покрывают все пары).
      if (c + 1 < match3Size &&
          wouldMatch(grid, (r: r, c: c), (r: r, c: c + 1))) {
        return true;
      }
      if (r + 1 < match3Size &&
          wouldMatch(grid, (r: r, c: c), (r: r + 1, c: c))) {
        return true;
      }
    }
  }
  return false;
}
