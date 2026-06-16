/// match3_screen.dart — экран режима «Match-3 PvP» (View).
///
/// За что отвечает файл:
///   Тонкий View поверх [Match3Notifier]: табло обоих игроков с подсветкой
///   активного и счётчиком оставшихся ходов, поле 8×8 ([Match3BoardView]) и
///   оверлей итога. Логики нет — тапы делегируются ViewModel; seed берётся из
///   системного времени.
///
/// Соответствие ROADMAP: § 5.5 (Match-3 PvP, hot-seat).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../modes/match3/match3_notifier.dart';
import '../decor/theme_backdrop.dart';
import '../design_tokens.dart';
import '../widgets/match3_board_view.dart';

/// Экран режима «Match-3 PvP».
class Match3Screen extends ConsumerStatefulWidget {
  /// Создаёт экран.
  const Match3Screen({super.key});

  @override
  ConsumerState<Match3Screen> createState() => _Match3ScreenState();
}

class _Match3ScreenState extends ConsumerState<Match3Screen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _newGame());
  }

  void _newGame() {
    final seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    ref.read(match3Provider.notifier).newGame(seed);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    final state = ref.watch(match3Provider);
    final notifier = ref.read(match3Provider.notifier);
    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          const ThemeBackdrop(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.go('/'),
                            icon: Icon(Icons.arrow_back, color: tokens.ink),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '🍬 Match-3 PvP',
                            style: TextStyle(
                              color: tokens.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              fontFamily: tokens.fontDisplay,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _newGame,
                            icon: Icon(Icons.refresh, color: tokens.muted),
                            tooltip: 'Новая партия',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (int i = 0; i < 2; i++) ...[
                            Expanded(
                              child: _PlayerChip(
                                tokens: tokens,
                                name: 'Игрок ${i + 1}',
                                score: state.scores[i],
                                color: tokens.playerColor(i),
                                active: !state.gameOver && state.current == i,
                              ),
                            ),
                            if (i == 0) const SizedBox(width: 10),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.gameOver
                            ? 'Партия завершена'
                            : 'Ход: Игрок ${state.current + 1} · '
                                'осталось ходов: ${state.turnsLeft}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tokens.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Center(
                          child: Match3BoardView(
                            grid: state.grid,
                            selected: state.selected,
                            theme: tokens,
                            onTap: notifier.tapCell,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Поменяй местами две соседние фишки, чтобы собрать ряд '
                        'из трёх и больше.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tokens.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (state.gameOver)
            _ResultOverlay(
              tokens: tokens,
              winner: state.winner,
              scores: state.scores,
              onAgain: _newGame,
              onMenu: () => context.go('/'),
            ),
        ],
      ),
    );
  }
}

/// Чип игрока в табло.
class _PlayerChip extends StatelessWidget {
  final BlockDuelTheme tokens;
  final String name;
  final int score;
  final Color color;
  final bool active;

  const _PlayerChip({
    required this.tokens,
    required this.name,
    required this.score,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(
          color: active ? color : tokens.line,
          width: active ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              color: tokens.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Оверлей итога партии.
class _ResultOverlay extends StatelessWidget {
  final BlockDuelTheme tokens;
  final int? winner;
  final List<int> scores;
  final VoidCallback onAgain;
  final VoidCallback onMenu;

  const _ResultOverlay({
    required this.tokens,
    required this.winner,
    required this.scores,
    required this.onAgain,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final w = winner;
    final title = w == null ? '🤝 Ничья!' : '🏆 Игрок ${w + 1} победил';
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: tokens.panel,
              borderRadius: BorderRadius.circular(tokens.cardRadius),
              border: Border.all(color: tokens.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontFamily: tokens.fontDisplay,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Счёт ${scores[0]} : ${scores[1]}',
                  style: TextStyle(color: tokens.muted, fontSize: 14),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onMenu,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: tokens.line),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('В меню', style: TextStyle(color: tokens.ink)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: onAgain,
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.p0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Ещё раз'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
