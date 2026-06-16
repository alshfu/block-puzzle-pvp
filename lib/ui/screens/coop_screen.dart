/// coop_screen.dart — экран режима «Co-op Tetris» (View).
///
/// За что отвечает файл:
///   Тонкий View поверх [CoopNotifier]: высокое поле 10×20 (через
///   [CoopBoardView]), табло обоих игроков с подсветкой активного, рука
///   текущего игрока ([HandView]) и оверлей итога партии. Логики нет — выбор/
///   поворот/постановка делегируются ViewModel; seed новой партии берётся из
///   системного времени (UI-слой).
///
/// Соответствие ROADMAP: § 5.4 (Co-op Tetris UI, hot-seat).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../modes/coop/coop_notifier.dart';
import '../../modes/coop/coop_state.dart';
import '../decor/theme_backdrop.dart';
import '../design_tokens.dart';
import '../widgets/coop_board_view.dart';
import '../widgets/hand_view.dart';

/// Экран режима «Co-op Tetris».
class CoopScreen extends ConsumerStatefulWidget {
  /// Создаёт экран.
  const CoopScreen({super.key});

  @override
  ConsumerState<CoopScreen> createState() => _CoopScreenState();
}

class _CoopScreenState extends ConsumerState<CoopScreen> {
  @override
  void initState() {
    super.initState();
    // Свежая партия при каждом заходе на экран.
    WidgetsBinding.instance.addPostFrameCallback((_) => _newGame());
  }

  /// Новая партия со seed от системного времени.
  void _newGame() {
    final seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    ref.read(coopProvider.notifier).newGame(seed);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    final state = ref.watch(coopProvider);
    final notifier = ref.read(coopProvider.notifier);
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(tokens: tokens, onNewGame: _newGame),
                      const SizedBox(height: 6),
                      _Scoreboard(tokens: tokens, state: state),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Center(
                          child: CoopBoardView(
                            state: state,
                            theme: tokens,
                            onPlace: notifier.placeAt,
                            showGhost: !state.gameOver,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!state.gameOver) ...[
                        HandView(
                          hand: state.currentPlayer.hand,
                          selectedId: state.selectedPieceId,
                          interactive: true,
                          owner: state.current,
                          theme: tokens,
                          selectedCells: state.activeCells,
                          onSelect: notifier.selectPiece,
                          onRotate: notifier.rotate,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ход: ${state.currentPlayer.name}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: tokens.playerColor(state.current),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (state.gameOver)
            _ResultOverlay(
              tokens: tokens,
              state: state,
              onAgain: _newGame,
              onMenu: () => context.go('/'),
            ),
        ],
      ),
    );
  }
}

/// Шапка: назад, заголовок, новая партия.
class _Header extends StatelessWidget {
  final BlockDuelTheme tokens;
  final VoidCallback onNewGame;

  const _Header({required this.tokens, required this.onNewGame});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.go('/'),
          icon: Icon(Icons.arrow_back, color: tokens.ink),
        ),
        const SizedBox(width: 2),
        Text(
          '🧱 Co-op Tetris',
          style: TextStyle(
            color: tokens.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: tokens.fontDisplay,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onNewGame,
          icon: Icon(Icons.refresh, color: tokens.muted),
          tooltip: 'Новая партия',
        ),
      ],
    );
  }
}

/// Табло обоих игроков с подсветкой активного.
class _Scoreboard extends StatelessWidget {
  final BlockDuelTheme tokens;
  final CoopState state;

  const _Scoreboard({required this.tokens, required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < state.players.length; i++) ...[
          Expanded(
            child: _PlayerChip(
              tokens: tokens,
              name: state.players[i].name,
              score: state.players[i].score,
              color: tokens.playerColor(i),
              active: !state.gameOver && state.current == i,
            ),
          ),
          if (i == 0) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

/// Чип одного игрока в табло.
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
        border: Border.all(color: active ? color : tokens.line, width: active ? 2 : 1),
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
  final CoopState state;
  final VoidCallback onAgain;
  final VoidCallback onMenu;

  const _ResultOverlay({
    required this.tokens,
    required this.state,
    required this.onAgain,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final winner = state.winner;
    final title = winner == null
        ? '🤝 Ничья!'
        : '🏆 ${state.players[winner].name} победил';
    final scoreText =
        '${state.players[0].score} : ${state.players[1].score}';
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
                  'Счёт $scoreText',
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
