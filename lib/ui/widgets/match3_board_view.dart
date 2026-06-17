/// match3_board_view.dart — интерактивное поле «Match-3» 8×8 (View, анимир.).
///
/// За что отвечает файл:
///   Рисует сетку цветных «леденцов» 8×8 с премиальной графикой
///   ([paintGlossyCell]) и анимациями: pop-появление изменившихся после хода
///   клеток (каскад/досыпка «вырастают»), пульсирующая подсветка выбранной
///   клетки. Обрабатывает тапы: первый выделяет клетку, второй (соседняя) —
///   делегируется в ViewModel как своп. Логики игры нет.
///
/// Соответствие ROADMAP: § 5.5 (Match-3 UI).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../modes/match3/match3_core.dart';
import '../decor/cell_fx.dart';
import '../design_tokens.dart';

/// Палитра «леденцов» (6 цветов) — индекс = цвет клетки.
const List<Color> match3Palette = [
  Color(0xFFFF5D5D), // красный
  Color(0xFFFFD23F), // жёлтый
  Color(0xFF42E07A), // зелёный
  Color(0xFF49B6FF), // синий
  Color(0xFFB57BFF), // фиолетовый
  Color(0xFFFF924C), // оранжевый
];

/// Интерактивное поле Match-3 8×8.
class Match3BoardView extends StatefulWidget {
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
  State<Match3BoardView> createState() => _Match3BoardViewState();
}

class _Match3BoardViewState extends State<Match3BoardView>
    with TickerProviderStateMixin {
  /// Контроллер pop-появления изменившихся клеток (одноразовый прогон).
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  /// Контроллер пульсации выбранной клетки (повторяющийся).
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  /// Клетки, изменившиеся последним ходом (анимируются pop'ом).
  Set<Cellxy> _changed = {};

  @override
  void didUpdateWidget(covariant Match3BoardView old) {
    super.didUpdateWidget(old);
    final changed = <Cellxy>{};
    for (int r = 0; r < match3Size; r++) {
      for (int c = 0; c < match3Size; c++) {
        if (old.grid[r][c] != widget.grid[r][c]) changed.add((r: r, c: c));
      }
    }
    if (changed.isNotEmpty) {
      _changed = changed;
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / match3Size;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final c = (d.localPosition.dx / cell)
                  .floor()
                  .clamp(0, match3Size - 1);
              final r = (d.localPosition.dy / cell)
                  .floor()
                  .clamp(0, match3Size - 1);
              widget.onTap((r: r, c: c));
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.theme.bg2,
                    Color.lerp(widget.theme.bg2, widget.theme.panel, 0.6)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(widget.theme.boardRadius),
                border: Border.all(color: widget.theme.line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.theme.boardRadius),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pop, _pulse]),
                  builder: (context, _) => CustomPaint(
                    painter: _Match3Painter(
                      grid: widget.grid,
                      selected: widget.selected,
                      theme: widget.theme,
                      changed: _pop.isAnimating ? _changed : const {},
                      popT: Curves.easeOutBack.transform(_pop.value),
                      pulseT: (math.sin(_pulse.value * 2 * math.pi) + 1) / 2,
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

/// Отрисовщик поля Match-3.
class _Match3Painter extends CustomPainter {
  final Match3Grid grid;
  final Cellxy? selected;
  final BlockDuelTheme theme;
  final Set<Cellxy> changed;
  final double popT;
  final double pulseT;

  const _Match3Painter({
    required this.grid,
    required this.selected,
    required this.theme,
    required this.changed,
    required this.popT,
    required this.pulseT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / match3Size;
    final radius = theme.cellRadius + 3;
    for (int r = 0; r < match3Size; r++) {
      for (int c = 0; c < match3Size; c++) {
        final color = grid[r][c];
        final rect = Rect.fromLTWH(
          c * cell + 2.5,
          r * cell + 2.5,
          cell - 5,
          cell - 5,
        );
        // Лунка-подложка.
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)),
          Paint()..color = Colors.black.withValues(alpha: 0.18),
        );
        if (color >= 0 && color < match3Palette.length) {
          final isChanged = changed.contains((r: r, c: c));
          final scale = isChanged
              ? (0.3 + 0.7 * popT).clamp(0.0, 1.25)
              : 1.0;
          paintGlossyCell(
            canvas,
            rect,
            match3Palette[color],
            radius: radius,
            scale: scale,
          );
        }
      }
    }
    // Подсветка выбранной клетки — пульсирующая рамка-свечение.
    final sel = selected;
    if (sel != null) {
      final rect = Rect.fromLTWH(
        sel.c * cell + 2.5,
        sel.r * cell + 2.5,
        cell - 5,
        cell - 5,
      );
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(
        rr,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55 + 0.35 * pulseT)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 + 1.5 * pulseT
          ..maskFilter = MaskFilter.blur(BlurStyle.outer, 2 + 3 * pulseT),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_Match3Painter old) => true;
}
