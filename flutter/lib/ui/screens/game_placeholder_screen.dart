/// game_placeholder_screen.dart — временный игровой экран (View, Фаза 2.2).
///
/// За что отвечает файл:
///   Заглушка маршрута `/game/:mode` до готовности реального игрового экрана
///   (Фаза 2.3: Board на Flame + Hand + GameNotifier). Показывает выбранный
///   режим и кнопку «назад». Подтверждает работу навигации go_router.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_tokens.dart';

/// Заглушка игрового экрана с выбранным режимом [mode].
class GamePlaceholderScreen extends StatelessWidget {
  /// Идентификатор режима из маршрута (`bot`, `hotseat`, …).
  final String mode;

  /// Создаёт заглушку игрового экрана.
  const GamePlaceholderScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Режим: $mode',
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: tokens.fontDisplay,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Игровой экран — Фаза 2.3 (Board на Flame)',
                style: TextStyle(color: tokens.muted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => context.go('/'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.ink,
                  side: BorderSide(color: tokens.line),
                ),
                child: const Text('← в меню'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
