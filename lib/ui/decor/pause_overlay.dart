/// pause_overlay.dart — оверлей паузы (View, декоративный слой).
///
/// За что отвечает файл:
///   Порт `src/ui/components/PauseOverlay.tsx` (+ `.overlay`/`.pause-card`).
///   Полупрозрачный затемняющий слой с блюром и карточкой: заголовок «Пауза» и
///   три кнопки — продолжить / новая игра / в меню. Чистый View: только колбэки.
///
/// Соответствие TS: `components/PauseOverlay.tsx`.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Оверлей паузы с тремя действиями.
class PauseOverlay extends StatelessWidget {
  /// Токены темы.
  final BlockDuelTheme theme;

  /// Продолжить партию.
  final VoidCallback onResume;

  /// Начать новую игру.
  final VoidCallback onRestart;

  /// Выйти в меню.
  final VoidCallback onExit;

  /// Создаёт оверлей паузы.
  const PauseOverlay({
    super.key,
    required this.theme,
    required this.onResume,
    required this.onRestart,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            decoration: BoxDecoration(
              color: theme.panel,
              borderRadius: BorderRadius.circular(theme.cardRadius),
              border: Border.all(color: theme.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Пауза',
                  style: TextStyle(
                    color: theme.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: theme.fontMono,
                  ),
                ),
                const SizedBox(height: 16),
                _PauseButton(
                  theme: theme,
                  label: '▶ Продолжить',
                  primary: true,
                  onTap: onResume,
                ),
                const SizedBox(height: 10),
                _PauseButton(
                  theme: theme,
                  label: '⟳ Новая игра',
                  primary: false,
                  onTap: onRestart,
                ),
                const SizedBox(height: 10),
                _PauseButton(
                  theme: theme,
                  label: '← В меню',
                  primary: false,
                  onTap: onExit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Кнопка оверлея паузы: основная (залитая) или «призрак».
class _PauseButton extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _PauseButton({
    required this.theme,
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: primary ? theme.p0 : Colors.transparent,
        borderRadius: BorderRadius.circular(theme.btnRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(theme.btnRadius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.btnRadius),
              border: primary ? null : Border.all(color: theme.line),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: primary ? theme.bg : theme.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
