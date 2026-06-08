/// profile_screen.dart — экран профиля игрока (View).
///
/// За что отвечает файл:
///   Показывает аватар, ник (с возможностью смены), уровень с XP-полосой,
///   монеты и статистику матчей. Чистый View: данные из [ProfileController],
///   команды смены ника/аватара — туда же. Логики прогрессии здесь нет.
///
/// Соответствие TS: `screens/ProfileScreen.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../achievements/stats_controller.dart';
import '../../profile/profile_controller.dart';
import '../design_tokens.dart';
import '../widgets/screen_scaffold.dart';

/// Набор аватаров для выбора.
const List<String> _avatars = ['🙂', '😎', '🦊', '🐲', '🦄', '🤖', '👾', '🐱'];

/// Экран профиля.
class ProfileScreen extends ConsumerWidget {
  /// Создаёт экран профиля.
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    final profile = ref.watch(profileControllerProvider);
    final stats = ref.watch(statsControllerProvider);
    final ctrl = ref.read(profileControllerProvider.notifier);
    final winrate = stats.games == 0
        ? 0
        : (stats.wins * 100 / stats.games).round();
    final xpRatio = profile.xpForNextLevel == 0
        ? 0.0
        : (profile.xpInLevel / profile.xpForNextLevel).clamp(0.0, 1.0);

    return ScreenScaffold(
      title: 'Профиль',
      theme: theme,
      onBack: () => context.go('/'),
      children: [
        Center(
          child: Text(profile.avatar, style: const TextStyle(fontSize: 64)),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final a in _avatars)
              _AvatarChip(
                emoji: a,
                selected: a == profile.avatar,
                theme: theme,
                onTap: () => ctrl.setAvatar(a),
              ),
          ],
        ),
        const SizedBox(height: 20),
        TextFormField(
          initialValue: profile.nick,
          onFieldSubmitted: ctrl.setNick,
          style: TextStyle(color: theme.ink),
          decoration: InputDecoration(
            labelText: 'Ник',
            labelStyle: TextStyle(color: theme.muted),
            filled: true,
            fillColor: theme.panel,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.btnRadius),
              borderSide: BorderSide(color: theme.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.btnRadius),
              borderSide: BorderSide(color: theme.p0, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _StatPanel(
          theme: theme,
          rows: [
            ('Уровень', '${profile.level}'),
            ('Монеты', '${profile.coins} 🪙'),
            ('Партий', '${stats.games}'),
            ('Побед', '${stats.wins}'),
            ('Винрейт', '$winrate%'),
            ('Рекорд за партию', '${stats.bestScore}'),
            ('Лучшая мульти-очистка', '×${stats.maxMultiClear}'),
            ('Очищено линий/боксов', '${stats.totalClears}'),
            ('Серия побед', '${stats.currentWinStreak}'),
            ('Лучшая серия', '${stats.bestWinStreak}'),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'XP: ${profile.xpInLevel} / ${profile.xpForNextLevel}',
            style: TextStyle(color: theme.muted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(theme.btnRadius),
          child: LinearProgressIndicator(
            value: xpRatio,
            minHeight: 10,
            backgroundColor: theme.panel2,
            valueColor: AlwaysStoppedAnimation<Color>(theme.p0),
          ),
        ),
      ],
    );
  }
}

/// Чип выбора аватара.
class _AvatarChip extends StatelessWidget {
  final String emoji;
  final bool selected;
  final BlockDuelTheme theme;
  final VoidCallback onTap;

  const _AvatarChip({
    required this.emoji,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(theme.btnRadius),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.panel,
          borderRadius: BorderRadius.circular(theme.btnRadius),
          border: Border.all(
            color: selected ? theme.p0 : theme.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
      ),
    );
  }
}

/// Панель «строк статистики».
class _StatPanel extends StatelessWidget {
  final BlockDuelTheme theme;
  final List<(String, String)> rows;

  const _StatPanel({required this.theme, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r.$1, style: TextStyle(color: theme.muted)),
                  Text(
                    r.$2,
                    style: TextStyle(
                      color: theme.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
