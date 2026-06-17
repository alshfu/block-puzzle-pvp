/// coop_board_view.dart — интерактивное поле Co-op Tetris 10×20 (View, анимир.).
///
/// За что отвечает файл:
///   Рисует и обслуживает ввод для высокого поля произвольных размеров
///   (`coopWidth`×`coopHeight`) на `CustomPaint`: занятые клетки премиальной
///   глянцевой отрисовкой ([paintGlossyCell]), «призрак» выбранной фигуры под
///   курсором/пальцем и подсветку строк к очистке. Анимации: pop-появление
///   только что поставленных клеток и яркая вспышка очищенных строк. Логики игры
///   нет — постановка делегируется через [onPlace], превью считает [CoopState].
///
/// Почему отдельный виджет (а не `BoardView`):
///   `BoardView`/`BoardGame` захардкожены под 9×9. Это поле другого размера и
///   без боксов — собственная отрисовка в едином визуальном стиле.
///
/// Соответствие ROADMAP: § 5.4 (Co-op Tetris UI).
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';

import '../../modes/coop/coop_core.dart';
import '../../modes/coop/coop_state.dart';
import '../decor/cell_fx.dart';
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

class _CoopBoardViewState extends State<CoopBoardView>
    with TickerProviderStateMixin {
  /// Клетка под курсором/пальцем (якорь призрака) либо `null`.
  ({int r, int c})? _hover;

  /// pop-появление только что поставленных клеток.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  /// Вспышка очищенных строк.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  /// Клетки, появившиеся последним ходом.
  Set<Coord> _newCells = {};

  /// Строки, очищенные последним ходом (для вспышки).
  List<int> _flashRows = const [];

  @override
  void didUpdateWidget(covariant CoopBoardView old) {
    super.didUpdateWidget(old);
    final oldB = old.state.board;
    final newB = widget.state.board;
    final appeared = <Coord>{};
    for (int r = 0; r < coopHeight; r++) {
      for (int c = 0; c < coopWidth; c++) {
        if (newB[r][c].filled && !oldB[r][c].filled) {
          appeared.add(Coord(r, c));
        }
      }
    }
    if (appeared.isNotEmpty) {
      _newCells = appeared;
      _pop.forward(from: 0);
    }
    if (widget.state.moveSeq != old.state.moveSeq &&
        widget.state.lastClearedRows.isNotEmpty) {
      _flashRows = widget.state.lastClearedRows;
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _flash.dispose();
    super.dispose();
  }

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
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.theme.bg2,
                      Color.lerp(widget.theme.bg2, widget.theme.panel, 0.5)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(widget.theme.boardRadius),
                  border: Border.all(color: widget.theme.line),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.theme.boardRadius),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_pop, _flash]),
                    builder: (context, _) => CustomPaint(
                      painter: _CoopBoardPainter(
                        board: state.board,
                        preview: preview,
                        previewValid: valid,
                        clearRows: clearRows,
                        theme: widget.theme,
                        newCells: _pop.isAnimating ? _newCells : const {},
                        popT: Curves.easeOutBack.transform(_pop.value),
                        flashRows: _flash.isAnimating ? _flashRows : const [],
                        flashT: _flash.value,
                      ),
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

/// Отрисовщик поля Co-op: клетки, призрак, подсветка/вспышка строк.
class _CoopBoardPainter extends CustomPainter {
  final Board board;
  final List<Coord> preview;
  final bool previewValid;
  final List<int> clearRows;
  final BlockDuelTheme theme;
  final Set<Coord> newCells;
  final double popT;
  final List<int> flashRows;
  final double flashT;

  const _CoopBoardPainter({
    required this.board,
    required this.preview,
    required this.previewValid,
    required this.clearRows,
    required this.theme,
    required this.newCells,
    required this.popT,
    required this.flashRows,
    required this.flashT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / coopWidth;
    final radius = theme.cellRadius;
    final fillEmpty = Paint()..color = theme.cell;
    final gridLine = Paint()
      ..color = theme.cellLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    Rect cellRect(int r, int c) =>
        Rect.fromLTWH(c * cell + 1, r * cell + 1, cell - 2, cell - 2);

    for (int r = 0; r < coopHeight; r++) {
      for (int c = 0; c < coopWidth; c++) {
        final rr = RRect.fromRectAndRadius(cellRect(r, c), Radius.circular(radius));
        final bc = board[r][c];
        if (bc.filled) {
          final isNew = newCells.contains(Coord(r, c));
          final scale = isNew ? (0.2 + 0.8 * popT).clamp(0.0, 1.2) : 1.0;
          paintGlossyCell(
            canvas,
            cellRect(r, c),
            theme.playerColor(bc.owner ?? 0),
            radius: radius,
            scale: scale,
            shadow: false,
          );
        } else {
          canvas.drawRRect(rr, fillEmpty);
          canvas.drawRRect(rr, gridLine);
        }
      }
    }

    // Подсветка строк, которые очистятся этим ходом (превью).
    if (clearRows.isNotEmpty) {
      final glow = Paint()..color = theme.good.withValues(alpha: 0.28);
      for (final r in clearRows) {
        for (int c = 0; c < coopWidth; c++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(cellRect(r, c), Radius.circular(radius)),
            glow,
          );
        }
      }
    }

    // Вспышка только что очищенных строк (яркая, гаснет).
    if (flashRows.isNotEmpty && flashT > 0) {
      final a = (1 - flashT) * 0.85;
      final flash = Paint()
        ..color = Color.lerp(theme.good, Colors.white, 0.5)!.withValues(alpha: a);
      for (final r in flashRows) {
        canvas.drawRect(
          Rect.fromLTWH(0, r * cell, size.width, cell),
          flash,
        );
      }
    }

    // Призрак выбранной фигуры.
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
          RRect.fromRectAndRadius(cellRect(coord.r, coord.c), Radius.circular(radius)),
          ghost,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CoopBoardPainter old) => true;
}
