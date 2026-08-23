/// season_pass_screen.dart — экран сезонного пропуска (View, § 10.4).
///
/// За что отвечает файл:
///   Показывает прогресс 90-дневного пропуска: текущий уровень и XP до
///   следующего, статус/покупку премиум-трека (за кристаллы) и список 50
///   уровней с наградами бесплатного и премиум-треков и кнопками «забрать».
///   Начисление наград при claim — через [ProfileController]; прогресс/claimed —
///   в [SeasonPassController]. Чистый View по MVVM.
///
/// Соответствие ROADMAP: § 10.4 (серверная валидация — 🔒).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/profile_controller.dart';
import '../../progression/season_pass.dart';
import '../../progression/season_pass_controller.dart';
import '../design_tokens.dart';
import '../widgets/screen_scaffold.dart';

/// Экран сезонного пропуска.
class SeasonPassScreen extends ConsumerWidget {
  /// Создаёт экран.
  const SeasonPassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    final pass = ref.watch(seasonPassControllerProvider);
    final ratio = seasonXpInTier(pass.xp) / seasonXpPerTier;

    void grant(SeasonReward? r) {
      if (r == null) return;
      final p = ref.read(profileControllerProvider.notifier);
      if (r.coins > 0) p.addCoins(r.coins);
      if (r.crystals > 0) p.addCrystals(r.crystals);
    }

    return ScreenScaffold(
      title: 'Сезонный пропуск',
      theme: theme,
      onBack: () => context.go('/'),
      children: [
        // Шапка прогресса.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.panel,
            borderRadius: BorderRadius.circular(theme.cardRadius),
            border: Border.all(color: theme.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Уровень ${pass.tier} / $seasonTiers',
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFamily: theme.fontDisplay,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(theme.btnRadius),
                child: LinearProgressIndicator(
                  value: pass.tier >= seasonTiers ? 1.0 : ratio,
                  minHeight: 10,
                  backgroundColor: theme.panel2,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.p0),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                pass.tier >= seasonTiers
                    ? 'Пропуск пройден полностью 🏆'
                    : 'XP: ${seasonXpInTier(pass.xp)} / $seasonXpPerTier до '
                        'уровня ${pass.tier + 1}',
                style: TextStyle(color: theme.muted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'XP начисляется за матчи. Сезон — $seasonDays дней.',
                style: TextStyle(color: theme.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Премиум.
        if (!pass.premium)
          FilledButton.icon(
            onPressed: () {
              // Атомарная проверка+списание по СВЕЖЕМУ балансу (ref.read):
              // защищает от двойной траты при быстром повторном тапе, пока
              // виджет не перестроился. buyPremium() — только при успехе.
              final ok = ref
                  .read(profileControllerProvider.notifier)
                  .spendCrystals(seasonPremiumPrice);
              if (!ok) {
                final have = ref.read(profileControllerProvider).crystals;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Нужно $seasonPremiumPrice 💎 (у тебя $have)'),
                  ),
                );
                return;
              }
              ref.read(seasonPassControllerProvider.notifier).buyPremium();
            },
            icon: const Icon(Icons.workspace_premium),
            label: Text('Купить премиум-трек — $seasonPremiumPrice 💎'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.p0,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          )
        else
          Row(
            children: [
              Icon(Icons.workspace_premium, color: theme.good, size: 18),
              const SizedBox(width: 6),
              Text('Премиум-трек активен',
                  style: TextStyle(
                      color: theme.good, fontWeight: FontWeight.w700)),
            ],
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text('Уровень',
                  style: TextStyle(color: theme.muted, fontSize: 11)),
            ),
            Expanded(
              flex: 2,
              child: Text('Бесплатно',
                  style: TextStyle(color: theme.muted, fontSize: 11)),
            ),
            Expanded(
              flex: 2,
              child: Text('Премиум',
                  style: TextStyle(color: theme.muted, fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (int tier = 1; tier <= seasonTiers; tier++)
          _TierRow(
            theme: theme,
            tier: tier,
            reached: tier <= pass.tier,
            premiumOwned: pass.premium,
            freeClaimed: pass.claimedFree.contains(tier),
            premiumClaimed: pass.claimedPremium.contains(tier),
            free: seasonFreeReward(tier),
            premium: seasonPremiumReward(tier),
            onClaimFree: () => grant(
              ref.read(seasonPassControllerProvider.notifier).claimFree(tier),
            ),
            onClaimPremium: () => grant(
              ref.read(seasonPassControllerProvider.notifier).claimPremium(tier),
            ),
          ),
      ],
    );
  }
}

/// Строка одного уровня пропуска.
class _TierRow extends StatelessWidget {
  final BlockDuelTheme theme;
  final int tier;
  final bool reached;
  final bool premiumOwned;
  final bool freeClaimed;
  final bool premiumClaimed;
  final SeasonReward free;
  final SeasonReward premium;
  final VoidCallback onClaimFree;
  final VoidCallback onClaimPremium;

  const _TierRow({
    required this.theme,
    required this.tier,
    required this.reached,
    required this.premiumOwned,
    required this.freeClaimed,
    required this.premiumClaimed,
    required this.free,
    required this.premium,
    required this.onClaimFree,
    required this.onClaimPremium,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(theme.btnRadius),
        border: Border.all(color: reached ? theme.p0 : theme.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$tier',
              style: TextStyle(
                color: theme.ink,
                fontWeight: FontWeight.w800,
                fontFamily: theme.fontMono,
              ),
            ),
          ),
          Expanded(flex: 2, child: _cell(theme, free, freeClaimed, reached, onClaimFree, true)),
          Expanded(
            flex: 2,
            child: _cell(theme, premium, premiumClaimed, reached && premiumOwned,
                onClaimPremium, premiumOwned),
          ),
        ],
      ),
    );
  }

  /// Ячейка награды трека: текст + статус/кнопка «забрать».
  Widget _cell(BlockDuelTheme theme, SeasonReward r, bool claimed,
      bool claimable, VoidCallback onClaim, bool trackAvailable) {
    final label = [
      if (r.coins > 0) '${r.coins}🪙',
      if (r.crystals > 0) '${r.crystals}💎',
    ].join(' ');
    if (claimed) {
      return Row(children: [
        Icon(Icons.check, size: 14, color: theme.good),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              style: TextStyle(color: theme.muted, fontSize: 11)),
        ),
      ]);
    }
    if (!trackAvailable) {
      return Text(label, style: TextStyle(color: theme.muted, fontSize: 11));
    }
    return InkWell(
      onTap: claimable ? onClaim : null,
      child: Text(
        claimable ? '$label ▸' : label,
        style: TextStyle(
          color: claimable ? theme.p0 : theme.muted,
          fontSize: 11,
          fontWeight: claimable ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}
