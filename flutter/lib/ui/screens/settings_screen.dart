/// settings_screen.dart — экран настроек (View).
///
/// За что отвечает файл:
///   Переключение темы и пользовательских настроек (звук/музыка/уменьшение
///   анимаций) + раздел «о приложении». Чистый View: тема — из
///   [ThemeController], настройки — из [SettingsController]; команды туда же.
///
/// Соответствие TS: `screens/SettingsScreen.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../settings/settings_controller.dart';
import '../design_tokens.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/theme_switch.dart';

/// Экран настроек.
class SettingsScreen extends ConsumerWidget {
  /// Создаёт экран настроек.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return ScreenScaffold(
      title: 'Настройки',
      theme: theme,
      onBack: () => context.go('/'),
      children: [
        _SectionLabel(text: 'Тема', theme: theme),
        const SizedBox(height: 8),
        const ThemeSwitch(),
        const SizedBox(height: 20),
        _SectionLabel(text: 'Игра', theme: theme),
        const SizedBox(height: 8),
        _ToggleRow(
          theme: theme,
          label: 'Звуковые эффекты',
          value: settings.soundOn,
          onChanged: (_) => ctrl.toggleSound(),
        ),
        _ToggleRow(
          theme: theme,
          label: 'Музыка',
          value: settings.musicOn,
          onChanged: (_) => ctrl.toggleMusic(),
        ),
        _ToggleRow(
          theme: theme,
          label: 'Меньше анимаций',
          value: settings.reduceMotion,
          onChanged: (_) => ctrl.toggleReduceMotion(),
        ),
        const SizedBox(height: 24),
        _SectionLabel(text: 'О приложении', theme: theme),
        const SizedBox(height: 8),
        Text(
          'BlockDuel 9×9 · v2.0.0 (flutter)\n'
          'Соревновательный блок-пазл на поле 9×9.',
          style: TextStyle(color: theme.muted, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}

/// Заголовок секции настроек.
class _SectionLabel extends StatelessWidget {
  final String text;
  final BlockDuelTheme theme;

  const _SectionLabel({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: theme.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}

/// Строка-переключатель настройки.
class _ToggleRow extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.theme,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.ink, fontSize: 15)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: theme.p0,
          ),
        ],
      ),
    );
  }
}
