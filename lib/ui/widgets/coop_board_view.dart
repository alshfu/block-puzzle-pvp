/// coop_board_view.dart — интерактивное поле Co-op Tetris 10×20 (View).
///
/// За что отвечает файл:
///   Рисует и обслуживает ввод для высокого поля произвольных размеров
///   (`coopWidth`×`coopHeight`) на `CustomPaint`: занятые клетки в цвете
///   игрока, пустые с сеткой, «призрак» выбранной фигуры под курсором/пальцем и
///   подсветку строк, которые очистятся этим ходом. Логики игры нет — постановка
///   делегируется через [onPlace] в ViewModel, превью/валидность считает
///   [CoopState] и pure-ядро `coop_core.dart`.
///
/// Почему отдельный виджет (а не `BoardView`):
///   `BoardView`/`BoardGame` захардкожены под 9×9 (`boardSize`, боксы 3×3). Это
///   поле другого размера и без боксов, поэтому отрисовка — собственная, но в
///   том же визуальном стиле (скруглённые клетки, токены темы).
///
/// Соответствие ROADMAP: § 5.4 (Co-op Tetris UI).
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';

import '../../modes/coop/coop_core.dart';
import '../../modes/coop/coop_state.dart';
import '../design_tokens.dart';

/// Интерактивное поле Co-op 10×20.
class CoopBoardView extends StatefulWidget {
  /// Текущее состояние матча (поле + выбранная фигура).
  final CoopState state;

  /// Токены темы.
  final BlockDuelTheme theme;

  /// Команда постановки фигуры с якорем `(r, c)`.
  final void Function(int r, int c) onPlace;

  /// Показывать ли «призрак» под курсором.
  final bool showGhost;

  /// Создаёт интерактивное поле.
  const CoopBoardView({
    super.key,
    required this.state,
    required this.theme,
    required this.onPlace,
    this.showGhost = true,
  });

  @override
  State<CoopBoardView> createState() => _CoopBoardViewState();
}

class _CoopBoardViewState extends State<CoopBoardView> {
  /// Клетка под курсором/пальцем (якорь призрака) либо `null`.
  ({int r, int c})? _hover;

  /// Переводит локальную позицию указателя в клетку по размеру клетки [cell].
  ({int r, int c}) _cellAt(Offset local, double cell) {
    final c = (local.dx / cell).floor().clamp(0, coopWidth - 1);
    final r = (local.dy / cell).floor().clamp(0, coopHeight - 1);
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

    // Подсветка строк, которые очистятся этим ходом.
    List<int> clearRows = const [];
    final cells = state.activeCells;
    if (valid && cells != null) {
      final board = cloneCoopBoard(state.board);
      coopPlace(board, cells, hover.r, hover.c, state.current);
      clearRows = coopFullRows(board);
    }

    return AspectRatio(
      aspectRatio: coopWidth / coopHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / coopWidth;
          final cursor = state.activeCells != null
              ? SystemMouseCursors.click
              : MouseCursor.defer;
          return MouseRegion(
            cursor: cursor,
            onHover: (e) => _setHover(_cellAt(e.localPosition, cell)),
            onExit: (_) => _setHover(null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                _setHover(_cellAt(d.localPosition, cell));
                _place();
              },
              onPanUpdate: (d) => _setHover(_cellAt(d.localPosition, cell)),
              onPanEnd: (_) => _place(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.theme.bg2,
                  borderRadius: BorderRadius.circular(widget.theme.boardRadius),
                  border: Border.all(color: widget.theme.line),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.theme.boardRadius),
                  child: CustomPaint(
                    painter: _CoopBoardPainter(
                      board: state.board,
                      preview: preview,
                      previewValid: valid,
                      clearRows: clearRows,
                      theme: widget.theme,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Отрисовщик поля Co-op: клетки, призрак, подсветка строк.
class _CoopBoardPainter extends CustomPainter {
  final Board board;
  final List<Coord> preview;
  final bool previewValid;
  final List<int> clearRows;
  final BlockDuelTheme theme;

  const _CoopBoardPainter({
    required this.board,
    required this.preview,
    required this.previewValid,
    required this.clearRows,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / coopWidth;
    final radius = Radius.circular(theme.cellRadius);
    final fillEmpty = Paint()..color = theme.cell;
    final gridLine = Paint()
      ..color = theme.cellLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    Rect cellRect(int r, int c) =>
        Rect.fromLTWH(c * cell + 1, r * cell + 1, cell - 2, cell - 2);

    // База: занятые/пустые клетки.
    for (int r = 0; r < coopHeight; r++) {
      for (int c = 0; c < coopWidth; c++) {
        final rr = RRect.fromRectAndRadius(cellRect(r, c), radius);
        final bc = board[r][c];
        if (bc.filled) {
          canvas.drawRRect(
            rr,
            Paint()..color = theme.playerColor(bc.owner ?? 0),
          );
        } else {
          canvas.drawRRect(rr, fillEmpty);
          canvas.drawRRect(rr, gridLine);
        }
      }
    }

    // Подсветка строк, которые очистятся.
    if (clearRows.isNotEmpty) {
      final glow = Paint()..color = theme.good.withValues(alpha: 0.30);
      for (final r in clearRows) {
        for (int c = 0; c < coopWidth; c++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(cellRect(r, c), radius),
            glow,
          );
        }
      }
    }

    // Призрак выбранной фигуры (зелёный валидный / красный нет).
    if (preview.isNotEmpty) {
      final ghost = Paint()
        ..color = (previewValid ? theme.good : theme.bad).withValues(
          alpha: 0.45,
        );
      for (final coord in preview) {
        if (coord.r < 0 ||
            coord.r >= coopHeight ||
            coord.c < 0 ||
            coord.c >= coopWidth) {
          continue;
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(cellRect(coord.r, coord.c), radius),
          ghost,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CoopBoardPainter old) => true;
}
