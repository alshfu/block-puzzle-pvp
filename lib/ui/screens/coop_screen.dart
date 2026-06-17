/// coop_screen.dart — экран режима «Co-op Tetris» (View).
///
/// За что отвечает файл:
///   Тонкий View поверх [CoopNotifier]: высокое поле 10×20 (через
///   [CoopBoardView]), табло обоих игроков с подсветкой активного и анимацией
///   счёта, всплывающий «+счёт» и конфетти при очистках/победе, рука текущего
///   игрока ([HandView]) и оверлей итога. Логики нет — выбор/поворот/постановка
///   делегируются ViewModel; seed новой партии берётся из системного времени.
///
/// Соответствие ROADMAP: § 5.4 (Co-op Tetris UI, hot-seat).
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../modes/coop/coop_notifier.dart';
import '../../modes/coop/coop_state.dart';
import '../decor/cell_fx.dart';
import '../decor/theme_backdrop.dart';
import '../design_tokens.dart';
import '../game/confetti_overlay.dart';
import '../widgets/coop_board_view.dart';
import '../widgets/hand_view.dart';
import '../widgets/piece_controls.dart';

/// Доступен ли поворот выбранной фигуры (у неё > 1 уникальной ориентации).
bool _canRotate(CoopState s) {
  final p = s.selectedPiece;
  if (p == null) return false;
  return orientations(p.type, s.cfg.rotationEnabled, s.cfg.flipEnabled).length >
      1;
}

/// Порог ширины, с которого «обвязка» выносится сбоку от высокого поля
/// (ROADMAP § 5.4: «на мобиле board высокий, обвязка по бокам»). Ниже —
/// вертикальная раскладка (поле сверху, управление снизу).
const double _coopSideBySideWidth = 720;

/// Экран режима «Co-op Tetris».
class CoopScreen extends ConsumerStatefulWidget {
  /// Создаёт экран.
  const CoopScreen({super.key});

  @override
  ConsumerState<CoopScreen> createState() => _CoopScreenState();
}

class _CoopScreenState extends ConsumerState<CoopScreen> {
  /// Flame-движок конфетти (очистка строк/победа).
  final ConfettiGame _confetti = ConfettiGame();

  /// Текущий всплывающий «+счёт».
  String? _floatText;
  int _floatId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _newGame());
  }

  void _newGame() {
    final seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    ref.read(coopProvider.notifier).newGame(seed);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    final state = ref.watch(coopProvider);
    final notifier = ref.read(coopProvider.notifier);

    ref.listen(coopProvider, (prev, next) {
      if (prev == null) return;
      if (next.moveSeq != prev.moveSeq && next.lastGain > 0) {
        setState(() {
          _floatText = '+${next.lastGain}';
          _floatId++;
        });
        _confetti.burst([tokens.good, tokens.p0, tokens.p1]);
      }
      if (next.gameOver && !prev.gameOver) {
        _confetti.burst([tokens.p0, tokens.p1, tokens.good]);
      }
    });

    // Поле + всплывающий счёт (общий блок для обеих раскладок).
    final board = Stack(
      alignment: Alignment.center,
      children: [
        CoopBoardView(
          state: state,
          theme: tokens,
          onPlace: notifier.placeAt,
          showGhost: !state.gameOver,
        ),
        if (_floatText != null)
          FloatingScore(
            key: ValueKey(_floatId),
            text: _floatText!,
            color: tokens.good,
            onDone: () => setState(() => _floatText = null),
          ),
      ],
    );

    // Рука + панель управления (показываются, пока партия идёт).
    final controls = state.gameOver
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 8),
              PieceControls(
                theme: tokens,
                hasSelection: state.selectedPiece != null,
                canRotate: _canRotate(state),
                onRotate: notifier.rotate,
                onDeselect: notifier.deselect,
                hint:
                    'Ход: ${state.currentPlayer.name} · '
                    'выбери фигуру и тапни по доске',
              ),
            ],
          );

    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          const ThemeBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Широкий экран (планшет/десктоп/ландшафт): высокое поле слева,
                // «обвязка» (табло/рука/управление) — сбоку справа.
                final wide = constraints.maxWidth >= _coopSideBySideWidth;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 980 : 460),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: wide
                          ? _WideLayout(
                              tokens: tokens,
                              state: state,
                              board: board,
                              controls: controls,
                              onNewGame: _newGame,
                            )
                          : _NarrowLayout(
                              tokens: tokens,
                              state: state,
                              board: board,
                              controls: controls,
                              onNewGame: _newGame,
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(child: ConfettiOverlay(game: _confetti)),
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

/// Узкая (вертикальная) раскладка: поле сверху, управление снизу.
class _NarrowLayout extends StatelessWidget {
  final BlockDuelTheme tokens;
  final CoopState state;
  final Widget board;
  final Widget? controls;
  final VoidCallback onNewGame;

  const _NarrowLayout({
    required this.tokens,
    required this.state,
    required this.board,
    required this.controls,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(tokens: tokens, onNewGame: onNewGame),
        const SizedBox(height: 6),
        _Scoreboard(tokens: tokens, state: state),
        const SizedBox(height: 8),
        Expanded(child: Center(child: board)),
        if (controls != null) ...[const SizedBox(height: 10), controls!],
      ],
    );
  }
}

/// Широкая раскладка: высокое поле слева, «обвязка» (табло + управление)
/// вертикальной панелью справа.
class _WideLayout extends StatelessWidget {
  final BlockDuelTheme tokens;
  final CoopState state;
  final Widget board;
  final Widget? controls;
  final VoidCallback onNewGame;

  const _WideLayout({
    required this.tokens,
    required this.state,
    required this.board,
    required this.controls,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(tokens: tokens, onNewGame: onNewGame),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Center(child: board)),
              const SizedBox(width: 20),
              SizedBox(
                width: 300,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Scoreboard(tokens: tokens, state: state),
                    if (controls != null) ...[
                      const SizedBox(height: 28),
                      controls!,
                    ],
                  ],
                ),
              ),
            ],
          ),
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

/// Чип одного игрока в табло (с анимацией счёта и подсветки).
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Color.lerp(tokens.panel, color, 0.14) : tokens.panel,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: active ? color : tokens.line, width: active ? 2 : 1),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ]
            : null,
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
          TweenAnimationBuilder<double>(
            tween: Tween(end: score.toDouble()),
            duration: const Duration(milliseconds: 400),
            builder: (context, v, _) => Text(
              '${v.round()}',
              style: TextStyle(
                color: tokens.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
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
    final scoreText = '${state.players[0].score} : ${state.players[1].score}';
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.55 * t),
            child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
          ),
        ),
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
