/// moves.dart — перебор ходов и эвристики оценки (порт из `src/core/index.ts`).
///
/// За что отвечает файл:
///   Генерация всех допустимых ходов руки ([enumerateMoves]), проверка наличия
///   хода ([hasAnyMove], [pieceHasMove]), симуляция хода ([simulate]) и
///   эвристики для бота: «дырки» ([countHoles]), «почти-готовые линии»
///   ([nearLines]) и «подарок сопернику» ([opponentThreatGain]). Порядок
///   перебора ходов обязан совпадать с TS — от него зависит выбор бота и
///   golden-партия (берётся первый ход).
///
/// Соответствие TS:
///   CandidateMove / enumerateMoves / pieceHasMove / hasAnyMove / countHoles /
///   nearLines / simulate / opponentThreatGain → этот файл.
library;

import 'board.dart';
import 'pieces.dart';
import 'types.dart';

/// Кандидат-ход: фигура [pieceId] типа [type] в ориентации [cells] с якорем
/// `(r, c)`. TS: `CandidateMove`.
class CandidateMove {
  /// Id экземпляра фигуры в руке.
  final String pieceId;

  /// Тип фигуры.
  final PieceType type;

  /// Клетки выбранной ориентации.
  final List<Coord> cells;

  /// Строка якоря.
  final int r;

  /// Столбец якоря.
  final int c;

  /// Создаёт кандидат-ход.
  const CandidateMove({
    required this.pieceId,
    required this.type,
    required this.cells,
    required this.r,
    required this.c,
  });
}

/// Максимальные смещения по строке и столбцу в наборе клеток — задают границу
/// перебора якорей. Возвращает `(maxR, maxC)`.
(int, int) _extent(List<Coord> cells) {
  var maxR = cells.first.r;
  var maxC = cells.first.c;
  for (final cell in cells) {
    if (cell.r > maxR) maxR = cell.r;
    if (cell.c > maxC) maxC = cell.c;
  }
  return (maxR, maxC);
}

/// Перечисляет все допустимые ходы для руки в порядке: фигура → ориентация →
/// строка → столбец (как в TS). TS: `enumerateMoves`.
List<CandidateMove> enumerateMoves(
  Board board,
  List<PieceInstance> hand,
  RuleConfig cfg,
) {
  final moves = <CandidateMove>[];
  for (final piece in hand) {
    for (final oriented in orientations(
      piece.type,
      cfg.rotationEnabled,
      cfg.flipEnabled,
    )) {
      final (maxR, maxC) = _extent(oriented);
      for (int r = 0; r + maxR < boardSize; r++) {
        for (int c = 0; c + maxC < boardSize; c++) {
          if (canPlace(board, oriented, r, c)) {
            moves.add(
              CandidateMove(
                pieceId: piece.id,
                type: piece.type,
                cells: oriented,
                r: r,
                c: c,
              ),
            );
          }
        }
      }
    }
  }
  return moves;
}

/// Есть ли хоть один допустимый ход у этой фигуры. TS: `pieceHasMove`.
bool pieceHasMove(Board board, PieceInstance piece, RuleConfig cfg) =>
    hasAnyMove(board, [piece], cfg);

/// Есть ли хоть один допустимый ход у руки (ранний выход). TS: `hasAnyMove`.
bool hasAnyMove(Board board, List<PieceInstance> hand, RuleConfig cfg) {
  for (final piece in hand) {
    for (final oriented in orientations(
      piece.type,
      cfg.rotationEnabled,
      cfg.flipEnabled,
    )) {
      final (maxR, maxC) = _extent(oriented);
      for (int r = 0; r + maxR < boardSize; r++) {
        for (int c = 0; c + maxC < boardSize; c++) {
          if (canPlace(board, oriented, r, c)) return true;
        }
      }
    }
  }
  return false;
}

/// Результат симуляции хода: получившаяся доска, найденные очистки и флаг
/// perfect clear. TS: возвращаемый объект `simulate`.
class SimResult {
  /// Доска после применения хода и очисток (копия исходной).
  final Board board;

  /// Найденные очистки.
  final ClearResult clears;

  /// Стала ли доска пустой (perfect clear).
  final bool perfect;

  /// Создаёт результат симуляции.
  const SimResult({
    required this.board,
    required this.clears,
    required this.perfect,
  });
}

/// Симулирует ход на копии доски: ставит фигуру, находит и применяет очистки.
/// Исходная доска не меняется. TS: `simulate`.
SimResult simulate(Board board, CandidateMove move, int owner) {
  final b = cloneBoard(board);
  place(b, move.cells, move.r, move.c, owner);
  final clears = findClears(b);
  applyClears(b, clears.cleared);
  return SimResult(board: b, clears: clears, perfect: isPerfectClear(b));
}

/// Считает «дырки» — пустые клетки, окружённые занятыми (или краями) со всех
/// четырёх сторон. Штрафная эвристика бота. TS: `countHoles`.
int countHoles(Board board) {
  var holes = 0;
  for (int r = 0; r < boardSize; r++) {
    for (int c = 0; c < boardSize; c++) {
      if (board[r][c].filled) continue;
      final blocked =
          (r == 0 || board[r - 1][c].filled) &&
          (r == boardSize - 1 || board[r + 1][c].filled) &&
          (c == 0 || board[r][c - 1].filled) &&
          (c == boardSize - 1 || board[r][c + 1].filled);
      if (blocked) holes++;
    }
  }
  return holes;
}

/// Оценка «заготовок»: строкам/столбцам/боксам, которым не хватает 1 клетки,
/// начисляется 3, которым 2 — 1. Поощрительная эвристика бота. TS: `nearLines`.
int nearLines(Board board) {
  var score = 0;
  int credit(int missing) => missing == 1 ? 3 : (missing == 2 ? 1 : 0);

  for (int r = 0; r < boardSize; r++) {
    var filled = 0;
    for (int c = 0; c < boardSize; c++) {
      if (board[r][c].filled) filled++;
    }
    score += credit(boardSize - filled);
  }
  for (int c = 0; c < boardSize; c++) {
    var filled = 0;
    for (int r = 0; r < boardSize; r++) {
      if (board[r][c].filled) filled++;
    }
    score += credit(boardSize - filled);
  }
  for (int b = 0; b < boardSize; b++) {
    final br = (b ~/ 3) * 3;
    final bc = (b % 3) * 3;
    var filled = 0;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (board[br + r][bc + c].filled) filled++;
      }
    }
    score += credit(9 - filled);
  }
  return score;
}

/// Дешёвая угроза: число строк/столбцов/боксов, которым осталась ровно одна
/// пустая клетка (соперник почти наверняка возьмёт очистку). TS:
/// `opponentThreatGain`.
int opponentThreatGain(Board board) {
  var n = 0;
  for (int r = 0; r < boardSize; r++) {
    var filled = 0;
    for (int c = 0; c < boardSize; c++) {
      if (board[r][c].filled) filled++;
    }
    if (filled == boardSize - 1) n++;
  }
  for (int c = 0; c < boardSize; c++) {
    var filled = 0;
    for (int r = 0; r < boardSize; r++) {
      if (board[r][c].filled) filled++;
    }
    if (filled == boardSize - 1) n++;
  }
  for (int b = 0; b < boardSize; b++) {
    final br = (b ~/ 3) * 3;
    final bc = (b % 3) * 3;
    var filled = 0;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (board[br + r][bc + c].filled) filled++;
      }
    }
    if (filled == 8) n++;
  }
  return n;
}
