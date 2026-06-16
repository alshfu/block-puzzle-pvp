/// coop_core.dart — pure-ядро режима «Co-op Tetris» (поле 10×20, Model-слой).
///
/// За что отвечает файл:
///   Логика поля произвольного размера W×H с очисткой ТОЛЬКО полных строк
///   (без столбцов/боксов и без «падения» — pure puzzle, ROADMAP § 5.4). Здесь:
///   создание/копирование поля, проверка и выполнение постановки, поиск и
///   очистка полных строк, подсчёт очков за очистку и проверка тупика. Фигуры,
///   ориентации, мешок и тип клетки переиспользуются из `lib/core/` (они
///   размерно-независимы) — дублируется только то, что завязано на размер поля.
///
/// Чистота: без UI/IO/таймеров/DateTime; случайность — только через `Bag` от
/// seed. Режим НЕ зеркалится в TS и НЕ входит в golden-паритет 9×9.
///
/// Соответствие ROADMAP: § 5.4 (Co-op Tetris, turn-based 10×20).
library;

import 'package:block_duel/core/core.dart';

/// Ширина поля Co-op (столбцов).
const int coopWidth = 10;

/// Высота поля Co-op (строк).
const int coopHeight = 20;

/// Создаёт пустое поле [coopHeight]×[coopWidth] (строки × столбцы).
Board emptyCoopBoard() => [
  for (int r = 0; r < coopHeight; r++)
    [for (int c = 0; c < coopWidth; c++) Cell()],
];

/// Глубокая копия поля Co-op (клетки копируются).
Board cloneCoopBoard(Board board) => [
  for (final row in board)
    [for (final cell in row) Cell(filled: cell.filled, owner: cell.owner)],
];

/// Можно ли поставить [cells] с верхним-левым якорем в `(r, c)`: все клетки в
/// пределах поля и свободны.
bool coopCanPlace(Board board, List<Coord> cells, int r, int c) {
  for (final cell in cells) {
    final rr = r + cell.r;
    final cc = c + cell.c;
    if (rr < 0 || rr >= coopHeight || cc < 0 || cc >= coopWidth) return false;
    if (board[rr][cc].filled) return false;
  }
  return true;
}

/// Ставит [cells] на поле с якорем `(r, c)` от имени [owner]. Мутирует поле.
void coopPlace(Board board, List<Coord> cells, int r, int c, int owner) {
  for (final cell in cells) {
    board[r + cell.r][c + cell.c] = Cell(filled: true, owner: owner);
  }
}

/// Индексы полностью заполненных строк (сверху вниз). Не мутирует поле.
List<int> coopFullRows(Board board) {
  final rows = <int>[];
  for (int r = 0; r < coopHeight; r++) {
    if (board[r].every((cell) => cell.filled)) rows.add(r);
  }
  return rows;
}

/// Очищает (делает пустыми) указанные строки [rows]. Без «падения» —
/// вышестоящие клетки остаются на месте. Мутирует поле.
void coopClearRows(Board board, List<int> rows) {
  for (final r in rows) {
    for (int c = 0; c < coopWidth; c++) {
      board[r][c] = Cell();
    }
  }
}

/// Есть ли у игрока с рукой [hand] хоть один легальный ход на [board] при
/// заданных правилах поворота/отражения. Тупик = ни одной фигурой никуда.
bool coopHasAnyMove(
  Board board,
  List<PieceInstance> hand, {
  required bool rotationEnabled,
  required bool flipEnabled,
}) {
  for (final piece in hand) {
    for (final cells in orientations(
      piece.type,
      rotationEnabled,
      flipEnabled,
    )) {
      for (int r = 0; r < coopHeight; r++) {
        for (int c = 0; c < coopWidth; c++) {
          if (coopCanPlace(board, cells, r, c)) return true;
        }
      }
    }
  }
  return false;
}

/// Базовые очки за одну очищенную строку.
const int coopRowPoints = 100;

/// Очки за очистку [rowsCleared] строк одним ходом: линейная база + бонус за
/// одновременную очистку нескольких строк (множитель `1 + 0.25·(n-1)`).
int coopScoreForClear(int rowsCleared) {
  if (rowsCleared <= 0) return 0;
  final mult = 1.0 + 0.25 * (rowsCleared - 1);
  return (rowsCleared * coopRowPoints * mult).round();
}
