/// online_menu_screen.dart — экран онлайна: матчмейкинг + вход в лидерборд.
///
/// За что отвечает файл:
///   `/online`. Кнопка «Найти соперника» ставит в очередь ([LobbyNotifier]);
///   показывает позицию ожидания; на `matched` навигирует в живой матч
///   (передавая профили через `extra`); на `bot_fallback` предлагает локального
///   бота. Чистый View по MVVM: команды уходят в ViewModel, навигация — через
///   go_router.
///
/// Соответствие TS: `screens/OnlineMenu.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../online/lobby_notifier.dart';
import '../../../online/online_models.dart';
import '../../../profile/profile_controller.dart';
import '../../design_tokens.dart';
import '../../widgets/screen_scaffold.dart';

/// Экран онлайн-меню (матчмейкинг + лидерборд).
class OnlineMenuScreen extends ConsumerWidget {
  /// Создаёт экран.
  const OnlineMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    final lobby = ref.watch(lobbyProvider);

    // Навигация по итогам матчмейкинга.
    ref.listen(lobbyProvider, (prev, next) {
      if (next is LobbyMatched) {
        final me = OnlineProfile.fromProfile(
          ref.read(profileControllerProvider),
        );
        context.go(
          '/online/game/${next.roomId}',
          extra: OnlineGameArgs(opponent: next.opponent, me: me),
        );
      } else if (next is LobbyBotFallback) {
        context.go('/game/bot');
      }
    });

    return ScreenScaffold(
      title: 'Онлайн',
      theme: tokens,
      onBack: () {
        ref.read(lobbyProvider.notifier).cancel();
        context.go('/');
      },
      children: [
        const SizedBox(height: 12),
        _LobbyBody(tokens: tokens, lobby: lobby),
        const SizedBox(height: 24),
        _LeaderboardLink(tokens: tokens),
      ],
    );
  }
}

/// Центральная часть: статус очереди и кнопки.
class _LobbyBody extends ConsumerWidget {
  final BlockDuelTheme tokens;
  final LobbyState lobby;

  const _LobbyBody({required this.tokens, required this.lobby});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(lobbyProvider.notifier);

    void startQueue() {
      final me = OnlineProfile.fromProfile(ref.read(profileControllerProvider));
      notifier.queue(me);
    }

    return switch (lobby) {
      LobbyIdle() || LobbyMatched() => _BigButton(
        tokens: tokens,
        label: '🎮 Найти соперника',
        onTap: startQueue,
      ),
      LobbyQueued(:final position, :final waitedSec) => Column(
        children: [
          CircularProgressIndicator(color: tokens.p0),
          const SizedBox(height: 16),
          Text(
            'Поиск соперника…',
            style: TextStyle(
              color: tokens.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'позиция $position · ждём $waitedSec с',
            style: TextStyle(
              color: tokens.muted,
              fontSize: 13,
              fontFamily: tokens.fontMono,
            ),
          ),
          const SizedBox(height: 16),
          _BigButton(
            tokens: tokens,
            label: 'Отмена',
            ghost: true,
            onTap: notifier.cancel,
          ),
        ],
      ),
      LobbyBotFallback() => Column(
        children: [
          Text(
            'Соперник не найден — играем с ботом.',
            style: TextStyle(color: tokens.muted, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _BigButton(
            tokens: tokens,
            label: '🤖 Играть с ботом',
            onTap: () => context.go('/game/bot'),
          ),
        ],
      ),
      LobbyError(:final reason) => Column(
        children: [
          Text(
            'Ошибка: $reason',
            style: TextStyle(color: tokens.bad, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _BigButton(tokens: tokens, label: 'Повторить', onTap: startQueue),
        ],
      ),
    };
  }
}

/// Кнопка перехода к лидерборду.
class _LeaderboardLink extends StatelessWidget {
  final BlockDuelTheme tokens;
  const _LeaderboardLink({required this.tokens});

  @override
  Widget build(BuildContext context) => _BigButton(
    tokens: tokens,
    label: '🏆 Таблица лидеров',
    ghost: true,
    onTap: () => context.go('/leaderboard'),
  );
}

/// Крупная кнопка (основная или «призрак»).
class _BigButton extends StatelessWidget {
  final BlockDuelTheme tokens;
  final String label;
  final bool ghost;
  final VoidCallback onTap;

  const _BigButton({
    required this.tokens,
    required this.label,
    required this.onTap,
    this.ghost = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: ghost ? Colors.transparent : tokens.p0,
        borderRadius: BorderRadius.circular(tokens.btnRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.btnRadius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.btnRadius),
              border: ghost ? Border.all(color: tokens.line) : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: ghost ? tokens.ink : tokens.bg,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
