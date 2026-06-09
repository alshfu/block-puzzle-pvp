/// floating_theme.dart — плавающий переключатель темы (View).
///
/// За что отвечает файл:
///   Порт `src/ui/components/FloatingTheme.tsx` (+ `.floating-theme`): плавающая
///   «пилюля» снизу-справа. Тап циклирует тему по [themeOrder]; внутри —
///   образец палитры СЛЕДУЮЩЕЙ темы (диагональный градиент p0/p1) и ярлык
///   ТЕКУЩЕЙ темы. Команда смены уходит в [ThemeController]; звук клика — общий.
///
/// Соответствие TS: `components/FloatingTheme.tsx`, правила `.floating-theme/
/// .ft-swatch/.ft-lbl`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_service.dart';
import '../../audio/sfx.dart';
import '../design_tokens.dart';
import '../theme/theme_controller.dart';

/// Плавающая пилюля переключения темы (циклом).
class FloatingTheme extends ConsumerWidget {
  /// Создаёт переключатель.
  const FloatingTheme({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeControllerProvider);
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    final idx = themeOrder.indexOf(current);
    final next = themeOrder[(idx + 1) % themeOrder.length];
    final nextTokens = blockDuelThemes[next]!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          ref.read(audioServiceProvider).play(Sfx.click);
          ref.read(themeControllerProvider.notifier).select(next);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tokens.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Образец следующей темы: диагональный градиент p0→p1.
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [nextTokens.p0, nextTokens.p1],
                    stops: const [0.5, 0.5],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tokens.label,
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 11,
                  fontFamily: tokens.fontMono,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
