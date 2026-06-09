/// combo_flash.dart — вспышка комбо-вехи (View, декоративный слой).
///
/// За что отвечает файл:
///   Порт `src/ui/components/ComboFlash.tsx` (+ CSS `comboFlashIn/FadeOut`,
///   `mascotBounce`). Полноэкранный оверлей: маскот темы + сообщение уровня +
///   подпись «комбо ×N». Появляется с overshoot-масштабом, держится и плавно
///   гаснет за 1.7с, после чего зовёт [onComplete] (родитель убирает виджет).
///   Цвет заголовка зависит от уровня (1=p0, 2=good, 3=p1).
///
/// Соответствие TS: `components/ComboFlash.tsx` (COMBO_MESSAGES,
/// pickComboMessage) и правила `.combo-flash*` из `styles.css`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_tokens.dart';
import 'mascot.dart';

/// Сообщения комбо по теме и уровню (1:1 с TS `COMBO_MESSAGES`).
const Map<ThemeId, Map<int, List<String>>> comboMessages = {
  ThemeId.neutral: {
    1: ['EFFICIENT', 'CLEAN', 'NICE'],
    2: ['EXCELLENT', 'MASTERFUL', 'FLAWLESS'],
    3: ['LEGEND', 'TRANSCENDENT', 'MAX OUTPUT'],
  },
  ThemeId.candy: {
    1: ['Молодец!', 'Волшебно!', 'Здорово!'],
    2: ['Невероятно!', 'Магия!', 'Сладко!'],
    3: ['Магистр карамели!', 'Звёздное чудо!', 'Радужный шторм!'],
  },
  ThemeId.night: {
    1: ['Жестоко', 'Холодно', 'Тень одобряет'],
    2: ['Безжалостно', 'Идеальный удар', 'Чистая ночь'],
    3: ['Ты — тьма', 'Чемпион ночи', 'Бесконечность'],
  },
};

/// Случайно выбирает сообщение комбо для темы [theme] и уровня [level] (1..3).
String pickComboMessage(ThemeId theme, int level, [math.Random? rng]) {
  final opts = comboMessages[theme]![level]!;
  final r = rng ?? math.Random();
  return opts[r.nextInt(opts.length)];
}

/// Анимированная вспышка комбо-вехи.
class ComboFlash extends StatefulWidget {
  /// Текущая тема (для маскота и регистра текста).
  final ThemeId themeId;

  /// Уровень вехи: 1 (комбо ≥3), 2 (≥5), 3 (≥10).
  final int level;

  /// Текущее значение комбо.
  final int combo;

  /// Сообщение (уже выбранное родителем — стабильно на весь показ).
  final String message;

  /// Вызывается по завершении показа (~1.7с) — родитель убирает оверлей.
  final VoidCallback onComplete;

  /// Создаёт вспышку.
  const ComboFlash({
    super.key,
    required this.themeId,
    required this.level,
    required this.combo,
    required this.message,
    required this.onComplete,
  });

  @override
  State<ComboFlash> createState() => _ComboFlashState();
}

class _ComboFlashState extends State<ComboFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onComplete();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Размер маскота по уровню (как в TSX: 110/130/160).
  double get _mascotSize => switch (widget.level) {
    3 => 160,
    2 => 130,
    _ => 110,
  };

  /// Цвет заголовка по уровню.
  Color _titleColor(BlockDuelTheme t) => switch (widget.level) {
    3 => t.p1,
    2 => t.good,
    _ => t.p0,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<BlockDuelTheme>()!;
    final color = _titleColor(t);
    final title = widget.themeId == ThemeId.night
        ? widget.message.toUpperCase()
        : widget.message;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          // Контейнер: вход scale .6→1 с overshoot за ~20% таймлайна; гаснет
          // после 70% (порт comboFlashIn + comboFlashFadeOut).
          final tIn = (v / 0.206).clamp(0.0, 1.0);
          final entrance = Curves.easeOutBack.transform(tIn);
          var scale = 0.6 + (1.0 - 0.6) * entrance;
          var opacity = tIn;
          if (v > 0.7) {
            final fo = (v - 0.7) / 0.3;
            scale = 1.0 - 0.05 * fo;
            opacity = 1.0 - fo;
          } else if (tIn >= 1.0) {
            scale = 1.0;
            opacity = 1.0;
          }
          // Маскот: bounce scale .4→1.15→1 + сдвиг по Y за ~0.53 таймлайна.
          final tM = (v / 0.53).clamp(0.0, 1.0);
          final double mScale, mDy;
          if (tM < 0.5) {
            final k = tM / 0.5;
            mScale = 0.4 + (1.15 - 0.4) * k;
            mDy = 20 + (-6 - 20) * k;
          } else {
            final k = (tM - 0.5) / 0.5;
            mScale = 1.15 + (1.0 - 1.15) * k;
            mDy = -6 + (0 - -6) * k;
          }

          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: t.panel.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(t.cardRadius),
                    border: Border.all(color: color, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 0,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: color,
                        blurRadius: 60,
                        spreadRadius: -20,
                        offset: const Offset(0, 30),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.translate(
                        offset: Offset(0, mDy),
                        child: Transform.scale(
                          scale: mScale,
                          child: Mascot(
                            themeId: widget.themeId,
                            size: _mascotSize,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: t.fontDisplay,
                          fontWeight: FontWeight.w800,
                          fontSize: 32 + (widget.level - 1) * 6,
                          height: 1,
                          color: color,
                          shadows: [
                            Shadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 14,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'комбо ×${widget.combo}',
                        style: TextStyle(
                          fontFamily: t.fontMono,
                          fontSize: 13,
                          color: t.ink.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
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
