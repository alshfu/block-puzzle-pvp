/// cell_fx.dart — переиспользуемые визуальные эффекты для режимов (View-декор).
///
/// За что отвечает файл:
///   Премиальная отрисовка «глянцевой» ячейки/леденца ([paintGlossyCell]) —
///   радиальный блик + верхний хайлайт + мягкая тень + тёмная кромка, с
///   поддержкой масштаба (для pop-анимаций) и прозрачности (для появления).
///   Плюс анимированные виджеты: всплывающий «+счёт» ([FloatingScore]) и
///   кольцевой таймер ([RingTimerPainter]). Используются Match-3 / Co-op /
///   Memory-режимами, чтобы не дублировать рисование и анимации.
///
/// Чистый View-декор: без бизнес-логики и зависимостей от ядра.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Рисует премиальную «глянцевую» ячейку цвета [base] в прямоугольнике [rect].
///
/// [scale] (0..1) сжимает ячейку к центру (для pop-появления), [opacity] —
/// прозрачность всей ячейки, [radius] — скругление, [shadow] — рисовать ли
/// мягкую тень снизу.
void paintGlossyCell(
  Canvas canvas,
  Rect rect,
  Color base, {
  double radius = 6,
  double scale = 1.0,
  double opacity = 1.0,
  bool shadow = true,
}) {
  if (scale <= 0 || opacity <= 0) return;
  final r = scale >= 1.0
      ? rect
      : Rect.fromCenter(
          center: rect.center,
          width: rect.width * scale,
          height: rect.height * scale,
        );
  final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
  final a = opacity.clamp(0.0, 1.0);
  final dark = Color.lerp(base, Colors.black, 0.42)!;

  // Мягкая тень снизу — объём.
  if (shadow && a > 0.5) {
    final shadowRect = r.translate(0, r.height * 0.06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, Radius.circular(radius)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  // Тело: радиальный градиент блик→цвет→тёмный край.
  canvas.drawRRect(
    rr,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.55),
        radius: 1.15,
        colors: [
          Color.lerp(base, Colors.white, 0.55)!.withValues(alpha: a),
          base.withValues(alpha: a),
          dark.withValues(alpha: a),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(r),
  );

  // Верхний глянцевый блик.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.42),
      Radius.circular(radius),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.20 * a),
  );

  // Маленькая искра-хайлайт в верхнем-левом.
  canvas.drawCircle(
    Offset(r.left + r.width * 0.30, r.top + r.height * 0.28),
    r.width * 0.10,
    Paint()..color = Colors.white.withValues(alpha: 0.5 * a),
  );
}

/// Всплывающий «+счёт»: поднимается и плавно гаснет, затем зовёт [onDone].
class FloatingScore extends StatefulWidget {
  /// Текст (например `+120`).
  final String text;

  /// Цвет текста.
  final Color color;

  /// Колбэк по завершении анимации (родитель убирает виджет).
  final VoidCallback? onDone;

  /// Создаёт всплывающий счёт.
  const FloatingScore({
    super.key,
    required this.text,
    required this.color,
    this.onDone,
  });

  @override
  State<FloatingScore> createState() => _FloatingScoreState();
}

class _FloatingScoreState extends State<FloatingScore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final fade = t < 0.15 ? t / 0.15 : (1 - (t - 0.15) / 0.85);
        return Transform.translate(
          offset: Offset(0, -40 * t),
          child: Transform.scale(
            scale: 0.7 + 0.5 * math.min(1, t * 4),
            child: Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Text(
                widget.text,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Кольцевой таймер: рисует дугу прогресса [value] (0..1) цвета [color].
class RingTimerPainter extends CustomPainter {
  /// Доля заполнения (0..1).
  final double value;

  /// Цвет активной дуги.
  final Color color;

  /// Цвет фоновой окружности.
  final Color track;

  /// Толщина кольца.
  final double stroke;

  /// Создаёт отрисовщик кольца.
  const RingTimerPainter({
    required this.value,
    required this.color,
    required this.track,
    this.stroke = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final sweep = 2 * math.pi * value.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(RingTimerPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
