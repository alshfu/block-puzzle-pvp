/// puzzle_state.dart — неизменяемое состояние партии «Силуэты» (Model-слой).
///
/// За что отвечает файл:
///   Снимок прохождения уровня, которым управляет [PuzzleNotifier]: текущий
///   уровень, поле, оставшаяся рука (ещё не поставленные фигуры с цветом),
///   стопка сделанных постановок (для undo), выбранная фигура и ориентация,
///   число сделанных ходов и факт решения. Чистые query-методы ([activeCells],
///   [previewCells], [canPlaceAt]) держат View тонким. Без UI/IO/таймеров.
///
/// Соответствие ROADMAP: § 9.1 (игровой режим «Силуэты»).
library;

import 'package:block_duel/core/core.dart';

import 'puzzle_core.dart';
import 'puzzle_pieces.dart';

/// Фигура в руке: уникальный экземпляр [instanceId], её форма [shapeId] и
/// стабильный [color] (индекс палитры — для раскраски на поле).
typedef HandPiece = ({String instanceId, String shapeId, int color});

/// Сделанная постановка (для undo): экземпляр, форма, цвет и абсолютные клетки.
typedef PlacedPiece = ({
  String instanceId,
  String shapeId,
  int color,
  List<Coord> cells,
});

/// Неизменяемый снимок прохождения уровня-силуэта.
class PuzzleState {
  /// Текущий уровень.
  final PuzzleDef def;

  /// Поле (заполняется только внутри маски).
  final Board board;

  /// Оставшаяся рука (ещё не поставленные фигуры).
  final List<HandPiece> hand;

  /// Стопка сделанных постановок (последняя — вершина, для undo).
  final List<PlacedPiece> placed;

  /// Выбранный экземпляр руки (или `null`).
  final String? selectedInstanceId;

  /// Индекс текущей ориентации выбранной фигуры.
  final int orientIndex;

  /// Сделано ходов (постановок). Промахи (поставил→undo) тоже считаются.
  final int movesUsed;

  /// Решён ли уровень.
  final bool solved;

  /// Итоговый счёт (на момент решения; до этого 0).
  final int score;

  /// Создаёт снимок.
  const PuzzleState({
    required this.def,
    required this.board,
    required this.hand,
    required this.placed,
    required this.selectedInstanceId,
    required this.orientIndex,
    required this.movesUsed,
    required this.solved,
    required this.score,
  });

  /// Маска-цель уровня.
  Set<Coord> get mask => def.mask;

  /// Выбранная фигура руки (или `null`).
  HandPiece? get selectedPiece {
    final id = selectedInstanceId;
    if (id == null) return null;
    for (final p in hand) {
      if (p.instanceId == id) return p;
    }
    return null;
  }

  /// Клетки выбранной фигуры в текущей ориентации (нормализованные) или `null`.
  List<Coord>? get activeCells {
    final p = selectedPiece;
    if (p == null) return null;
    final os = puzzleOrientations(p.shapeId);
    return os[orientIndex % os.length];
  }

  /// Можно ли поставить выбранную фигуру с якорем `(r, c)`.
  bool canPlaceAt(int r, int c) {
    final cells = activeCells;
    if (cells == null) return false;
    return puzzleCanPlace(board, mask, cells, r, c);
  }

  /// Абсолютные клетки превью выбранной фигуры при якоре `(r, c)`.
  List<Coord> previewCells(int r, int c) {
    final cells = activeCells;
    if (cells == null) return const [];
    return [for (final cell in cells) Coord(r + cell.r, c + cell.c)];
  }

  /// Есть ли что отменять.
  bool get canUndo => placed.isNotEmpty;

  /// Копия с изменёнными полями.
  PuzzleState copyWith({
    Board? board,
    List<HandPiece>? hand,
    List<PlacedPiece>? placed,
    String? selectedInstanceId,
    bool clearSelection = false,
    int? orientIndex,
    int? movesUsed,
    bool? solved,
    int? score,
  }) => PuzzleState(
    def: def,
    board: board ?? this.board,
    hand: hand ?? this.hand,
    placed: placed ?? this.placed,
    selectedInstanceId: clearSelection
        ? null
        : (selectedInstanceId ?? this.selectedInstanceId),
    orientIndex: orientIndex ?? this.orientIndex,
    movesUsed: movesUsed ?? this.movesUsed,
    solved: solved ?? this.solved,
    score: score ?? this.score,
  );
}
