/// tetris_board_view.dart — поле «Классического Tetris» 10×20 (View, анимир.).
///
/// За что отвечает файл:
///   Рисует поле живого Tetris на `CustomPaint`: зафиксированную стопку,
///   активную падающую фигуру в её «фирменном» цвете, полупрозрачный «призрак»
///   приземления (куда упадёт при hard drop) и вспышку только что очищённых
///   строк. Клетки красятся по типу фигуры (классическая палитра [tetrisColors])
///   глянцевой отрисовкой [paintGlossyCell]. Ввод поле НЕ обрабатывает —
///   управление идёт с клавиатуры/экранных кнопок в `TetrisScreen` (это
///   соответствует классическому Tetris, где фигура падает сама).
///
/// Соответствие ROADMAP: Фаза 5, режим «Tetris».
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';

import '../../modes/tetris/tetris_core.dart';
import '../../modes/tetris/tetris_state.dart';
import '../decor/cell_fx.dart';
import '../design_tokens.dart';

/// Классическая палитра тетромино по индексу цвета (`tetrisColorIndex`,
/// порядок [allTypes] = I,O,T,S,Z,J,L): голубой, жёлтый, фиолетовый, зелёный,
/// красный, синий, оранжевый.
const List<Color> tetrisColors = [
  Color(0xFF26C6DA), // I — cyan
  Color(0xFFFFCA28), // O — yellow
  Color(0xFFAB47BC), // T — purple
  Color(0xFF66BB6A), // S — green
  Color(0xFFEF5350), // Z — red
  Color(0xFF42A5F5), // J — blue
  Color(0xFFFFA726), // L — orange
];

/// Цвет фигуры [type] из классической палитры.
Color tetrisColorFor(PieceType type) => tetrisColors[tetrisColorIndex(type)];

/// Поле живого Tetris 10×20 (display-only, с анимациями lock/flash).
class TetrisBoardView extends StatefulWidget {
  /// Текущее состояние партии.
  final TetrisState state;

  /// Токены темы.
  final BlockDuelTheme theme;

  /// Показывать ли «призрак» приземления.
  final bool showGhost;

  /// Создаёт поле.
  const TetrisBoardView({
    super.key,
    required this.state,
    required this.theme,
    this.showGhost = true,
  });

  @override
  State<TetrisBoardView> createState() => _TetrisBoardViewState();
}

class _TetrisBoardViewState extends State<TetrisBoardView>
    with TickerProviderStateMixin {
  /// Вспышка только что очищённых строк.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  /// Строки, очищённые последним lock'ом (для вспышки).
  List<int> _flashRows = const [];

  @override
  void didUpdateWidget(covariant TetrisBoardView old) {
    super.didUpdateWidget(old);
    if (widget.state.moveSeq != old.state.moveSeq &&
        widget.state.lastClearCount > 0) {
      _flashRows = widget.state.lastClearedRows;
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AspectRatio(
      aspectRatio: tetrisCols / tetrisRows,
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
            animation: _flash,
            builder: (context, _) => CustomPaint(
              painter: _TetrisBoardPainter(
                state: state,
                theme: widget.theme,
                showGhost: widget.showGhost,
                flashRows: _flash.isAnimating ? _flashRows : const [],
                flashT: _flash.value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Отрисовщик поля Tetris: стопка, активная фигура, призрак, вспышка строк.
class _TetrisBoardPainter extends CustomPainter {
  final TetrisState state;
  final BlockDuelTheme theme;
  final bool showGhost;
  final List<int> flashRows;
  final double flashT;

  const _TetrisBoardPainter({
    required this.state,
    required this.theme,
    required this.showGhost,
    required this.flashRows,
    required this.flashT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / tetrisCols;
    final radius = theme.cellRadius;
    final fillEmpty = Paint()..color = theme.cell;
    final gridLine = Paint()
      ..color = theme.cellLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    Rect cellRect(int r, int c) =>
        Rect.fromLTWH(c * cell + 1, r * cell + 1, cell - 2, cell - 2);

    // Зафиксированная стопка.
    for (int r = 0; r < tetrisRows; r++) {
      for (int c = 0; c < tetrisCols; c++) {
        final bc = state.board[r][c];
        final rr =
            RRect.fromRectAndRadius(cellRect(r, c), Radius.circular(radius));
        if (bc.filled) {
          paintGlossyCell(
            canvas,
            cellRect(r, c),
            tetrisColors[(bc.owner ?? 0) % tetrisColors.length],
            radius: radius,
            shadow: false,
          );
        } else {
          canvas.drawRRect(rr, fillEmpty);
          canvas.drawRRect(rr, gridLine);
        }
      }
    }

    // «Призрак» приземления — контур там, куда упадёт фигура.
    if (showGhost && state.piece != null) {
      final ghostPaint = Paint()
        ..color = tetrisColorFor(state.piece!.type).withValues(alpha: 0.22);
      for (final coord in state.ghostCells) {
        if (_inBounds(coord)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              cellRect(coord.r, coord.c),
              Radius.circular(radius),
            ),
            ghostPaint,
          );
        }
      }
    }

    // Активная падающая фигура.
    if (state.piece != null) {
      final color = tetrisColorFor(state.piece!.type);
      for (final coord in state.activeCells) {
        if (_inBounds(coord)) {
          paintGlossyCell(
            canvas,
            cellRect(coord.r, coord.c),
            color,
            radius: radius,
            shadow: false,
          );
        }
      }
    }

    // Вспышка только что очищённых строк.
    if (flashRows.isNotEmpty && flashT > 0) {
      final a = (1 - flashT) * 0.85;
      final flash = Paint()
        ..color =
            Color.lerp(theme.good, Colors.white, 0.6)!.withValues(alpha: a);
      for (final r in flashRows) {
        canvas.drawRect(Rect.fromLTWH(0, r * cell, size.width, cell), flash);
      }
    }
  }

  bool _inBounds(Coord coord) =>
      coord.r >= 0 &&
      coord.r < tetrisRows &&
      coord.c >= 0 &&
      coord.c < tetrisCols;

  @override
  bool shouldRepaint(_TetrisBoardPainter old) => true;
}
