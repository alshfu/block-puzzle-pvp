/// board_view.dart — интерактивная доска (View: Flame + ввод).
///
/// За что отвечает файл:
///   Встраивает [BoardGame] в Flutter и обрабатывает ввод: наведение/перетаскивание
///   показывают «призрак» выбранной фигуры, тап или отпускание — ставят её
///   (якорь = верхняя-левая клетка фигуры). Логики игры здесь нет — постановка
///   делегируется через [onPlace] в ViewModel; превью считает [GameState].
///
/// Соответствие TS: `components/Board.tsx` + `DragLayer.tsx` + хук
/// `useBoardPointer.ts`.
library;

import 'package:block_duel/core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../../shop/skins.dart';
import '../design_tokens.dart';
import '../game/board_game.dart';

/// Интерактивная доска 9×9.
class BoardView extends StatefulWidget {
  /// Текущее состояние партии (доска + выбранная фигура).
  final GameState state;

  /// Токены темы.
  final BlockDuelTheme theme;

  /// Команда постановки фигуры с якорем `(r, c)`.
  final void Function(int r, int c) onPlace;

  /// Показывать ли «призрак» (подсветку цели) под курсором.
  final bool showGhost;

  /// Надетый скин клеток (косметика из магазина).
  final SkinStyle skin;

  /// Создаёт интерактивную доску.
  const BoardView({
    super.key,
    required this.state,
    required this.theme,
    required this.onPlace,
    this.showGhost = true,
    this.skin = SkinStyle.plain,
  });

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  /// Flame-движок доски (живёт всё время жизни виджета).
  final BoardGame _game = BoardGame();

  /// Клетка под курсором/пальцем (якорь призрака) либо `null`.
  ({int r, int c})? _hover;

  /// Переводит локальную позицию указателя в клетку с учётом стороны [side].
  ({int r, int c}) _cellAt(Offset local, double side) {
    final cell = side / 9;
    final c = (local.dx / cell).floor().clamp(0, 8);
    final r = (local.dy / cell).floor().clamp(0, 8);
    return (r: r, c: c);
  }

  void _setHover(({int r, int c})? value) {
    if (_hover != value) setState(() => _hover = value);
  }

  void _place() {
    final h = _hover;
    if (h != null) widget.onPlace(h.r, h.c);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final hover = _hover;
    final List<Coord> preview =
        (widget.showGhost && hover != null && state.activeCells != null)
        ? state.previewCells(hover.r, hover.c)
        : const <Coord>[];
    final valid = hover != null && state.canPlaceAt(hover.r, hover.c);
    // Подсветка будущих очисток: симулируем постановку и ищем очистки (ТЗ §8.2).
    List<Coord> clearPreview = const [];
    final cells = state.activeCells;
    if (valid && cells != null) {
      final board = cloneBoard(state.board);
      place(board, cells, hover.r, hover.c, state.current);
      clearPreview = findClears(board).cleared;
    }
    _game.data = BoardRender(
      board: state.board,
      preview: preview,
      previewValid: valid,
      clearPreview: clearPreview,
      theme: widget.theme,
      skin: widget.skin,
      hintCells: state.hintCells,
    );

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth;
          // Курсор-рука (десктоп), когда есть что ставить под курсором.
          final cursor = state.activeCells != null
              ? SystemMouseCursors.click
              : MouseCursor.defer;
          return MouseRegion(
            cursor: cursor,
            onHover: (e) => _setHover(_cellAt(e.localPosition, side)),
            onExit: (_) => _setHover(null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                _setHover(_cellAt(d.localPosition, side));
                _place();
              },
              onPanUpdate: (d) => _setHover(_cellAt(d.localPosition, side)),
              onPanEnd: (_) => _place(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.theme.bg2,
                  borderRadius: BorderRadius.circular(widget.theme.boardRadius),
                  border: Border.all(color: widget.theme.line),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.theme.boardRadius),
                  child: GameWidget(game: _game),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
