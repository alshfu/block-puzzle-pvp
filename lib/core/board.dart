/// board.dart — доска 9×9 и операции над ней (порт из `src/core/index.ts`).
///
/// За что отвечает файл:
///   Представление доски ([Cell], [Board]), её создание/копирование, проверка
///   и выполнение постановки фигуры ([canPlace], [place]), поиск и применение
///   очисток ([findClears], [applyClears]) и проверка perfect clear
///   ([isPerfectClear]). Доска мутабельна (как в TS): [place]/[applyClears]
///   меняют её на месте — это сознательно сохранено для верности порту.
///
/// Соответствие TS:
///   Cell / Board / emptyBoard / cloneBoard / canPlace / place / ClearResult /
///   findClears / applyClears / isPerfectClear → этот файл.
library;

import 'types.dart';

/// Клетка доски. [filled] — занята ли; [owner] — игрок (0/1), поставивший её
/// (только для подсветки), либо `null` для пустой. Мутабельна, как в TS.
class Cell {
  /// Занята ли клетка.
  bool filled;

  /// Владелец клетки (0/1) или `null`.
  int? owner;

  /// Создаёт клетку (по умолчанию пустую).
  Cell({this.filled = false, this.owner});
}

/// Доска — матрица клеток 9×9. TS: `Board = Cell[][]`.
typedef Board = List<List<Cell>>;

/// Создаёт пустую доску [boardSize]×[boardSize]. TS: `emptyBoard`.
Board emptyBoard() => [
  for (int r = 0; r < boardSize; r++)
    [for (int c = 0; c < boardSize; c++) Cell()],
];

/// Глубокая копия доски (клетки копируются). TS: `cloneBoard`.
Board cloneBoard(Board board) => [
  for (final row in board)
    [for (final cell in row) Cell(filled: cell.filled, owner: cell.owner)],
];

/// Можно ли поставить набор [cells] с верхним-левым якорем в `(r, c)`:
/// все клетки в пределах доски и не заняты. TS: `canPlace`.
bool canPlace(Board board, List<Coord> cells, int r, int c) {
  for (final cell in cells) {
    final rr = r + cell.r;
    final cc = c + cell.c;
    if (rr < 0 || rr >= boardSize || cc < 0 || cc >= boardSize) return false;
    if (board[rr][cc].filled) return false;
  }
  return true;
}

/// Ставит [cells] на доску с якорем `(r, c)` от имени [owner]. Мутирует доску.
/// TS: `place`.
void place(Board board, List<Coord> cells, int r, int c, int owner) {
  for (final cell in cells) {
    board[r + cell.r][c + cell.c] = Cell(filled: true, owner: owner);
  }
}

/// Результат поиска очисток. [count] — суммарное число очищенных линий
/// (строки+столбцы+боксы); [cleared] — уникальные клетки к очистке;
/// [rows]/[cols]/[boxes] — индексы заполненных линий. TS: `ClearResult`.
class ClearResult {
  /// Число очищенных линий (строк + столбцов + боксов).
  final int count;

  /// Уникальные клетки, подлежащие очистке.
  final List<Coord> cleared;

  /// Индексы полностью заполненных строк.
  final List<int> rows;

  /// Индексы полностью заполненных столбцов.
  final List<int> cols;

  /// Индексы полностью заполненных боксов 3×3 (0..8).
  final List<int> boxes;

  /// Создаёт результат поиска очисток.
  const ClearResult({
    required this.count,
    required this.cleared,
    required this.rows,
    required this.cols,
    required this.boxes,
  });
}

/// Находит все заполненные строки, столбцы и боксы 3×3 и множество клеток к
/// очистке. Не мутирует доску. TS: `findClears`.
ClearResult findClears(Board board) {
  final rows = <int>[];
  final cols = <int>[];
  final boxes = <int>[];

  for (int r = 0; r < boardSize; r++) {
    if (board[r].every((cell) => cell.filled)) rows.add(r);
  }
  for (int c = 0; c < boardSize; c++) {
    var full = true;
    for (int r = 0; r < boardSize; r++) {
      if (!board[r][c].filled) {
        full = false;
        break;
      }
    }
    if (full) cols.add(c);
  }
  for (int b = 0; b < boardSize; b++) {
    final br = (b ~/ 3) * 3;
    final bc = (b % 3) * 3;
    var full = true;
    for (int r = 0; r < 3 && full; r++) {
      for (int c = 0; c < 3; c++) {
        if (!board[br + r][bc + c].filled) {
          full = false;
          break;
        }
      }
    }
    if (full) boxes.add(b);
  }

  // Уникальные клетки к очистке. Порядок добавления повторяет TS
  // (строки → столбцы → боксы), хотя для применения он не важен.
  final set = <Coord>{};
  for (final r in rows) {
    for (int c = 0; c < boardSize; c++) {
      set.add(Coord(r, c));
    }
  }
  for (final c in cols) {
    for (int r = 0; r < boardSize; r++) {
      set.add(Coord(r, c));
    }
  }
  for (final b in boxes) {
    final br = (b ~/ 3) * 3;
    final bc = (b % 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        set.add(Coord(br + r, bc + c));
      }
    }
  }

  return ClearResult(
    count: rows.length + cols.length + boxes.length,
    cleared: set.toList(),
    rows: rows,
    cols: cols,
    boxes: boxes,
  );
}

/// Очищает указанные клетки (делает их пустыми). Мутирует доску.
/// TS: `applyClears`.
void applyClears(Board board, List<Coord> cleared) {
  for (final cell in cleared) {
    board[cell.r][cell.c] = Cell();
  }
}

/// Пуста ли доска полностью (perfect clear). TS: `isPerfectClear`.
bool isPerfectClear(Board board) {
  for (int r = 0; r < boardSize; r++) {
    for (int c = 0; c < boardSize; c++) {
      if (board[r][c].filled) return false;
    }
  }
  return true;
}
