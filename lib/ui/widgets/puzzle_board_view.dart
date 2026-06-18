/// puzzle_board_view.dart — поле режима «Силуэты» (View, интерактивное).
///
/// За что отвечает файл:
///   Рисует уровень-силуэт на `CustomPaint`: маску-цель как сглаженный силуэт
///   со скруглёнными ВНЕШНИМИ углами (ROADMAP § 9.2 — «не grid-of-squares»),
///   поставленные фигуры глянцевыми цветными блоками, «призрак» выбранной
///   фигуры под курсором/пальцем и подсветку-подсказку. Клетки вне маски не
///   рисуются (заблокированы). Логики игры нет — постановка делегируется через
///   [onPlace], превью считает [PuzzleState].
///
/// Соответствие ROADMAP: § 9.1/§ 9.2 (UI силуэтов, скруглённые формы).
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';

import '../../modes/puzzle/puzzle_state.dart';
import '../decor/cell_fx.dart';
import '../design_tokens.dart';

/// Палитра цветов фигур пазла (по индексу `HandPiece.color`).
const List<Color> puzzlePalette = [
  Color(0xFF42A5F5),
  Color(0xFFFFA726),
  Color(0xFF66BB6A),
  Color(0xFFAB47BC),
  Color(0xFFEF5350),
  Color(0xFF26C6DA),
  Color(0xFFFFCA28),
];

/// Интерактивное поле уровня-силуэта.
class PuzzleBoardView extends StatefulWidget {
  /// Текущее состояние прохождения.
  final PuzzleState state;

  /// Токены темы.
  final BlockDuelTheme theme;

  /// Команда постановки фигуры с якорем `(r, c)`.
  final void Function(int r, int c) onPlace;

  /// Показывать ли «призрак» под курсором.
  final bool showGhost;

  /// Клетки-подсказка (подсвечиваются), либо пусто.
  final List<Coord> hintCells;

  /// Создаёт поле.
  const PuzzleBoardView({
    super.key,
    required this.state,
    required this.theme,
    required this.onPlace,
    this.showGhost = true,
    this.hintCells = const [],
  });

  @override
  State<PuzzleBoardView> createState() => _PuzzleBoardViewState();
}

class _PuzzleBoardViewState extends State<PuzzleBoardView> {
  /// Клетка под курсором/пальцем (якорь призрака) либо `null`.
  ({int r, int c})? _hover;

  ({int r, int c}) _cellAt(Offset local, double cell, int w, int h) {
    final c = (local.dx / cell).floor().clamp(0, w - 1);
    final r = (local.dy / cell).floor().clamp(0, h - 1);
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
    final w = state.def.width;
    final h = state.def.height;
    final hover = _hover;
    final preview = (widget.showGhost && hover != null && state.activeCells != null)
        ? state.previewCells(hover.r, hover.c)
        : const <Coord>[];
    final valid = hover != null && state.canPlaceAt(hover.r, hover.c);

    return AspectRatio(
      aspectRatio: w / h,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / w;
          final cursor = state.activeCells != null
              ? SystemMouseCursors.click
              : MouseCursor.defer;
          return MouseRegion(
            cursor: cursor,
            onHover: (e) => _setHover(_cellAt(e.localPosition, cell, w, h)),
            onExit: (_) => _setHover(null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                _setHover(_cellAt(d.localPosition, cell, w, h));
                _place();
              },
              onPanUpdate: (d) =>
                  _setHover(_cellAt(d.localPosition, cell, w, h)),
              onPanEnd: (_) => _place(),
              child: CustomPaint(
                painter: _PuzzlePainter(
                  state: state,
                  theme: widget.theme,
                  preview: preview,
                  previewValid: valid,
                  hintCells: widget.hintCells,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Отрисовщик поля: силуэт-маска (скруглённый), фигуры, призрак, подсказка.
class _PuzzlePainter extends CustomPainter {
  final PuzzleState state;
  final BlockDuelTheme theme;
  final List<Coord> preview;
  final bool previewValid;
  final List<Coord> hintCells;

  const _PuzzlePainter({
    required this.state,
    required this.theme,
    required this.preview,
    required this.previewValid,
    required this.hintCells,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = state.def.width;
    final cell = size.width / w;
    final mask = state.mask;

    // Силуэт-цель: сглаженный контур со скруглёнными внешними углами (§ 9.2).
    final maskPath = _groupPath(mask, cell, radius: cell * 0.32);
    canvas.drawPath(maskPath, Paint()..color = theme.cell);
    canvas.drawPath(
      maskPath,
      Paint()
        ..color = theme.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    Rect cellRect(int r, int c) =>
        Rect.fromLTWH(c * cell + 1.5, r * cell + 1.5, cell - 3, cell - 3);

    // Поставленные фигуры — глянцевые цветные блоки.
    for (int r = 0; r < state.board.length; r++) {
      for (int c = 0; c < state.board[0].length; c++) {
        final bc = state.board[r][c];
        if (bc.filled) {
          paintGlossyCell(
            canvas,
            cellRect(r, c),
            puzzlePalette[(bc.owner ?? 0) % puzzlePalette.length],
            radius: cell * 0.22,
            shadow: false,
          );
        }
      }
    }

    // Подсказка — пульсирующая обводка предлагаемых клеток.
    if (hintCells.isNotEmpty) {
      final hintPaint = Paint()
        ..color = theme.good.withValues(alpha: 0.30);
      for (final coord in hintCells) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(cellRect(coord.r, coord.c),
              Radius.circular(cell * 0.22)),
          hintPaint,
        );
      }
    }

    // Призрак выбранной фигуры.
    if (preview.isNotEmpty) {
      final ghost = Paint()
        ..color = (previewValid ? theme.good : theme.bad).withValues(alpha: 0.5);
      for (final coord in preview) {
        if (coord.r < 0 || coord.c < 0) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              cellRect(coord.r, coord.c), Radius.circular(cell * 0.22)),
          ghost,
        );
      }
    }
  }

  /// Строит путь по множеству клеток [cells] со скруглением только ВНЕШНИХ
  /// углов (угол скруглён, если обе ортогональные соседние клетки отсутствуют) —
  /// даёт гладкий силуэт вместо «решётки квадратов».
  Path _groupPath(Set<Coord> cells, double cell, {required double radius}) {
    final path = Path();
    for (final coord in cells) {
      final r = coord.r;
      final c = coord.c;
      final up = cells.contains(Coord(r - 1, c));
      final down = cells.contains(Coord(r + 1, c));
      final left = cells.contains(Coord(r, c - 1));
      final right = cells.contains(Coord(r, c + 1));
      final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
      path.addRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: (!up && !left) ? Radius.circular(radius) : Radius.zero,
          topRight: (!up && !right) ? Radius.circular(radius) : Radius.zero,
          bottomLeft: (!down && !left) ? Radius.circular(radius) : Radius.zero,
          bottomRight: (!down && !right) ? Radius.circular(radius) : Radius.zero,
        ),
      );
    }
    return path;
  }

  @override
  bool shouldRepaint(_PuzzlePainter old) => true;
}
