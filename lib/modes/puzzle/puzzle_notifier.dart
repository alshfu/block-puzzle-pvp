/// puzzle_notifier.dart — ViewModel режима «Силуэты» (MVVM, слой ViewModel).
///
/// За что отвечает файл:
///   Управляет прохождением уровня поверх pure-ядра (`puzzle_core.dart`):
///   загружает уровень и раздаёт руку, обслуживает команды View (выбор/поворот/
///   снятие фигуры, постановка только внутрь маски, отмена хода, рестарт,
///   подсказка) и определяет решение (рука опустела → силуэт собран). Считает
///   сделанные ходы (промахи их тратят) и итоговый счёт. Без `BuildContext`/
///   виджетов/таймеров — награды/рекорды (монеты, время, лучший счёт)
///   начисляет View на переходе в `solved` (как в 9×9).
///
/// Соответствие ROADMAP: § 9.1 (игровой режим), § 9.4 (счёт по сложности).
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'puzzle_core.dart';
import 'puzzle_pack.dart';
import 'puzzle_pieces.dart';
import 'puzzle_state.dart';

/// Размер палитры цветов фигур (для раскраски на поле).
const int puzzlePaletteSize = 7;

/// ViewModel прохождения уровня-силуэта.
class PuzzleNotifier extends Notifier<PuzzleState> {
  @override
  PuzzleState build() => _fresh(puzzlePack.first);

  // ── Команды View ───────────────────────────────────────────────────────────

  /// Загружает уровень [def] (новое прохождение).
  void loadPuzzle(PuzzleDef def) {
    state = _fresh(def);
  }

  /// Рестарт текущего уровня.
  void restart() {
    state = _fresh(state.def);
  }

  /// Выбирает фигуру руки по [instanceId] (сбрасывает ориентацию).
  void selectPiece(String instanceId) {
    if (state.solved) return;
    state = state.copyWith(selectedInstanceId: instanceId, orientIndex: 0);
  }

  /// Поворачивает выбранную фигуру (следующая ориентация).
  void rotate() {
    if (state.solved || state.selectedPiece == null) return;
    state = state.copyWith(orientIndex: state.orientIndex + 1);
  }

  /// Снимает выбор.
  void deselect() {
    if (state.selectedInstanceId == null) return;
    state = state.copyWith(clearSelection: true);
  }

  /// Ставит выбранную фигуру с якорем `(r, c)` (если помещается в маску). Убирает
  /// её из руки, кладёт в стопку отмены, увеличивает счётчик ходов, проверяет
  /// решение и считает счёт.
  void placeAt(int r, int c) {
    if (state.solved) return;
    final piece = state.selectedPiece;
    final cells = state.activeCells;
    if (piece == null || cells == null) return;
    if (!puzzleCanPlace(state.board, state.mask, cells, r, c)) return;

    final board = _clone(state.board);
    puzzlePlace(board, cells, r, c, piece.color);
    final abs = [for (final cell in cells) Coord(r + cell.r, c + cell.c)];

    final hand = [
      for (final p in state.hand) if (p.instanceId != piece.instanceId) p,
    ];
    final placed = [
      ...state.placed,
      (
        instanceId: piece.instanceId,
        shapeId: piece.shapeId,
        color: piece.color,
        cells: abs,
      ),
    ];
    final solved = isPuzzleSolved(board, state.mask);
    final movesUsed = state.movesUsed + 1;

    state = state.copyWith(
      board: board,
      hand: hand,
      placed: placed,
      clearSelection: true,
      orientIndex: 0,
      movesUsed: movesUsed,
      solved: solved,
      score: solved ? puzzleScore(state.def, movesUsed) : 0,
    );
  }

  /// Отменяет последнюю постановку (фигура возвращается в руку). Число
  /// сделанных ходов НЕ уменьшается — промах стоит хода (эффективность в счёте).
  void undo() {
    if (state.placed.isEmpty || state.solved) return;
    final last = state.placed.last;
    final board = _clone(state.board);
    for (final coord in last.cells) {
      board[coord.r][coord.c] = Cell();
    }
    state = state.copyWith(
      board: board,
      hand: [
        ...state.hand,
        (instanceId: last.instanceId, shapeId: last.shapeId, color: last.color),
      ],
      placed: [for (int i = 0; i < state.placed.length - 1; i++) state.placed[i]],
      clearSelection: true,
      orientIndex: 0,
    );
  }

  /// Подсказка: одно валидное размещение, покрывающее ещё пустую клетку маски
  /// фигурой, которая есть в руке (или `null`, если подсказать нечего). Не
  /// мутирует состояние — View подсвечивает результат.
  List<Coord>? hint() {
    if (state.solved) return null;
    final handShapes = state.hand.map((p) => p.shapeId).toSet();
    // Первая пустая клетка маски (row-major).
    final empties = [
      for (final coord in state.mask)
        if (!state.board[coord.r][coord.c].filled) coord,
    ]..sort((a, b) => a.r != b.r ? a.r - b.r : a.c - b.c);
    for (final target in empties) {
      for (final shapeId in handShapes) {
        for (final orient in puzzleOrientations(shapeId)) {
          for (final o in orient) {
            final ar = target.r - o.r;
            final ac = target.c - o.c;
            if (puzzleCanPlace(state.board, state.mask, orient, ar, ac)) {
              return [for (final cell in orient) Coord(ar + cell.r, ac + cell.c)];
            }
          }
        }
      }
      // Если первую пустую клетку нечем закрыть из руки — тупик; пробуем дальше.
    }
    return null;
  }

  // ── Внутреннее ──────────────────────────────────────────────────────────────

  Board _clone(Board b) => [
    for (final row in b)
      [for (final cell in row) Cell(filled: cell.filled, owner: cell.owner)],
  ];

  /// Свежее прохождение [def]: пустое поле, рука из фигур решения (порядок
  /// перемешивать не нужно — это набор, а не очередь; цвет стабилен по индексу).
  PuzzleState _fresh(PuzzleDef def) {
    final ids = def.handShapeIds;
    final hand = <HandPiece>[
      for (int i = 0; i < ids.length; i++)
        (instanceId: 'h$i', shapeId: ids[i], color: i % puzzlePaletteSize),
    ];
    return PuzzleState(
      def: def,
      board: puzzleEmptyBoard(def.width, def.height),
      hand: hand,
      placed: const [],
      selectedInstanceId: null,
      orientIndex: 0,
      movesUsed: 0,
      solved: false,
      score: 0,
    );
  }
}

/// Провайдер ViewModel режима «Силуэты».
final puzzleProvider = NotifierProvider<PuzzleNotifier, PuzzleState>(
  PuzzleNotifier.new,
);
