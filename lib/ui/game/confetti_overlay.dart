/// confetti_overlay.dart — салют конфетти на Flame (View, декоративный слой).
///
/// За что отвечает файл:
///   Порт `src/ui/components/Confetti.tsx` (+ `@keyframes confettifall`) на
///   Flame `ParticleSystem`. На каждый «выстрел» ([ConfettiGame.burst]) рождает
///   32 частицы-прямоугольника, которые падают сверху с горизонтальным дрейфом,
///   вращением и затуханием (~1.2–2.0с, ease-in вниз — через ускорение).
///   Цвета приходят из темы (p0/p1/good). Прозрачный полноэкранный слой поверх
///   игры; ввод не перехватывает.
///
/// Соответствие TS: `components/Confetti.tsx`, правило `.confetti-bit` и
/// `@keyframes confettifall` (translate→110vh + rotate + opacity→0).
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/widgets.dart';

/// Flame-игра-салют: пустая сцена, в которую [burst] добавляет систему частиц.
class ConfettiGame extends FlameGame {
  /// Источник случайности для разброса частиц (View — не ядро, рандом допустим).
  final math.Random _rng = math.Random();

  @override
  Color backgroundColor() => const Color(0x00000000);

  /// Выпускает один залп из 32 конфетти цветов [colors] (палитра темы).
  void burst(List<Color> colors) {
    if (!isMounted || colors.isEmpty) return;
    final w = size.x;
    final h = size.y;
    const count = 32;
    final fall = h * 1.1; // как 110vh в CSS

    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: count,
          generator: (i) {
            final dur = 1.2 + _rng.nextDouble() * 0.8;
            final drift = _rng.nextDouble() * 80 - 40;
            final rot = _rng.nextDouble() * 4 * math.pi; // 0..720°
            final color = colors[i % colors.length];
            // d = ½·a·t² ⇒ a = 2d/t² даёт ускоряющееся (ease-in) падение.
            final accelY = 2 * fall / (dur * dur);
            return AcceleratedParticle(
              lifespan: dur,
              position: Vector2(_rng.nextDouble() * w, -0.08 * h),
              speed: Vector2(drift / dur, 0),
              acceleration: Vector2(0, accelY),
              child: RotatingParticle(to: rot, child: _confettiBit(color)),
            );
          },
        ),
      ),
    );
  }

  /// Одна частица-прямоугольник 8×14 со скруглением и затуханием к концу жизни.
  Particle _confettiBit(Color color) {
    final paint = Paint()..color = color;
    return ComputedParticle(
      renderer: (canvas, particle) {
        paint.color = color.withValues(alpha: 1 - particle.progress);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 8, height: 14),
            const Radius.circular(2),
          ),
          paint,
        );
      },
    );
  }
}

/// Полноэкранный прозрачный слой конфетти поверх игры (ввод не перехватывает).
class ConfettiOverlay extends StatelessWidget {
  /// Flame-игра салюта (создаётся во View и переживает перерисовки).
  final ConfettiGame game;

  /// Создаёт слой.
  const ConfettiOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: GameWidget(game: game));
  }
}
