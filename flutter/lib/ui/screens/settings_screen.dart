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

import '../../achievements/achievements_controller.dart';
import '../../achievements/stats_controller.dart';
import '../../auth/auth_controller.dart';
import '../../daily/daily_controller.dart';
import '../../game/saved_game_store.dart';
import '../../online/uuid.dart';
import '../../profile/profile.dart';
import '../../profile/profile_controller.dart';
import '../../settings/settings.dart';
import '../../settings/settings_controller.dart';
import '../../shop/inventory_controller.dart';
import '../../shop/skins_controller.dart';
import '../design_tokens.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/theme_switch.dart';

/// Экран настроек.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Создаёт экран настроек.
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Показывать ли подтверждение сброса прогресса (2-й шаг).
  bool _confirmReset = false;

  /// Активная категория настроек (0 — Звук, 1 — Вид, 2 — Игра, 3 — Аккаунт).
  int _category = 0;

  void _resetAll() {
    ref
        .read(profileControllerProvider.notifier)
        .replace(Profile.initial.copyWith(id: newUuidV4()));
    ref.read(settingsControllerProvider.notifier).replace(Settings.initial);
    ref.read(achievementsControllerProvider.notifier).reset();
    ref.read(statsControllerProvider.notifier).reset();
    ref.read(skinsControllerProvider.notifier).reset();
    ref.read(inventoryControllerProvider.notifier).reset();
    ref.read(dailyControllerProvider.notifier).resetToday();
    ref.read(savedGameStoreProvider).clear();
    setState(() => _confirmReset = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    final s = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    void update(Settings next) => ctrl.replace(next);

    return ScreenScaffold(
      title: 'Настройки',
      theme: theme,
      onBack: () => context.go('/'),
      children: [
        // Категории — переключение без длинной прокрутки.
        _CategoryBar(
          theme: theme,
          active: _category,
          onSelect: (i) => setState(() => _category = i),
        ),
        const SizedBox(height: 16),
        ...switch (_category) {
          0 => _soundSection(theme, s, update),
          1 => _viewSection(theme, s, update),
          2 => _gameSection(theme, s, update),
          _ => _accountSection(theme),
        },
      ],
    );
  }

  /// Категория «Звук» — эффекты, музыка, вибрация.
  List<Widget> _soundSection(
    BlockDuelTheme theme,
    Settings s,
    void Function(Settings) update,
  ) => [
    _SectionLabel(text: 'Звук', theme: theme),
    const SizedBox(height: 4),
    _ToggleRow(
      theme: theme,
      label: 'Звуковые эффекты',
      value: s.soundOn,
      onChanged: (v) => update(s.copyWith(soundOn: v)),
    ),
    if (s.soundOn)
      _SliderRow(
        theme: theme,
        label: 'Громкость эффектов',
        value: s.soundVolume,
        onChanged: (v) => update(s.copyWith(soundVolume: v)),
      ),
    _ToggleRow(
      theme: theme,
      label: 'Музыка',
      value: s.musicOn,
      onChanged: (v) => update(s.copyWith(musicOn: v)),
    ),
    if (s.musicOn)
      _SliderRow(
        theme: theme,
        label: 'Громкость музыки',
        value: s.musicVolume,
        onChanged: (v) => update(s.copyWith(musicVolume: v)),
      ),
    const SizedBox(height: 20),
    _SectionLabel(text: 'Вибрация', theme: theme),
    const SizedBox(height: 8),
    _SegmentRow<VibrationMode>(
      theme: theme,
      value: s.vibration,
      options: const {
        VibrationMode.off: 'Выкл',
        VibrationMode.light: 'Лёгкая',
        VibrationMode.strong: 'Сильная',
      },
      onChanged: (v) => update(s.copyWith(vibration: v)),
    ),
  ];

  /// Категория «Вид» — тема и анимации.
  List<Widget> _viewSection(
    BlockDuelTheme theme,
    Settings s,
    void Function(Settings) update,
  ) => [
    _SectionLabel(text: 'Тема', theme: theme),
    const SizedBox(height: 8),
    const ThemeSwitch(),
    const SizedBox(height: 20),
    _SectionLabel(text: 'Анимации и эффекты', theme: theme),
    const SizedBox(height: 4),
    _ToggleRow(
      theme: theme,
      label: 'Конфетти на perfect',
      value: s.confettiEnabled,
      onChanged: (v) => update(s.copyWith(confettiEnabled: v)),
    ),
    _ToggleRow(
      theme: theme,
      label: 'Маскоты и пони-декор',
      value: s.mascotsEnabled,
      onChanged: (v) => update(s.copyWith(mascotsEnabled: v)),
    ),
    _ToggleRow(
      theme: theme,
      label: 'Подсветка цели (призрак)',
      value: s.ghostEnabled,
      onChanged: (v) => update(s.copyWith(ghostEnabled: v)),
    ),
    _ToggleRow(
      theme: theme,
      label: 'Меньше анимаций',
      value: s.reduceMotion,
      onChanged: (v) => update(s.copyWith(reduceMotion: v)),
    ),
  ];

  /// Категория «Игра» — задержка бота и параметры матча по умолчанию.
  List<Widget> _gameSection(
    BlockDuelTheme theme,
    Settings s,
    void Function(Settings) update,
  ) => [
    _SectionLabel(text: 'Геймплей', theme: theme),
    const SizedBox(height: 8),
    _SliderRow(
      theme: theme,
      label: 'Задержка хода бота',
      value: (s.botDelayMs - 100) / 800,
      valueLabel: '${s.botDelayMs} мс',
      onChanged: (v) => update(s.copyWith(botDelayMs: (100 + v * 800).round())),
    ),
    const SizedBox(height: 16),
    _SectionLabel(text: 'Матч по умолчанию', theme: theme),
    const SizedBox(height: 8),
    _SegmentRow<String>(
      theme: theme,
      value: s.defaultBotLevel,
      options: const {'easy': 'Тупой', 'medium': 'Умный', 'hard': 'Сложный'},
      onChanged: (v) => update(s.copyWith(defaultBotLevel: v)),
    ),
    const SizedBox(height: 8),
    _ToggleRow(
      theme: theme,
      label: 'Повороты',
      value: s.defaultRotation,
      onChanged: (v) => update(s.copyWith(defaultRotation: v)),
    ),
    _ToggleRow(
      theme: theme,
      label: 'Отражения',
      value: s.defaultFlip,
      onChanged: (v) => update(s.copyWith(defaultFlip: v)),
    ),
    const SizedBox(height: 8),
    _SegmentRow<int>(
      theme: theme,
      value: s.defaultHandSize,
      options: const {1: 'Рука 1', 2: 'Рука 2', 3: 'Рука 3'},
      onChanged: (v) => update(s.copyWith(defaultHandSize: v)),
    ),
    const SizedBox(height: 8),
    _ToggleRow(
      theme: theme,
      label: s.defaultBlitz ? 'Блиц включён' : 'Без таймера',
      value: s.defaultBlitz,
      onChanged: (v) => update(s.copyWith(defaultBlitz: v)),
    ),
    if (s.defaultBlitz)
      _SegmentRow<String>(
        theme: theme,
        value: s.defaultBlitzPreset,
        options: const {
          'hardcore': 'Хардкор',
          'normal': 'Норма',
          'casual': 'Казуал',
        },
        onChanged: (v) => update(s.copyWith(defaultBlitzPreset: v)),
      ),
  ];

  /// Категория «Аккаунт» — вход, данные, о приложении.
  List<Widget> _accountSection(BlockDuelTheme theme) => [
    _SectionLabel(text: 'Аккаунт', theme: theme),
    const SizedBox(height: 8),
    _AccountSection(theme: theme),
    const SizedBox(height: 24),
    _SectionLabel(text: 'Данные', theme: theme),
    const SizedBox(height: 8),
    if (!_confirmReset)
      TextButton(
        onPressed: () => setState(() => _confirmReset = true),
        child: Text(
          '⚠ Сбросить весь прогресс',
          style: TextStyle(color: theme.bad, fontSize: 14),
        ),
      )
    else ...[
      Text(
        'Удалит профиль, статистику, ачивки и сохранёнку. Необратимо.',
        style: TextStyle(color: theme.bad, fontSize: 13),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          TextButton(
            onPressed: _resetAll,
            child: Text(
              'Да, удалить всё',
              style: TextStyle(color: theme.bad, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _confirmReset = false),
            child: Text('Отмена', style: TextStyle(color: theme.muted)),
          ),
        ],
      ),
    ],
    const SizedBox(height: 24),
    _SectionLabel(text: 'О приложении', theme: theme),
    const SizedBox(height: 8),
    Text(
      'BlockDuel 9×9 · v2.0.0 (flutter)\n'
      'Соревновательный блок-пазл на поле 9×9.',
      style: TextStyle(color: theme.muted, fontSize: 13, height: 1.4),
    ),
  ];
}

/// Панель категорий настроек (вкладки).
class _CategoryBar extends StatelessWidget {
  final BlockDuelTheme theme;
  final int active;
  final ValueChanged<int> onSelect;

  const _CategoryBar({
    required this.theme,
    required this.active,
    required this.onSelect,
  });

  static const List<(String, String)> _cats = [
    ('🔊', 'Звук'),
    ('🎨', 'Вид'),
    ('🎮', 'Игра'),
    ('👤', 'Аккаунт'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(theme.btnRadius),
        border: Border.all(color: theme.line),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _cats.length; i++)
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onSelect(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == active ? theme.p0 : Colors.transparent,
                      borderRadius: BorderRadius.circular(theme.btnRadius - 3),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_cats[i].$1, style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(
                          _cats[i].$2,
                          style: TextStyle(
                            color: i == active ? theme.bg : theme.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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

/// Строка-слайдер настройки (значение 0..1).
class _SliderRow extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final double value;
  final String? valueLabel;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.theme,
    required this.label,
    required this.value,
    required this.onChanged,
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: theme.ink, fontSize: 14)),
              Text(
                valueLabel ?? '${(value * 100).round()}%',
                style: TextStyle(
                  color: theme.muted,
                  fontSize: 12,
                  fontFamily: theme.fontMono,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: theme.p0,
              thumbColor: theme.p0,
              inactiveTrackColor: theme.line,
            ),
            child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// Сегментированный переключатель настройки из вариантов [options].
class _SegmentRow<T> extends StatelessWidget {
  final BlockDuelTheme theme;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  const _SegmentRow({
    required this.theme,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(theme.btnRadius),
        border: Border.all(color: theme.line),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onChanged(entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.key == value ? theme.p0 : Colors.transparent,
                      borderRadius: BorderRadius.circular(theme.btnRadius - 3),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: entry.key == value ? theme.bg : theme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
