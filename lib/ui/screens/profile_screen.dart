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
import '../../profile/level_rewards.dart';
import '../../profile/profile_controller.dart';
import '../design_tokens.dart';
import '../icons/game_icons.dart';
import '../widgets/avatar_view.dart';
import '../widgets/screen_scaffold.dart';

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
          child: AvatarView(value: profile.avatar, size: 64, color: theme.p0),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final a in avatarIds)
              _AvatarChip(
                value: a,
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
        const SizedBox(height: 12),
        _NextRewardCard(
          theme: theme,
          level: profile.level,
          xpToNext: profile.xpForNextLevel - profile.xpInLevel,
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => context.go('/stats'),
          icon: const Text('📊', style: TextStyle(fontSize: 18)),
          label: const Text('Подробная статистика'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.ink,
            side: BorderSide(color: theme.line),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(theme.btnRadius),
            ),
          ),
        ),
      ],
    );
  }
}

/// Чип выбора аватара.
class _AvatarChip extends StatelessWidget {
  final String value;
  final bool selected;
  final BlockDuelTheme theme;
  final VoidCallback onTap;

  const _AvatarChip({
    required this.value,
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
        child: Center(
          child: AvatarView(
            value: value,
            size: 24,
            color: selected ? theme.p0 : theme.ink,
          ),
        ),
      ),
    );
  }
}

/// Карточка-превью награды за следующий уровень (ROADMAP § 8.2).
class _NextRewardCard extends StatelessWidget {
  final BlockDuelTheme theme;
  final int level;
  final int xpToNext;

  const _NextRewardCard({
    required this.theme,
    required this.level,
    required this.xpToNext,
  });

  @override
  Widget build(BuildContext context) {
    // На максимальном уровне (100) награждать больше нечем.
    if (level >= 100) {
      return _wrap(
        context,
        Text(
          'Максимальный уровень достигнут 🏆',
          style: TextStyle(color: theme.ink, fontWeight: FontWeight.w700),
        ),
      );
    }
    final next = level + 1;
    final reward = rewardForLevel(next);
    final parts = <String>[
      if (reward.coins > 0) '+${reward.coins} 🪙',
      if (reward.crystals > 0) '+${reward.crystals} 💎',
      if (reward.unlock == mirrorPiecesUnlock) 'зеркальный набор фигур',
    ];
    return _wrap(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'До уровня $next: $xpToNext XP',
            style: TextStyle(color: theme.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Награда: ${parts.join(' · ')}',
            style: TextStyle(color: theme.ink, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _wrap(BuildContext context, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: theme.panel,
      borderRadius: BorderRadius.circular(theme.cardRadius),
      border: Border.all(color: theme.line),
    ),
    child: Row(
      children: [
        const Text('🎁', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    ),
  );
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
