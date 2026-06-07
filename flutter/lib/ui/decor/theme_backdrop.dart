/// theme_backdrop.dart — анимированный фон под темы (View, декоративный слой).
///
/// За что отвечает файл:
///   Порт `src/ui/components/ThemeBackdrop.tsx` + соответствующих CSS-анимаций.
///   Под каждую тему рисует свой фон:
///     • neutral — статичные слои радиальных градиентов;
///     • candy   — розовый градиент + радуга + облака + парящие сердечки/звёзды/
///                 искры, падающие сверху (порт `.candy-bit`/`floatdown`);
///     • night   — тёмно-синий градиент + звёзды + качающийся луч + эмблема-ромб
///                 со звездой + неоновый «скайлайн» из 22 зданий + сетка.
///   Частицы засеяны тем же PRNG ядра, что в TS (`makeRng(7)` для candy-битов,
///   `makeRng(100+i)` для зданий) — раскладка совпадает с веб-версией.
///
/// Анимация идёт от свободного [Ticker] (монотонные секунды); при включённом
/// `reduceMotion` тикер не запускается — рисуется статичный кадр (как CSS
/// `prefers-reduced-motion`). Чистый View: тему и настройку читает из провайдеров.
///
/// Соответствие TS: `components/ThemeBackdrop.tsx`, `components/FloatingTheme`
/// (декор), правила `.candy-*`/`.night-*` и `@keyframes floatdown/beamsweep/
/// emblemglow` из `styles.css`.
library;

import 'dart:math' as math;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/settings_controller.dart';
import '../design_tokens.dart';
import '../theme/theme_controller.dart';

/// Анимированный фон, переключающийся по текущей теме.
class ThemeBackdrop extends ConsumerStatefulWidget {
  /// Создаёт фон.
  const ThemeBackdrop({super.key});

  @override
  ConsumerState<ThemeBackdrop> createState() => _ThemeBackdropState();
}

class _ThemeBackdropState extends ConsumerState<ThemeBackdrop>
    with SingleTickerProviderStateMixin {
  /// Монотонные секунды от старта тикера — фаза всех анимаций.
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);

  /// Свободный тикер (репейнт-часы); null, когда анимация выключена.
  Ticker? _ticker;

  /// Падающие candy-биты (засев `makeRng(7)`, как в TS).
  late final List<_CandyBit> _bits = _buildBits();

  /// Здания ночного скайлайна (засев `makeRng(100+i)`, как в TS).
  late final List<_Building> _buildings = _buildSkyline();

  /// Звёзды ночного неба (засев `makeRng(200)`).
  late final List<Offset> _stars = _buildStars();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _clock.value = elapsed.inMicroseconds / 1e6;
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _clock.dispose();
    super.dispose();
  }

  /// Запускает/останавливает тикер в зависимости от настройки reduceMotion.
  void _syncTicker({required bool reduceMotion}) {
    final t = _ticker;
    if (t == null) return;
    if (reduceMotion) {
      if (t.isTicking) {
        t.stop();
        _clock.value = 0;
      }
    } else if (!t.isTicking) {
      t.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeId = ref.watch(themeControllerProvider);
    final reduceMotion = ref.watch(
      settingsControllerProvider.select((s) => s.reduceMotion),
    );
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    _syncTicker(reduceMotion: reduceMotion);

    return Positioned.fill(
      child: RepaintBoundary(
        child: switch (themeId) {
          ThemeId.candy => _candy(tokens),
          ThemeId.night => _night(tokens),
          ThemeId.neutral => _neutral(),
        },
      ),
    );
  }

  // ── Neutral ────────────────────────────────────────────────────────────────

  /// Статичные слои: базовый вертикальный градиент + два радиальных «свечения».
  Widget _neutral() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0E1116), Color(0xFF0B0E13)],
      ),
    ),
    child: Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.7, -1.2),
              radius: 1.2,
              colors: [Color(0x1AFF9D42), Color(0x00FF9D42)],
              stops: [0.0, 0.55],
            ),
          ),
          child: SizedBox.expand(),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.7, 1.2),
              radius: 1.2,
              colors: [Color(0x1A36D6E7), Color(0x0036D6E7)],
              stops: [0.0, 0.55],
            ),
          ),
          child: SizedBox.expand(),
        ),
      ],
    ),
  );

  // ── Candy ────────────────────────────────────────────────────────────────

  Widget _candy(BlockDuelTheme tokens) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0, -1.4),
        radius: 1.3,
        colors: [
          Color(0xFFFFF6FB),
          Color(0xFFFFE4F4),
          Color(0xFFF6DCFF),
          Color(0xFFE7E6FF),
        ],
        stops: [0.0, 0.3, 0.6, 1.0],
      ),
    ),
    child: AnimatedBuilder(
      animation: _clock,
      builder: (_, _) => CustomPaint(
        painter: _CandyPainter(bits: _bits, seconds: _clock.value),
        size: Size.infinite,
      ),
    ),
  );

  // ── Night ────────────────────────────────────────────────────────────────

  Widget _night(BlockDuelTheme tokens) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0, -1),
        radius: 1.2,
        colors: [Color(0xFF14213F), Color(0xFF0A0F1F), Color(0xFF05070D)],
        stops: [0.0, 0.45, 1.0],
      ),
    ),
    child: AnimatedBuilder(
      animation: _clock,
      builder: (_, _) => CustomPaint(
        painter: _NightPainter(
          buildings: _buildings,
          stars: _stars,
          accent: tokens.p0,
          grid: tokens.p1,
          seconds: _clock.value,
        ),
        size: Size.infinite,
      ),
    ),
  );

  // ── Засев частиц (тот же PRNG, что в TS) ─────────────────────────────────

  /// 22 падающих бита; порядок вызовов `rng()` совпадает с `CandyBackdrop`.
  List<_CandyBit> _buildBits() {
    const kinds = [
      _BitKind.heart,
      _BitKind.star,
      _BitKind.spark,
      _BitKind.spark,
      _BitKind.star,
    ];
    const palette = [
      Color(0xFFFF9ECB),
      Color(0xFFFFD166),
      Color(0xFFB89CFF),
      Color(0xFF7FE7DF),
      Color(0xFFFF77B3),
    ];
    final rng = makeRng(7);
    return [
      for (int i = 0; i < 22; i++)
        _CandyBit(
          kind: kinds[i % kinds.length],
          left: rng(),
          size: 10 + rng() * 22,
          dur: 9 + rng() * 10,
          delay: rng() * 18,
          color: palette[(rng() * palette.length).floor() % palette.length],
          drift: rng() * 40 - 20,
        ),
    ];
  }

  /// 22 здания; для каждого свой `makeRng(100+i)` — как в `NightBackdrop`.
  List<_Building> _buildSkyline() => [
    for (int i = 0; i < 22; i++)
      () {
        final rng = makeRng(100 + i);
        return _Building(
          width: 22 + (rng() * 26).floor().toDouble(),
          height: 30 + (rng() * 130).floor().toDouble(),
        );
      }(),
  ];

  /// Звёзды (декоративный засев — в TS они были CSS-градиентом).
  List<Offset> _buildStars() {
    final rng = makeRng(200);
    return [for (int i = 0; i < 60; i++) Offset(rng(), rng() * 0.6)];
  }
}

/// Вид candy-бита.
enum _BitKind { heart, star, spark }

/// Параметры одного падающего бита.
class _CandyBit {
  final _BitKind kind;
  final double left; // доля ширины [0,1)
  final double size; // px
  final double dur; // с
  final double delay; // с (фазовый сдвиг)
  final Color color;
  final double drift; // px по X к концу падения

  const _CandyBit({
    required this.kind,
    required this.left,
    required this.size,
    required this.dur,
    required this.delay,
    required this.color,
    required this.drift,
  });
}

/// Здание скайлайна.
class _Building {
  final double width;
  final double height;
  const _Building({required this.width, required this.height});
}

/// Рисует радугу, облака и падающие биты темы candy.
class _CandyPainter extends CustomPainter {
  final List<_CandyBit> bits;
  final double seconds;

  const _CandyPainter({required this.bits, required this.seconds});

  @override
  void paint(Canvas canvas, Size size) {
    _paintRainbow(canvas, size);
    _paintClouds(canvas, size);
    for (final b in bits) {
      _paintBit(canvas, size, b);
    }
  }

  /// Полупрозрачная дуга-радуга у верхнего края.
  void _paintRainbow(Canvas canvas, Size size) {
    const colors = [
      Color(0x33FF9ECB),
      Color(0x33FFD166),
      Color(0x337FE7DF),
      Color(0x33B89CFF),
    ];
    final center = Offset(size.width / 2, -size.height * 0.18);
    final radius = size.width * 0.8;
    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = colors[i];
      canvas.drawCircle(center, radius - i * 20, paint);
    }
  }

  /// Несколько мягких белых облаков.
  void _paintClouds(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x8CFFFFFF);
    void cloud(double cx, double cy, double scale) {
      final w = 120.0 * scale;
      final h = 46.0 * scale;
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(h / 2)),
        paint,
      );
    }

    cloud(size.width * 0.10, size.height * 0.14, 1.1);
    cloud(size.width * 0.92, size.height * 0.32, 1.0);
    cloud(size.width * 0.16, size.height * 0.88, 1.0);
    cloud(size.width * 0.90, size.height * 0.62, 0.85);
  }

  /// Один падающий бит: позиция/поворот/прозрачность из фазы падения.
  void _paintBit(Canvas canvas, Size size, _CandyBit b) {
    final p = ((seconds + b.delay) / b.dur) % 1.0; // фаза [0,1)
    final y = -0.08 * size.height + p * (1.13 * size.height);
    final x = b.left * size.width + b.drift * p;
    final opacity = _floatOpacity(p);
    if (opacity <= 0) return;
    final rotate = 220 * p * math.pi / 180;

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rotate);
    final paint = Paint()..color = b.color.withValues(alpha: opacity);
    final s = b.size;
    switch (b.kind) {
      case _BitKind.heart:
        _heart(canvas, s, paint);
      case _BitKind.star:
        _polyStar(canvas, s, paint);
      case _BitKind.spark:
        _spark(canvas, s, paint);
    }
    canvas.restore();
  }

  /// Прозрачность по `@keyframes floatdown` (0→.85 к 10%, спад к 100%).
  double _floatOpacity(double p) {
    if (p < 0.1) return (p / 0.1) * 0.85;
    if (p < 0.9) return 0.85;
    return (1 - (p - 0.9) / 0.1) * 0.85;
  }

  void _heart(Canvas canvas, double s, Paint paint) {
    final path = Path();
    final r = s / 2;
    path.moveTo(0, r * 0.3);
    path.cubicTo(-r, -r * 0.6, -r * 0.5, -r, 0, -r * 0.35);
    path.cubicTo(r * 0.5, -r, r, -r * 0.6, 0, r * 0.3);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _polyStar(Canvas canvas, double s, Paint paint) {
    _drawStar(canvas, s / 2, 5, 0.45, paint);
  }

  void _spark(Canvas canvas, double s, Paint paint) {
    _drawStar(canvas, s / 2, 4, 0.4, paint);
  }

  /// Рисует звезду с [points] лучами (внутренний радиус = [innerRatio]·R).
  void _drawStar(
    Canvas canvas,
    double radius,
    int points,
    double innerRatio,
    Paint paint,
  ) {
    final path = Path();
    final step = math.pi / points;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * innerRatio;
      final a = -math.pi / 2 + i * step;
      final pt = Offset(r * math.cos(a), r * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CandyPainter old) => old.seconds != seconds;
}

/// Рисует звёзды, луч, эмблему, скайлайн и сетку темы night.
class _NightPainter extends CustomPainter {
  final List<_Building> buildings;
  final List<Offset> stars;
  final Color accent;
  final Color grid;
  final double seconds;

  const _NightPainter({
    required this.buildings,
    required this.stars,
    required this.accent,
    required this.grid,
    required this.seconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintStars(canvas, size);
    _paintBeam(canvas, size);
    _paintEmblem(canvas, size);
    _paintSkyline(canvas, size);
    _paintGrid(canvas, size);
  }

  void _paintStars(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xCCFFFFFF);
    for (final s in stars) {
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        1.3,
        paint,
      );
    }
  }

  /// Луч прожектора, качающийся ±7° (порт `@keyframes beamsweep`, период 8с).
  void _paintBeam(Canvas canvas, Size size) {
    final angle = math.sin(seconds / 8 * 2 * math.pi) * 7 * math.pi / 180;
    final base = Offset(size.width / 2, size.height);
    final height = size.height * 0.78;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);
    final rect = Rect.fromLTWH(-4, -height, 8, height);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0x4D8FC2FF), Color(0x008FC2FF)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  /// Эмблема-ромб со звездой; свечение пульсирует (порт `emblemglow`, 3.5с).
  void _paintEmblem(Canvas canvas, Size size) {
    final glow =
        0.6 + 0.35 * (0.5 + 0.5 * math.sin(seconds / 3.5 * 2 * math.pi));
    final cx = size.width / 2;
    final cy = size.height * 0.12;
    const r = 56.0;
    final color = accent.withValues(alpha: glow);

    final diamond = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = color,
    );
    // Звезда в центре ромба.
    final star = Path();
    const pts = 5;
    final step = math.pi / pts;
    for (int i = 0; i < pts * 2; i++) {
      final rad = i.isEven ? r * 0.42 : r * 0.18;
      final a = -math.pi / 2 + i * step;
      final pt = Offset(cx + rad * math.cos(a), cy + rad * math.sin(a));
      i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = color);
  }

  /// Неоновый скайлайн из зданий, прижатый к нижнему краю.
  void _paintSkyline(Canvas canvas, Size size) {
    const gap = 3.0;
    final total = buildings.fold<double>(0, (acc, b) => acc + b.width + gap);
    var x = (size.width - total) / 2;
    for (final b in buildings) {
      final rect = Rect.fromLTWH(x, size.height - b.height, b.width, b.height);
      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFF04060B), Color(0xFF0A1124)],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x143AA6FF),
      );
      x += b.width + gap;
    }
  }

  /// Слабая перспективная сетка у нижнего края (упрощённый порт `.night-grid`).
  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid.withValues(alpha: 0.07);
    final top = size.height - 90;
    const stepX = 40.0;
    for (double gx = 0; gx <= size.width; gx += stepX) {
      // Линии сходятся к центру-горизонту для эффекта перспективы.
      final vanish = Offset(size.width / 2, top);
      canvas.drawLine(Offset(gx, size.height), vanish, paint);
    }
    for (double gy = top; gy <= size.height; gy += 18) {
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), paint);
    }
  }

  @override
  bool shouldRepaint(_NightPainter old) => old.seconds != seconds;
}
