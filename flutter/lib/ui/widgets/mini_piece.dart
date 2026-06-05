/// mini_piece.dart — декоративный мини-рендер тетромино (View).
///
/// За что отвечает файл:
///   Рисует одну фигуру набором скруглённых клеток в цвете игрока. Используется
///   как декор меню (`MiniDeco`) и для превью фигур. Чистый View: берёт
///   статичные формы из ядра (Model) и токены темы, бизнес-логики нет.
///
/// Соответствие TS: `components/MiniPiece.tsx`.
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Рисует фигуру [cells] (нормализуется внутри) клетками размера [cellSize] в
/// цвете игрока [owner]. Скругление берётся из токенов темы ([BlockDuelTheme]).
class MiniPiece extends StatelessWidget {
  /// Клетки фигуры (любые офсеты; нормализуются перед отрисовкой).
  final List<Coord> cells;

  /// Владелец (0/1) — определяет цвет.
  final int owner;

  /// Размер одной клетки в логических пикселях.
  final double cellSize;

  /// Создаёт мини-фигуру.
  const MiniPiece({
    super.key,
    required this.cells,
    required this.owner,
    this.cellSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    final norm = normalize(cells);
    var maxR = 0;
    var maxC = 0;
    for (final cell in norm) {
      if (cell.r > maxR) maxR = cell.r;
      if (cell.c > maxC) maxC = cell.c;
    }
    return SizedBox(
      width: (maxC + 1) * cellSize,
      height: (maxR + 1) * cellSize,
      child: CustomPaint(
        painter: _MiniPiecePainter(
          cells: norm,
          cellSize: cellSize,
          color: tokens.playerColor(owner),
          radius: tokens.miniRadius,
        ),
      ),
    );
  }
}

/// Отрисовщик клеток мини-фигуры.
class _MiniPiecePainter extends CustomPainter {
  final List<Coord> cells;
  final double cellSize;
  final Color color;
  final double radius;

  const _MiniPiecePainter({
    required this.cells,
    required this.cellSize,
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const gap = 1.0;
    for (final cell in cells) {
      final rect = Rect.fromLTWH(
        cell.c * cellSize + gap,
        cell.r * cellSize + gap,
        cellSize - gap * 2,
        cellSize - gap * 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniPiecePainter old) =>
      old.color != color || old.cellSize != cellSize || old.radius != radius;
}
