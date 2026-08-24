/// quests_screen.dart — экран квестов: ежедневные / недельные / сезонные (View).
///
/// За что отвечает файл:
///   Объединяет три периода квестов во вкладках: ежедневные (из
///   `DailyController`) и недельные/сезонные (из `QuestsController`). Для
///   каждого квеста — прогресс-бар, награда и кнопка «Забрать» при выполнении.
///   Тонкий View: вся логика прогресса/выдачи — в контроллерах.
///
/// Соответствие ROADMAP: § 8.4 (UI `QuestsScreen` с прогресс-барами и claim).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../daily/daily.dart' as daily;
import '../../daily/daily_controller.dart';
import '../../quests/quest.dart';
import '../../quests/quests_controller.dart';
import '../decor/theme_backdrop.dart';
import '../design_tokens.dart';

/// Экран квестов с тремя вкладками.
class QuestsScreen extends ConsumerWidget {
  /// Создаёт экран.
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    // Открытие после смены недели/сезона должно показать новый набор квестов:
    // провайдер keepAlive не пересобирается сам. Идемпотентно, после кадра.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(questsControllerProvider.notifier).refreshPeriods(),
    );
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: tokens.bg,
        body: Stack(
          children: [
            const ThemeBackdrop(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 16, 0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.go('/'),
                              icon: Icon(Icons.arrow_back, color: tokens.ink),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '🎯 Квесты',
                              style: TextStyle(
                                color: tokens.ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                fontFamily: tokens.fontDisplay,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TabBar(
                        labelColor: tokens.p0,
                        unselectedLabelColor: tokens.muted,
                        indicatorColor: tokens.p0,
                        tabs: const [
                          Tab(text: 'День'),
                          Tab(text: 'Неделя'),
                          Tab(text: 'Сезон'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _DailyTab(tokens: tokens),
                            _PeriodTab(
                              tokens: tokens,
                              period: QuestPeriod.weekly,
                            ),
                            _PeriodTab(
                              tokens: tokens,
                              period: QuestPeriod.seasonal,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Вкладка ежедневных квестов (источник — `DailyController`).
class _DailyTab extends ConsumerWidget {
  final BlockDuelTheme tokens;

  const _DailyTab({required this.tokens});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyControllerProvider);
    final ctrl = ref.read(dailyControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _Hint(tokens: tokens, text: 'Обновляются каждый день в 00:00.'),
        for (final id in state.questIds)
          if (daily.questById(id) case final q?)
            _QuestCard(
              tokens: tokens,
              icon: q.icon,
              title: q.title,
              progress: state.progress[id] ?? 0,
              target: q.target,
              coins: q.reward,
              crystals: 0,
              claimed: state.claimed.contains(id),
              onClaim: () => ctrl.claim(id),
            ),
      ],
    );
  }
}

/// Вкладка недельных/сезонных квестов (источник — `QuestsController`).
class _PeriodTab extends ConsumerWidget {
  final BlockDuelTheme tokens;
  final QuestPeriod period;

  const _PeriodTab({required this.tokens, required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(questsControllerProvider).forPeriod(period);
    final ctrl = ref.read(questsControllerProvider.notifier);
    final hint = period == QuestPeriod.weekly
        ? 'Обновляются раз в неделю.'
        : 'Сезон длится 90 дней.';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _Hint(tokens: tokens, text: hint),
        for (final id in state.questIds)
          if (questById(id) case final q?)
            _QuestCard(
              tokens: tokens,
              icon: q.icon,
              title: q.title,
              progress: state.progress[id] ?? 0,
              target: q.target,
              coins: q.rewardCoins,
              crystals: q.rewardCrystals,
              claimed: state.claimed.contains(id),
              onClaim: () => ctrl.claim(period, id),
            ),
      ],
    );
  }
}

/// Подсказка-строка над списком квестов.
class _Hint extends StatelessWidget {
  final BlockDuelTheme tokens;
  final String text;

  const _Hint({required this.tokens, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(text, style: TextStyle(color: tokens.muted, fontSize: 12)),
    );
  }
}

/// Карточка квеста: иконка, заголовок, прогресс, награда, кнопка «Забрать».
class _QuestCard extends StatelessWidget {
  final BlockDuelTheme tokens;
  final String icon;
  final String title;
  final int progress;
  final int target;
  final int coins;
  final int crystals;
  final bool claimed;
  final VoidCallback onClaim;

  const _QuestCard({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.progress,
    required this.target,
    required this.coins,
    required this.crystals,
    required this.claimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final done = progress >= target;
    final ratio = target == 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(
          color: done && !claimed ? tokens.p0 : tokens.line,
          width: done && !claimed ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _RewardChip(tokens: tokens, coins: coins, crystals: crystals),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: tokens.line,
                    valueColor: AlwaysStoppedAnimation(
                      done ? tokens.good : tokens.p0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$progress/$target',
                style: TextStyle(color: tokens.muted, fontSize: 12),
              ),
            ],
          ),
          if (done) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: claimed
                  ? Text(
                      '✓ Награда получена',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tokens.good,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : FilledButton(
                      onPressed: onClaim,
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.p0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Забрать награду'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Чип награды: монеты (+ кристаллы).
class _RewardChip extends StatelessWidget {
  final BlockDuelTheme tokens;
  final int coins;
  final int crystals;

  const _RewardChip({
    required this.tokens,
    required this.coins,
    required this.crystals,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('🪙 $coins', style: TextStyle(color: tokens.ink, fontSize: 13)),
        if (crystals > 0) ...[
          const SizedBox(width: 8),
          Text('💎 $crystals', style: TextStyle(color: tokens.ink, fontSize: 13)),
        ],
      ],
    );
  }
}
