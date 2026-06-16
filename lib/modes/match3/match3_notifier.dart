/// match3_notifier.dart — ViewModel матча «Match-3 PvP» (MVVM, ViewModel-слой).
///
/// За что отвечает файл:
///   Turn-based hot-seat «три в ряд» на поле 8×8 поверх pure-ядра
///   (`match3_core.dart`): хранит сетку и детерминированный источник досыпки,
///   принимает тапы по клеткам (выбор → своп соседней), применяет легальный
///   своп с каскадами и начислением очков ходившему, переключает игроков и
///   завершает партию по лимиту ходов (или пере-перемешивает поле без ходов).
///   Без `BuildContext`/виджетов.
///
/// Соответствие ROADMAP: § 5.5 (Match-3 PvP, turn-based 8×8).
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'match3_core.dart';

/// Сколько ходов всего в партии (по [_maxTurns] ~/ 2 на игрока).
const int match3MaxTurns = 12;

/// Неизменяемое состояние матча Match-3.
class Match3State {
  /// Текущая сетка цветов.
  final Match3Grid grid;

  /// Очки игроков (индексы 0/1).
  final List<int> scores;

  /// Чей ход (0/1).
  final int current;

  /// Сделано ходов всего.
  final int turnsPlayed;

  /// Окончена ли партия.
  final bool gameOver;

  /// Победитель (0/1) или `null` (ничья/не окончено).
  final int? winner;

  /// Первая выбранная клетка свопа (или `null`).
  final Cellxy? selected;

  /// Очки за последний ход (для подсветки).
  final int lastGain;

  /// Создаёт состояние.
  const Match3State({
    required this.grid,
    required this.scores,
    required this.current,
    required this.turnsPlayed,
    required this.gameOver,
    required this.winner,
    required this.selected,
    this.lastGain = 0,
  });

  /// Сколько ходов осталось.
  int get turnsLeft => match3MaxTurns - turnsPlayed;

  /// Копия с изменёнными полями.
  Match3State copyWith({
    Match3Grid? grid,
    List<int>? scores,
    int? current,
    int? turnsPlayed,
    bool? gameOver,
    int? winner,
    bool clearWinner = false,
    Cellxy? selected,
    bool clearSelected = false,
    int? lastGain,
  }) => Match3State(
    grid: grid ?? this.grid,
    scores: scores ?? this.scores,
    current: current ?? this.current,
    turnsPlayed: turnsPlayed ?? this.turnsPlayed,
    gameOver: gameOver ?? this.gameOver,
    winner: clearWinner ? null : (winner ?? this.winner),
    selected: clearSelected ? null : (selected ?? this.selected),
    lastGain: lastGain ?? this.lastGain,
  );
}

/// ViewModel матча Match-3.
class Match3Notifier extends Notifier<Match3State> {
  /// Детерминированный источник досыпки (продвигается между ходами).
  late Mulberry32 _rng;

  @override
  Match3State build() => _freshState(0xBADA55);

  // ── Команды View ───────────────────────────────────────────────────────────

  /// Новая партия с заданным [seed].
  void newGame(int seed) => state = _freshState(seed);

  /// Тап по клетке: первый — выбор, второй (соседний легальный) — своп.
  void tapCell(Cellxy cell) {
    if (state.gameOver) return;
    final sel = state.selected;
    if (sel == null) {
      state = state.copyWith(selected: cell);
      return;
    }
    if (sel == cell) {
      state = state.copyWith(clearSelected: true);
      return;
    }
    if (areAdjacent(sel, cell) && wouldMatch(state.grid, sel, cell)) {
      _applySwap(sel, cell);
    } else {
      // Нелегально/далеко — просто переносим выбор на новую клетку.
      state = state.copyWith(selected: cell);
    }
  }

  // ── Внутреннее ──────────────────────────────────────────────────────────────

  /// Выполняет легальный своп: каскады, очки ходившему, смена хода, проверка
  /// конца партии и обновление поля без ходов.
  void _applySwap(Cellxy a, Cellxy b) {
    final cur = state.current;
    final grid = cloneGrid(state.grid);
    swapCells(grid, a, b);
    final res = resolveBoard(grid, _rng.next);

    final scores = [...state.scores];
    scores[cur] += res.score;

    final turnsPlayed = state.turnsPlayed + 1;
    final over = turnsPlayed >= match3MaxTurns;

    // Гарантируем наличие ходов на следующий ход (иначе пере-перемешиваем).
    if (!over && !hasAnyValidMove(grid)) {
      _reshuffle(grid);
    }

    state = Match3State(
      grid: grid,
      scores: scores,
      current: over ? cur : 1 - cur,
      turnsPlayed: turnsPlayed,
      gameOver: over,
      winner: over ? _winnerOf(scores) : null,
      selected: null,
      lastGain: res.score,
    );
  }

  /// Победитель по очкам (или `null` при равенстве).
  int? _winnerOf(List<int> scores) {
    if (scores[0] > scores[1]) return 0;
    if (scores[1] > scores[0]) return 1;
    return null;
  }

  /// Пере-перемешивает поле до состояния «есть серии нет, ход есть» (мутирует).
  void _reshuffle(Match3Grid grid) {
    var guard = 0;
    do {
      // Простая перетасовка: переназначаем цвета из rng, избегая стартовых серий.
      for (int r = 0; r < match3Size; r++) {
        for (int c = 0; c < match3Size; c++) {
          int color;
          var inner = 0;
          do {
            color = (_rng.next() * match3Colors).floor();
            inner++;
          } while (inner < 50 &&
              _wouldStartRun(grid, r, c, color));
          grid[r][c] = color;
        }
      }
      guard++;
    } while (guard < 20 && !hasAnyValidMove(grid));
  }

  /// Образует ли цвет серию с уже расставленными слева/сверху (для reshuffle).
  bool _wouldStartRun(Match3Grid grid, int r, int c, int color) {
    if (c >= 2 && grid[r][c - 1] == color && grid[r][c - 2] == color) {
      return true;
    }
    if (r >= 2 && grid[r - 1][c] == color && grid[r - 2][c] == color) {
      return true;
    }
    return false;
  }

  /// Свежая партия: новая сетка (с гарантией хода) и источник досыпки.
  Match3State _freshState(int seed) {
    _rng = Mulberry32(seed);
    var grid = generateMatch3Grid(seed);
    var attempt = 1;
    while (!hasAnyValidMove(grid) && attempt < 30) {
      grid = generateMatch3Grid(seed + attempt * 7919);
      attempt++;
    }
    return Match3State(
      grid: grid,
      scores: const [0, 0],
      current: 0,
      turnsPlayed: 0,
      gameOver: false,
      winner: null,
      selected: null,
    );
  }
}

/// Провайдер ViewModel матча Match-3.
final match3Provider = NotifierProvider<Match3Notifier, Match3State>(
  Match3Notifier.new,
);
