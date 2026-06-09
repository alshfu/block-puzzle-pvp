/// achievements_screen.dart — экран достижений (View).
///
/// За что отвечает файл:
///   Все достижения, сгруппированные по категориям, с прогресс-барами, скрытыми
///   (❓ до разблокировки) и наградой XP. Чистый View: каталог из
///   [achievementDefinitions], прогресс — из [AchievementsController].
///
/// Соответствие TS: `screens/AchievementsScreen.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../achievements/achievement.dart';
import '../../achievements/achievements_controller.dart';
import '../../achievements/definitions.dart';
import '../design_tokens.dart';
import '../widgets/screen_scaffold.dart';

/// Заголовки категорий.
const Map<AchievementCategory, String> _categoryTitles = {
  AchievementCategory.single: 'Вехи',
  AchievementCategory.progressive: 'Прогресс',
  AchievementCategory.series: 'Серии побед',
  AchievementCategory.hidden: 'Секреты',
  AchievementCategory.online: 'Онлайн PvP',
};

/// Экран достижений.
class AchievementsScreen extends ConsumerWidget {
  /// Создаёт экран достижений.
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    final progress = ref.watch(achievementsControllerProvider);
    final unlockedCount = progress.values.where((p) => p.unlocked).length;

    return ScreenScaffold(
      title: 'Достижения · $unlockedCount/${achievementDefinitions.length}',
      theme: theme,
      onBack: () => context.go('/'),
      children: [
        for (final category in AchievementCategory.values)
          ..._categorySection(theme, category, progress),
      ],
    );
  }

  List<Widget> _categorySection(
    BlockDuelTheme theme,
    AchievementCategory category,
    Map<String, AchProgress> progress,
  ) {
    final defs = achievementDefinitions
        .where((a) => a.category == category)
        .toList();
    if (defs.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(
          _categoryTitles[category]!.toUpperCase(),
          style: TextStyle(
            color: theme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
      for (final a in defs)
        _AchievementTile(
          theme: theme,
          def: a,
          progress: progress[a.id] ?? const AchProgress(),
        ),
    ];
  }
}

/// Плитка одного достижения с прогрессом.
class _AchievementTile extends StatelessWidget {
  final BlockDuelTheme theme;
  final AchievementDef def;
  final AchProgress progress;

  const _AchievementTile({
    required this.theme,
    required this.def,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = progress.unlocked;
    final secret = def.hidden && !unlocked;
    final icon = unlocked ? def.icon : (secret ? '❓' : def.icon);
    final title = secret ? '???' : def.title;
    final description = secret ? 'разблокируй, чтобы узнать' : def.description;
    final showBar = !secret && def.total > 1 && !unlocked;
    final current = progress.current.clamp(0, def.total);

    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: theme.panel,
          borderRadius: BorderRadius.circular(theme.cardRadius),
          border: Border.all(
            color: unlocked ? theme.p0 : theme.line,
            width: unlocked ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(color: theme.muted, fontSize: 11.5),
                  ),
                  if (showBar) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: current / def.total,
                        minHeight: 5,
                        backgroundColor: theme.line,
                        valueColor: AlwaysStoppedAnimation(theme.p0),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$current / ${def.total}',
                      style: TextStyle(
                        color: theme.muted,
                        fontSize: 10,
                        fontFamily: theme.fontMono,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${def.rewardXp}',
                  style: TextStyle(
                    color: theme.p0,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: theme.fontMono,
                  ),
                ),
                if (unlocked)
                  Icon(Icons.check_circle, color: theme.good, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
