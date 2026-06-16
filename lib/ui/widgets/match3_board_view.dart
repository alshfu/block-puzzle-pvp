/// match3_board_view.dart — интерактивное поле «Match-3» 8×8 (View).
///
/// За что отвечает файл:
///   Рисует сетку цветных «леденцов» 8×8 на `CustomPaint` и обрабатывает тапы:
///   первый тап выделяет клетку, второй (соседняя) — делегируется в ViewModel
///   как своп. Палитра цветов фиксирована (6 цветов ROADMAP § 5.5). Логики игры
///   нет — валидность свопа и каскады считает ядро/ViewModel.
///
/// Соответствие ROADMAP: § 5.5 (Match-3 UI).
library;

import 'package:flutter/material.dart';

import '../../modes/match3/match3_core.dart';
import '../design_tokens.dart';

/// Палитра «леденцов» (6 цветов) — индекс = цвет клетки.
const List<Color> match3Palette = [
  Color(0xFFE74C3C), // красный
  Color(0xFFF1C40F), // жёлтый
  Color(0xFF2ECC71), // зелёный
  Color(0xFF3498DB), // синий
  Color(0xFF9B59B6), // фиолетовый
  Color(0xFFE67E22), // оранжевый
];

/// Интерактивное поле Match-3 8×8.
class Match3BoardView extends StatelessWidget {
  /// Текущая сетка цветов.
  final Match3Grid grid;

  /// Выбранная клетка (или `null`).
  final Cellxy? selected;

  /// Токены темы (фон/рамка/радиусы).
  final BlockDuelTheme theme;

  /// Команда тапа по клетке.
  final void Function(Cellxy) onTap;

  /// Создаёт поле.
  const Match3BoardView({
    super.key,
    required this.grid,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth;
          final cell = side / match3Size;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final c = (d.localPosition.dx / cell)
                  .floor()
                  .clamp(0, match3Size - 1);
              final r = (d.localPosition.dy / cell)
                  .floor()
                  .clamp(0, match3Size - 1);
              onTap((r: r, c: c));
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.bg2,
                borderRadius: BorderRadius.circular(theme.boardRadius),
                border: Border.all(color: theme.line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(theme.boardRadius),
                child: CustomPaint(
                  painter: _Match3Painter(
                    grid: grid,
                    selected: selected,
                    theme: theme,
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

/// Отрисовщик поля Match-3.
class _Match3Painter extends CustomPainter {
  final Match3Grid grid;
  final Cellxy? selected;
  final BlockDuelTheme theme;

  const _Match3Painter({
    required this.grid,
    required this.selected,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / match3Size;
    final radius = Radius.circular(theme.cellRadius + 2);
    for (int r = 0; r < match3Size; r++) {
      for (int c = 0; c < match3Size; c++) {
        final color = grid[r][c];
        final rect = Rect.fromLTWH(
          c * cell + 2,
          r * cell + 2,
          cell - 4,
          cell - 4,
        );
        final rr = RRect.fromRectAndRadius(rect, radius);
        if (color >= 0 && color < match3Palette.length) {
          // База + лёгкий радиальный блик (глянец «леденца»).
          canvas.drawRRect(
            rr,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-0.4, -0.5),
                radius: 1.1,
                colors: [
                  const Color(0x55FFFFFF),
                  match3Palette[color],
                ],
                stops: const [0.0, 0.7],
              ).createShader(rect),
          );
        } else {
          canvas.drawRRect(rr, Paint()..color = theme.cell);
        }
      }
    }
    // Подсветка выбранной клетки.
    final sel = selected;
    if (sel != null) {
      final rect = Rect.fromLTWH(
        sel.c * cell + 2,
        sel.r * cell + 2,
        cell - 4,
        cell - 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..color = theme.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_Match3Painter old) => true;
}
