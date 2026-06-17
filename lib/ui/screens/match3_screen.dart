/// match3_screen.dart — экран режима «Match-3 PvP» (View).
///
/// За что отвечает файл:
///   Тонкий View поверх [Match3Notifier]: табло обоих игроков с подсветкой
///   активного и счётчиком оставшихся ходов, анимированное поле 8×8
///   ([Match3BoardView]), всплывающий «+счёт» при очистках, конфетти на победу
///   и оверлей итога. Логики нет — тапы делегируются ViewModel; seed берётся из
///   системного времени.
///
/// Соответствие ROADMAP: § 5.5 (Match-3 PvP, hot-seat).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../modes/match3/match3_notifier.dart';
import '../decor/cell_fx.dart';
import '../decor/theme_backdrop.dart';
import '../design_tokens.dart';
import '../game/confetti_overlay.dart';
import '../widgets/match3_board_view.dart';

/// Экран режима «Match-3 PvP».
class Match3Screen extends ConsumerStatefulWidget {
  /// Создаёт экран.
  const Match3Screen({super.key});

  @override
  ConsumerState<Match3Screen> createState() => _Match3ScreenState();
}

class _Match3ScreenState extends ConsumerState<Match3Screen> {
  /// Flame-движок конфетти (победа/крупная очистка).
  final ConfettiGame _confetti = ConfettiGame();

  /// Текущий всплывающий «+счёт» (или null).
  String? _floatText;

  /// Ключ всплытия — меняется на каждый новый «+счёт» для перезапуска анимации.
  int _floatId = 0;

  void _newGame() {
    final seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    ref.read(match3Provider.notifier).newGame(seed);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _newGame());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    final state = ref.watch(match3Provider);
    final notifier = ref.read(match3Provider.notifier);

    // Реакции на ход: всплывающий счёт и конфетти.
    ref.listen(match3Provider, (prev, next) {
      if (prev == null) return;
      if (next.turnsPlayed != prev.turnsPlayed && next.lastGain > 0) {
        setState(() {
          _floatText = '+${next.lastGain}';
          _floatId++;
        });
        if (next.lastGain >= 120) {
          _confetti.burst([tokens.p0, tokens.good, tokens.p1]);
        }
      }
      if (next.gameOver && !prev.gameOver) {
        _confetti.burst([tokens.p0, tokens.p1, tokens.good]);
      }
    });

    // Поле + всплывающий счёт (общий блок для обеих раскладок).
    final board = Stack(
      alignment: Alignment.center,
      children: [
        Match3BoardView(
          grid: state.grid,
          selected: state.selected,
          theme: tokens,
          onTap: notifier.tapCell,
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

    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          const ThemeBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _match3SideBySideWidth;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 920 : 460),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      child: wide
                          ? _WideLayout(
                              tokens: tokens,
                              state: state,
                              board: board,
                              onNewGame: _newGame,
                            )
                          : _NarrowLayout(
                              tokens: tokens,
                              state: state,
                              board: board,
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

/// Порог ширины, с которого таблица/подсказка выносятся сбоку от поля.
const double _match3SideBySideWidth = 720;

/// Шапка: назад, заголовок, новая партия.
class _Match3Header extends StatelessWidget {
  final BlockDuelTheme tokens;
  final VoidCallback onNewGame;

  const _Match3Header({required this.tokens, required this.onNewGame});

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
          onPressed: onNewGame,
          icon: Icon(Icons.refresh, color: tokens.muted),
          tooltip: 'Новая партия',
        ),
      ],
    );
  }
}

/// Табло обоих игроков (два чипа в ряд).
class _Match3Scoreboard extends StatelessWidget {
  final BlockDuelTheme tokens;
  final Match3State state;

  const _Match3Scoreboard({required this.tokens, required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

/// Подсказка по управлению.
class _Hint extends StatelessWidget {
  final BlockDuelTheme tokens;

  const _Hint({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Поменяй местами две соседние фишки, чтобы собрать ряд из трёх и больше.',
      textAlign: TextAlign.center,
      style: TextStyle(color: tokens.muted, fontSize: 12),
    );
  }
}

/// Узкая (вертикальная) раскладка: табло/строка хода сверху, поле — снизу.
class _NarrowLayout extends StatelessWidget {
  final BlockDuelTheme tokens;
  final Match3State state;
  final Widget board;
  final VoidCallback onNewGame;

  const _NarrowLayout({
    required this.tokens,
    required this.state,
    required this.board,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Match3Header(tokens: tokens, onNewGame: onNewGame),
        const SizedBox(height: 4),
        _Match3Scoreboard(tokens: tokens, state: state),
        const SizedBox(height: 8),
        _TurnBar(tokens: tokens, state: state),
        const SizedBox(height: 10),
        Expanded(child: Center(child: board)),
        const SizedBox(height: 8),
        _Hint(tokens: tokens),
      ],
    );
  }
}

/// Широкая раскладка: поле слева, табло/строка хода/подсказка панелью справа.
class _WideLayout extends StatelessWidget {
  final BlockDuelTheme tokens;
  final Match3State state;
  final Widget board;
  final VoidCallback onNewGame;

  const _WideLayout({
    required this.tokens,
    required this.state,
    required this.board,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Match3Header(tokens: tokens, onNewGame: onNewGame),
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
                    _Match3Scoreboard(tokens: tokens, state: state),
                    const SizedBox(height: 18),
                    _TurnBar(tokens: tokens, state: state),
                    const SizedBox(height: 18),
                    _Hint(tokens: tokens),
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

/// Полоса хода/оставшихся ходов.
class _TurnBar extends StatelessWidget {
  final BlockDuelTheme tokens;
  final Match3State state;

  const _TurnBar({required this.tokens, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.gameOver
              ? 'Партия завершена'
              : 'Ход: Игрок ${state.current + 1} · осталось ходов: '
                  '${state.turnsLeft}',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: state.turnsLeft / match3MaxTurns),
            duration: const Duration(milliseconds: 350),
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 5,
              backgroundColor: tokens.line,
              valueColor: AlwaysStoppedAnimation(tokens.p0),
            ),
          ),
        ),
      ],
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? Color.lerp(tokens.panel, color, 0.14)
            : tokens.panel,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(
          color: active ? color : tokens.line,
          width: active ? 2 : 1,
        ),
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
