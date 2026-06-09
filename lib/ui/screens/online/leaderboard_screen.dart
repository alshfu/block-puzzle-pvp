/// leaderboard_screen.dart — таблица лидеров ELO (View).
///
/// За что отвечает файл:
///   `/leaderboard`. Подписывается на [LeaderboardNotifier] (id из профиля),
///   рисует топ игроков и отдельную строку «мой ранг», если игрок вне топа.
///   Чистый View: данные из ViewModel, навигация — go_router.
///
/// Соответствие TS: `screens/LeaderboardScreen.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../online/leaderboard_notifier.dart';
import '../../../online/online_models.dart';
import '../../../profile/profile_controller.dart';
import '../../design_tokens.dart';
import '../../widgets/screen_scaffold.dart';

/// Экран таблицы лидеров.
class LeaderboardScreen extends ConsumerWidget {
  /// Создаёт экран.
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    final myId = ref.watch(profileControllerProvider.select((p) => p.id));
    final board = ref.watch(leaderboardProvider(myId));

    final inTop = board.entries.any((e) => e.id == myId);

    return ScreenScaffold(
      title: 'Таблица лидеров',
      theme: tokens,
      onBack: () => context.go('/online'),
      children: [
        if (!board.connected && board.entries.isEmpty) ...[
          const SizedBox(height: 40),
          Center(child: CircularProgressIndicator(color: tokens.p0)),
        ] else if (board.entries.isEmpty) ...[
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Пока никто не сыграл онлайн.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          for (var i = 0; i < board.entries.length; i++)
            _Row(
              tokens: tokens,
              rank: i + 1,
              entry: board.entries[i],
              me: board.entries[i].id == myId,
            ),
          if (!inTop && board.you != null && board.yourRank != null) ...[
            const SizedBox(height: 12),
            Text(
              'Ваше место',
              style: TextStyle(color: tokens.muted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            _Row(
              tokens: tokens,
              rank: board.yourRank!,
              entry: board.you!,
              me: true,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'всего игроков: ${board.total}',
            style: TextStyle(
              color: tokens.muted,
              fontSize: 11,
              fontFamily: tokens.fontMono,
            ),
          ),
        ],
      ],
    );
  }
}

/// Строка таблицы: ранг, аватар, ник, ELO, W/L/D.
class _Row extends StatelessWidget {
  final BlockDuelTheme tokens;
  final int rank;
  final LeaderboardEntry entry;
  final bool me;

  const _Row({
    required this.tokens,
    required this.rank,
    required this.entry,
    required this.me,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(
          color: me ? tokens.p0 : tokens.line,
          width: me ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                color: tokens.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: tokens.fontMono,
              ),
            ),
          ),
          Text(entry.avatar, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.nick,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.elo}',
                style: TextStyle(
                  color: tokens.p0,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFamily: tokens.fontMono,
                ),
              ),
              Text(
                '${entry.wins}/${entry.losses}/${entry.draws}',
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 10.5,
                  fontFamily: tokens.fontMono,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
