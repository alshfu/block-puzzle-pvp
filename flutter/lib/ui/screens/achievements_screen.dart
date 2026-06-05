/// achievements_screen.dart — экран достижений (View).
///
/// За что отвечает файл:
///   Список всех достижений с пометкой разблокировано/закрыто и счётчиком
///   прогресса. Чистый View: каталог из [achievementDefinitions], множество
///   разблокированных — из [AchievementsController].
///
/// Соответствие TS: `screens/AchievementsScreen.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../achievements/achievements_controller.dart';
import '../../achievements/definitions.dart';
import '../design_tokens.dart';
import '../widgets/screen_scaffold.dart';

/// Экран достижений.
class AchievementsScreen extends ConsumerWidget {
  /// Создаёт экран достижений.
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    final unlocked = ref.watch(achievementsControllerProvider);

    return ScreenScaffold(
      title: 'Достижения · ${unlocked.length}/${achievementDefinitions.length}',
      theme: theme,
      onBack: () => context.go('/'),
      children: [
        for (final a in achievementDefinitions)
          _AchievementTile(
            theme: theme,
            icon: a.icon,
            title: a.title,
            description: a.description,
            unlocked: unlocked.contains(a.id),
          ),
      ],
    );
  }
}

/// Плитка одного достижения.
class _AchievementTile extends StatelessWidget {
  final BlockDuelTheme theme;
  final String icon;
  final String title;
  final String description;
  final bool unlocked;

  const _AchievementTile({
    required this.theme,
    required this.icon,
    required this.title,
    required this.description,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.panel,
          borderRadius: BorderRadius.circular(theme.cardRadius),
          border: Border.all(
            color: unlocked ? theme.p0 : theme.line,
            width: unlocked ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(unlocked ? icon : '🔒', style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(color: theme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (unlocked) Icon(Icons.check_circle, color: theme.good, size: 20),
          ],
        ),
      ),
    );
  }
}
