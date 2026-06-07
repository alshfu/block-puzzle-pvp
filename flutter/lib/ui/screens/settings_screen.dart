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

import '../../auth/auth_controller.dart';
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
        _SectionLabel(text: 'Аккаунт', theme: theme),
        const SizedBox(height: 8),
        _AccountSection(theme: theme),
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

/// Секция аккаунта: вход через Google / профиль + выход, либо «недоступно».
class _AccountSection extends ConsumerWidget {
  final BlockDuelTheme theme;

  const _AccountSection({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final ctrl = ref.read(authControllerProvider.notifier);

    if (!auth.available) {
      return Text(
        'Облачная синхронизация недоступна на этой платформе.',
        style: TextStyle(color: theme.muted, fontSize: 13),
      );
    }

    if (auth.signedIn) {
      final u = auth.user!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (u.photoUrl != null)
                ClipOval(
                  child: Image.network(
                    u.photoUrl!,
                    width: 36,
                    height: 36,
                    errorBuilder: (_, _, _) => Text(
                      '👤',
                      style: TextStyle(color: theme.ink, fontSize: 24),
                    ),
                  ),
                )
              else
                Text('👤', style: TextStyle(color: theme.ink, fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.displayName ?? 'Игрок',
                      style: TextStyle(
                        color: theme.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      u.email ?? u.uid,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'синхронизация прогресса включена',
            style: TextStyle(color: theme.good, fontSize: 11),
          ),
          const SizedBox(height: 10),
          _AuthButton(
            theme: theme,
            label: 'Выйти',
            ghost: true,
            onTap: ctrl.signOut,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Войди, чтобы синхронизировать прогресс между устройствами.',
          style: TextStyle(color: theme.muted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        _AuthButton(
          theme: theme,
          label: auth.busy ? 'Вход…' : '🔑 Войти через Google',
          onTap: auth.busy ? null : ctrl.signInWithGoogle,
        ),
        if (auth.error != null) ...[
          const SizedBox(height: 6),
          Text(auth.error!, style: TextStyle(color: theme.bad, fontSize: 12)),
        ],
      ],
    );
  }
}

/// Кнопка авторизации (основная/призрак).
class _AuthButton extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final bool ghost;
  final VoidCallback? onTap;

  const _AuthButton({
    required this.theme,
    required this.label,
    required this.onTap,
    this.ghost = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ghost ? Colors.transparent : theme.p0,
      borderRadius: BorderRadius.circular(theme.btnRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.btnRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.btnRadius),
            border: ghost ? Border.all(color: theme.line) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: ghost ? theme.ink : theme.bg,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
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
