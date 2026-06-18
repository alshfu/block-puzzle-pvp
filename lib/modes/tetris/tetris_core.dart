/// tetris_core.dart — pure-ядро режима «Классический Tetris» (Model-слой).
///
/// За что отвечает файл:
///   Классическая механика падающих фигур на поле 10×20: четыре состояния
///   поворота каждой фигуры (через [rotate90] из ядра), проверка/постановка,
///   гравитация на один ряд, мгновенный сброс (hard drop), повороты с
///   wall-kick'ами, очистка ПОЛНЫХ строк со «схлопыванием» стопки вниз (в
///   отличие от Co-op, где строки гасятся на месте), классический счёт за линии
///   и кривая скорости падения по уровню. Всё чистое и детерминированное:
///   набор фигур приходит из засеянного [Bag] (выбор seed — в UI-слое), здесь
///   нет ни таймеров, ни `DateTime`, ни I/O. Темп гравитации (когда делать шаг)
///   — забота ViewModel/Ticker, ядро лишь умеет «шагнуть на ряд вниз».
///
/// Почему отдельный движок (а не Co-op/9×9):
///   у 9×9 — очистка строк/столбцов/боксов без падения; у Co-op — turn-based
///   без гравитации. Классический Tetris — это живое падение + схлопывание
///   стопки, поэтому собственный pure-модуль. Режим НЕ зеркалится в TS и НЕ
///   входит в golden-паритет 9×9.
///
/// Соответствие ROADMAP: Фаза 5 (платформа режимов), новый режим «Tetris».
library;

import 'package:block_duel/core/core.dart';

/// Ширина поля (столбцов) — классические 10.
const int tetrisCols = 10;

/// Высота поля (строк) — классические 20.
const int tetrisRows = 20;

/// Создаёт пустое поле [tetrisRows]×[tetrisCols].
Board emptyTetrisBoard() => [
  for (int r = 0; r < tetrisRows; r++)
    [for (int c = 0; c < tetrisCols; c++) Cell()],
];

/// Глубокая копия поля.
Board cloneTetrisBoard(Board board) => [
  for (final row in board)
    [for (final cell in row) Cell(filled: cell.filled, owner: cell.owner)],
];

/// Индекс цвета фигуры [type] (0..6 в порядке [allTypes]) — кладётся в
/// `Cell.owner`, чтобы View красил клетки в «фирменный» цвет тетромино.
int tetrisColorIndex(PieceType type) => allTypes.indexOf(type);

/// Четыре состояния поворота фигуры [type] (индексы 0..3), полученные
/// последовательным применением [rotate90] к базовой форме и нормализованные к
/// началу координат. Некоторые состояния совпадают (O — все четыре, I/S/Z —
/// попарно), это нормально: поворот всё равно работает, просто визуально
/// идентичен. Кэшируется в [_rotationCache].
List<List<Coord>> tetrisRotationStates(PieceType type) =>
    _rotationCache.putIfAbsent(type, () {
      final states = <List<Coord>>[];
      var cur = normalize(baseShapes[type]!);
      for (int i = 0; i < 4; i++) {
        states.add(cur);
        cur = rotate90(cur);
      }
      return states;
    });

/// Кэш состояний поворота (вычисляются один раз на тип).
final Map<PieceType, List<List<Coord>>> _rotationCache = {};

/// Клетки фигуры [type] в состоянии поворота [rot] (нормализованные, от 0,0).
List<Coord> tetrisCells(PieceType type, int rot) =>
    tetrisRotationStates(type)[rot & 3];

/// Ширина (число столбцов) фигуры [type] в состоянии [rot].
int tetrisPieceWidth(PieceType type, int rot) {
  var maxC = 0;
  for (final cell in tetrisCells(type, rot)) {
    if (cell.c > maxC) maxC = cell.c;
  }
  return maxC + 1;
}

/// Можно ли разместить фигуру [type] в состоянии [rot] с верхним-левым якорем
/// `(r, c)`: все клетки в пределах поля и свободны.
bool tetrisCanPlace(Board board, PieceType type, int rot, int r, int c) {
  for (final cell in tetrisCells(type, rot)) {
    final rr = r + cell.r;
    final cc = c + cell.c;
    if (rr < 0 || rr >= tetrisRows || cc < 0 || cc >= tetrisCols) return false;
    if (board[rr][cc].filled) return false;
  }
  return true;
}

/// Стартовый столбец-якорь для фигуры [type] (состояние 0) — центрирование по
/// ширине поля.
int tetrisSpawnCol(PieceType type) =>
    ((tetrisCols - tetrisPieceWidth(type, 0)) / 2).floor();

/// Смещения wall-kick для попытки поворота: сначала «на месте», затем сдвиги
/// влево/вправо на 1–2 и вверх на 1. Этого достаточно, чтобы фигуры (включая I)
/// уверенно поворачивались у стен и в «колодцах». Каждый кортеж — `(dr, dc)`.
const List<(int, int)> _kickOffsets = [
  (0, 0),
  (0, -1),
  (0, 1),
  (0, -2),
  (0, 2),
  (-1, 0),
  (-1, -1),
  (-1, 1),
];

/// Результат попытки поворота: индекс нового состояния и якорь после kick'а.
/// `null`, если повернуть невозможно ни с одним смещением.
({int rot, int r, int c})? tetrisTryRotate(
  Board board,
  PieceType type,
  int rot,
  int r,
  int c,
  int dir,
) {
  final newRot = (rot + dir) & 3;
  for (final (dr, dc) in _kickOffsets) {
    if (tetrisCanPlace(board, type, newRot, r + dr, c + dc)) {
      return (rot: newRot, r: r + dr, c: c + dc);
    }
  }
  return null;
}

/// На сколько рядов фигура [type]/[rot] упадёт из `(r, c)` до упора (для
/// «призрака» и hard drop). 0 — стоять уже не на чём двигаться вниз.
int tetrisDropDistance(Board board, PieceType type, int rot, int r, int c) {
  var d = 0;
  while (tetrisCanPlace(board, type, rot, r + d + 1, c)) {
    d++;
  }
  return d;
}

/// Ставит фигуру [type]/[rot] на поле с якорем `(r, c)`, крася клетки в цвет
/// фигуры (`owner = tetrisColorIndex`). Мутирует поле.
void tetrisLock(Board board, PieceType type, int rot, int r, int c) {
  final color = tetrisColorIndex(type);
  for (final cell in tetrisCells(type, rot)) {
    board[r + cell.r][c + cell.c] = Cell(filled: true, owner: color);
  }
}

/// Индексы полностью заполненных строк (сверху вниз). Не мутирует поле.
List<int> tetrisFullRows(Board board) {
  final rows = <int>[];
  for (int r = 0; r < tetrisRows; r++) {
    if (board[r].every((cell) => cell.filled)) rows.add(r);
  }
  return rows;
}

/// Очистка полных строк со СХЛОПЫВАНИЕМ стопки: возвращает НОВОЕ поле, в котором
/// заполненные строки удалены, а всё, что было выше, опустилось вниз; сверху
/// добавлены пустые строки. Это классическое поведение Tetris (в отличие от
/// [coopClearRows], гасящего строки на месте). Возвращает поле и число строк.
({Board board, int cleared}) tetrisClearRows(Board board) {
  final kept = <List<Cell>>[];
  for (int r = 0; r < tetrisRows; r++) {
    if (!board[r].every((cell) => cell.filled)) {
      kept.add([
        for (final cell in board[r]) Cell(filled: cell.filled, owner: cell.owner),
      ]);
    }
  }
  final cleared = tetrisRows - kept.length;
  final result = <List<Cell>>[
    for (int i = 0; i < cleared; i++)
      [for (int c = 0; c < tetrisCols; c++) Cell()],
    ...kept,
  ];
  return (board: result, cleared: cleared);
}

/// Очки за очистку [lines] строк одним lock'ом на уровне [level] — классическая
/// таблица (single 100 / double 300 / triple 500 / tetris 800), умноженная на
/// уровень. 0 строк → 0 очков.
int tetrisLineScore(int lines, int level) {
  const base = {0: 0, 1: 100, 2: 300, 3: 500, 4: 800};
  return (base[lines] ?? 800) * level;
}

/// Уровень по суммарно очищенным линиям [totalLines]: +1 за каждые 10 линий,
/// старт с 1.
int tetrisLevelForLines(int totalLines) => 1 + totalLines ~/ 10;

/// Интервал гравитации (секунд на шаг вниз) для уровня [level]: классическая
/// убывающая кривая, зажатая снизу до 0.05 с (максимальный темп).
double tetrisGravitySeconds(int level) {
  final s = 0.80 - (level - 1) * 0.07;
  return s < 0.05 ? 0.05 : s;
}
