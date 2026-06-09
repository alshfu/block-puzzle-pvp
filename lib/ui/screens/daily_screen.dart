/// daily_screen.dart — экран ежедневных квестов (View).
///
/// За что отвечает файл:
///   Показывает квесты на сегодня с прогресс-полосой и кнопкой получения
///   награды. Чистый View: данные и команды — из [DailyController]; определения
///   квестов — из пула. Логика прогресса/наград — во ViewModel.
///
/// Соответствие TS: `screens/DailyScreen.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../daily/daily.dart';
import '../../daily/daily_controller.dart';
import '../design_tokens.dart';
import '../widgets/screen_scaffold.dart';

/// Экран ежедневных квестов.
class DailyScreen extends ConsumerWidget {
  /// Создаёт экран ежедневных квестов.
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    final daily = ref.watch(dailyControllerProvider);
    final ctrl = ref.read(dailyControllerProvider.notifier);

    return ScreenScaffold(
      title: 'Ежедневные квесты',
      theme: theme,
      onBack: () => context.go('/'),
      children: [
        Text(
          'Обновляются каждый день',
          style: TextStyle(color: theme.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (final id in daily.questIds)
          if (questById(id) case final quest?)
            _QuestTile(
              theme: theme,
              quest: quest,
              progress: daily.progress[id] ?? 0,
              claimed: daily.claimed.contains(id),
              onClaim: () => ctrl.claim(id),
            ),
      ],
    );
  }
}

/// Плитка одного квеста с прогрессом и кнопкой награды.
class _QuestTile extends StatelessWidget {
  final BlockDuelTheme theme;
  final DailyQuest quest;
  final int progress;
  final bool claimed;
  final VoidCallback onClaim;

  const _QuestTile({
    required this.theme,
    required this.quest,
    required this.progress,
    required this.claimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (progress / quest.target).clamp(0.0, 1.0);
    final done = progress >= quest.target;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(
          color: done ? theme.good : theme.line,
          width: done ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(quest.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: TextStyle(
                        color: theme.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Награда: ${quest.reward} 🪙',
                      style: TextStyle(color: theme.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _ClaimButton(
                theme: theme,
                claimed: claimed,
                done: done,
                onClaim: onClaim,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(theme.btnRadius),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: theme.panel2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      done ? theme.good : theme.p0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$progress/${quest.target}',
                style: TextStyle(
                  color: theme.muted,
                  fontSize: 12,
                  fontFamily: theme.fontMono,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Кнопка получения награды (или метка «получено»).
class _ClaimButton extends StatelessWidget {
  final BlockDuelTheme theme;
  final bool claimed;
  final bool done;
  final VoidCallback onClaim;

  const _ClaimButton({
    required this.theme,
    required this.claimed,
    required this.done,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    if (claimed) {
      return Icon(Icons.check_circle, color: theme.good, size: 22);
    }
    return Material(
      color: done ? theme.p0 : theme.panel2,
      borderRadius: BorderRadius.circular(theme.btnRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.btnRadius),
        onTap: done ? onClaim : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Забрать',
            style: TextStyle(
              color: done
                  ? (theme.kind == Brightness.dark
                        ? const Color(0xFF0B0E13)
                        : Colors.white)
                  : theme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
