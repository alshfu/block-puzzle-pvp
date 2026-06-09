/// tutorial_steps.dart — сценарий обучения (Model-данные).
///
/// За что отвечает файл:
///   Пять шагов интерактивного туториала: стартовая доска и рука для каждого
///   плюс условие достижения цели. Порт `src/ui/tutorial/steps.ts`. Чистые
///   данные поверх ядра — без UI и состояния.
///
/// Соответствие TS: `src/ui/tutorial/steps.ts`.
library;

import 'package:block_duel/core/core.dart';

/// Награда за полное прохождение туториала (монеты).
const int tutorialRewardCoins = 50;

/// Условие цели шага: `(clearsCount, combo, boardEmptyAfter) → достигнута ли`.
typedef GoalCheck =
    bool Function(int clearsCount, int combo, bool boardEmptyAfter);

/// Один шаг обучения.
class TutorialStep {
  /// Идентификатор шага.
  final String id;

  /// Заголовок.
  final String title;

  /// Описание задачи.
  final String description;

  /// Подсказка под доской, пока шаг идёт.
  final String hint;

  /// Строит стартовую доску шага.
  final Board Function() buildBoard;

  /// Строит стартовую руку шага.
  final List<PieceInstance> Function() buildHand;

  /// Достигнута ли цель шага после хода.
  final GoalCheck isGoalMet;

  const TutorialStep({
    required this.id,
    required this.title,
    required this.description,
    required this.hint,
    required this.buildBoard,
    required this.buildHand,
    required this.isGoalMet,
  });
}

int _pieceCounter = 0;

/// Создаёт экземпляр фигуры [type] с уникальным id (нормализованный).
PieceInstance _mkPiece(PieceType type) {
  _pieceCounter += 1;
  return PieceInstance(
    id: 'tut_${type.name}_$_pieceCounter',
    type: type,
    cells: normalize(baseShapes[type]!),
  );
}

/// Заполняет клетки [coords] доски [board] владельцем [owner].
void _fill(Board board, List<Coord> coords, [int owner = 0]) {
  for (final cell in coords) {
    if (cell.r >= 0 &&
        cell.r < boardSize &&
        cell.c >= 0 &&
        cell.c < boardSize) {
      board[cell.r][cell.c] = Cell(filled: true, owner: owner);
    }
  }
}

/// Клетки строки [r], кроме столбцов из [except].
List<Coord> _rowCells(int r, List<int> except) => [
  for (int c = 0; c < boardSize; c++)
    if (!except.contains(c)) Coord(r, c),
];

/// Пять шагов обучения (порт TS `TUTORIAL_STEPS`).
final List<TutorialStep> tutorialSteps = [
  TutorialStep(
    id: 'place',
    title: 'Шаг 1 · Поставь фигуру',
    description:
        'Выбери фигуру в руке и поставь её на любую клетку доски. '
        'На десктопе — мышью, на телефоне — пальцем.',
    hint: 'выбери фигуру и поставь',
    buildBoard: emptyBoard,
    buildHand: () => [_mkPiece(PieceType.l)],
    isGoalMet: (clearsCount, combo, boardEmptyAfter) => true,
  ),
  TutorialStep(
    id: 'close_row',
    title: 'Шаг 2 · Закрой строку',
    description:
        'Строка почти полная — поставь I-фигуру горизонтально в правый край, '
        'чтобы заполнить её. Целая строка = очистка!',
    hint: 'поставь I в строку 4',
    buildBoard: () {
      final b = emptyBoard();
      _fill(b, [for (int c = 0; c <= 4; c++) Coord(4, c)]);
      return b;
    },
    buildHand: () => [_mkPiece(PieceType.i)],
    isGoalMet: (clearsCount, combo, boardEmptyAfter) => clearsCount >= 1,
  ),
  TutorialStep(
    id: 'rotate',
    title: 'Шаг 3 · Поверни и закрой столбец',
    description:
        'Сейчас почти полный столбец 3. Поверни I в вертикальное положение '
        '(тап по выбранной фигуре) и поставь.',
    hint: 'поверни и закрой столбец 3',
    buildBoard: () {
      final b = emptyBoard();
      _fill(b, [for (int r = 0; r <= 4; r++) Coord(r, 3)]);
      return b;
    },
    buildHand: () => [_mkPiece(PieceType.i)],
    isGoalMet: (clearsCount, combo, boardEmptyAfter) => clearsCount >= 1,
  ),
  TutorialStep(
    id: 'box',
    title: 'Шаг 4 · Закрой бокс 3×3',
    description:
        'Верхний-левый квадрат 3×3 заполнен на 5 клеток — поставь O '
        '(квадрат 2×2) в его свободный угол, чтобы закрыть.',
    hint: 'поставь O в угол бокса',
    buildBoard: () {
      final b = emptyBoard();
      _fill(b, const [
        Coord(0, 0),
        Coord(0, 1),
        Coord(0, 2),
        Coord(1, 0),
        Coord(2, 0),
      ]);
      return b;
    },
    buildHand: () => [_mkPiece(PieceType.o)],
    isGoalMet: (clearsCount, combo, boardEmptyAfter) => clearsCount >= 1,
  ),
  TutorialStep(
    id: 'combo',
    title: 'Шаг 5 · Сделай комбо',
    description:
        'Два хода подряд с очисткой = комбо ×2. Используй обе фигуры — '
        'каждая закрывает свою строку.',
    hint: 'оба хода должны очистить — добьёшься комбо',
    buildBoard: () {
      final b = emptyBoard();
      _fill(b, _rowCells(3, const [5, 6, 7, 8]));
      _fill(b, _rowCells(5, const [5, 6, 7, 8]));
      return b;
    },
    buildHand: () => [_mkPiece(PieceType.i), _mkPiece(PieceType.i)],
    isGoalMet: (clearsCount, combo, boardEmptyAfter) => combo >= 2,
  ),
];
