/// memory_duel_screen.dart — экран локального «Memory Duel» (View).
///
/// За что отвечает файл:
///   Тонкий View поверх [MemoryDuelNotifier]: заставки смены игроков, фаза
///   расстановки (поле 9×9 + рука), фаза запоминания (показ раскладки с
///   обратным отсчётом), фаза воспроизведения (поле + рука + таймер), итог
///   раунда и итог дуэли. Переиспользует [BoardView]/[HandView]. Логики нет —
///   всё делегируется ViewModel; seed дуэли берётся из системного времени.
///
/// Соответствие ROADMAP: § 5.3 (Memory Duel, локальный hot-seat).
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../modes/memory_duel/memory_duel_notifier.dart';
import '../decor/theme_backdrop.dart';
import '../design_tokens.dart';
import '../game/confetti_overlay.dart';
import '../widgets/board_view.dart';
import '../widgets/hand_view.dart';
import '../widgets/piece_controls.dart';

/// Доступен ли поворот фигуры [p] при правилах [cfg] (> 1 ориентации).
bool _canRotateCells(PieceInstance? p, RuleConfig cfg) {
  if (p == null) return false;
  return orientations(p.type, cfg.rotationEnabled, cfg.flipEnabled).length > 1;
}

/// Порог ширины для боковой раскладки в игровых фазах (доска слева, обвязка
/// справа). Ниже — вертикальная раскладка.
const double _duelSideBySideWidth = 720;

/// Имя игрока по индексу.
String _playerName(int i) => 'Игрок ${i + 1}';

/// Экран режима «Memory Duel».
class MemoryDuelScreen extends ConsumerStatefulWidget {
  /// Создаёт экран.
  const MemoryDuelScreen({super.key});

  @override
  ConsumerState<MemoryDuelScreen> createState() => _MemoryDuelScreenState();
}

class _MemoryDuelScreenState extends ConsumerState<MemoryDuelScreen> {
  /// Flame-движок конфетти (победа в дуэли).
  final ConfettiGame _confetti = ConfettiGame();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
      ref.read(memoryDuelProvider.notifier).restart(seed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    final state = ref.watch(memoryDuelProvider);
    final notifier = ref.read(memoryDuelProvider.notifier);

    ref.listen(memoryDuelProvider, (prev, next) {
      if (next.phase == DuelPhase.done && prev?.phase != DuelPhase.done) {
        _confetti.burst([tokens.p0, tokens.p1, tokens.good]);
      }
    });

    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          const ThemeBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _duelSideBySideWidth;
                final playing = state.phase == DuelPhase.arrange ||
                    state.phase == DuelPhase.reproduce ||
                    state.phase == DuelPhase.memorize;
                return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: wide && playing ? 920 : 460,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(
                      key: ValueKey(state.phase),
                      child: switch (state.phase) {
                    DuelPhase.introArrange => _Intro(
                      tokens: tokens,
                      emoji: '🤫',
                      title: '${_playerName(state.arranger)} расставляет',
                      body:
                          'Раунд ${state.round + 1}. ${_playerName(state.reproducer)} '
                          'не подсматривает! Расставь $memoryDuelPieces фигур — '
                          'соперник будет их запоминать.',
                      button: 'Я готов расставлять',
                      onTap: notifier.proceed,
                      onBack: () => context.go('/'),
                    ),
                    DuelPhase.arrange => _PlacePhase(
                      tokens: tokens,
                      state: state,
                      title: '🧩 ${_playerName(state.arranger)}: расставь узор',
                      hint: 'Поставь фигуры как хочешь — это нужно будет повторить.',
                      onPlace: notifier.placeAt,
                      onSelect: notifier.select,
                      onRotate: notifier.rotate,
                      onDeselect: notifier.deselect,
                      onFinish: notifier.finishArrange,
                      showTimer: false,
                      wide: wide,
                    ),
                    DuelPhase.introMemorize => _Intro(
                      tokens: tokens,
                      emoji: '👀',
                      title: '${_playerName(state.reproducer)}, приготовься',
                      body:
                          'Сейчас покажем раскладку ${memoryDuelShowSeconds.toStringAsFixed(0)} '
                          'секунд — запомни и повтори её теми же фигурами.',
                      button: 'Показать раскладку',
                      onTap: notifier.proceed,
                      onBack: () => context.go('/'),
                    ),
                    DuelPhase.memorize =>
                      _ShowPhase(tokens: tokens, state: state, wide: wide),
                    DuelPhase.reproduce => _PlacePhase(
                      tokens: tokens,
                      state: state,
                      title: '🧠 ${_playerName(state.reproducer)}: повтори',
                      hint: 'Воспроизведи раскладку по памяти.',
                      onPlace: notifier.placeAt,
                      onSelect: notifier.select,
                      onRotate: notifier.rotate,
                      onDeselect: notifier.deselect,
                      onFinish: notifier.finishReproduce,
                      showTimer: true,
                      wide: wide,
                    ),
                    DuelPhase.roundResult => _RoundResult(
                      tokens: tokens,
                      state: state,
                      onNext: notifier.proceed,
                    ),
                    DuelPhase.done => _Done(
                      tokens: tokens,
                      state: state,
                      onAgain: () {
                        final seed =
                            DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
                        notifier.restart(seed);
                      },
                      onMenu: () => context.go('/'),
                    ),
                      },
                    ),
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
        ],
      ),
    );
  }
}

/// Заставка-«передай устройство» с пояснением и кнопкой продолжения.
class _Intro extends StatelessWidget {
  final BlockDuelTheme tokens;
  final String emoji;
  final String title;
  final String body;
  final String button;
  final VoidCallback onTap;
  final VoidCallback onBack;

  const _Intro({
    required this.tokens,
    required this.emoji,
    required this.title,
    required this.body,
    required this.button,
    required this.onTap,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back, color: tokens.ink),
          ),
        ),
        const Spacer(),
        Text(emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
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
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.muted, fontSize: 14, height: 1.4),
        ),
        const Spacer(),
        FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: tokens.p0,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(button),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Фаза расстановки или воспроизведения: поле + рука + действие.
class _PlacePhase extends StatelessWidget {
  final BlockDuelTheme tokens;
  final MemoryDuelState state;
  final String title;
  final String hint;
  final void Function(int, int) onPlace;
  final void Function(String) onSelect;
  final VoidCallback onRotate;
  final VoidCallback onDeselect;
  final VoidCallback onFinish;
  final bool showTimer;
  final bool wide;

  const _PlacePhase({
    required this.tokens,
    required this.state,
    required this.title,
    required this.hint,
    required this.onPlace,
    required this.onSelect,
    required this.onRotate,
    required this.onDeselect,
    required this.onFinish,
    required this.showTimer,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final game = state.game;
    final timerHeader = Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: tokens.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              fontFamily: tokens.fontDisplay,
            ),
          ),
        ),
        if (showTimer)
          Text(
            '${state.phaseRemaining.ceil()} с',
            style: TextStyle(
              color: state.phaseRatio < 0.25 ? tokens.bad : tokens.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
    final bar = showTimer
        ? ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.phaseRatio,
              minHeight: 6,
              backgroundColor: tokens.line,
              valueColor: AlwaysStoppedAnimation(tokens.good),
            ),
          )
        : null;
    final boardW = BoardView(state: game, theme: tokens, onPlace: onPlace);
    final hand = HandView(
      hand: game.currentPlayer.hand,
      selectedId: game.selectedPieceId,
      interactive: true,
      owner: 0,
      theme: tokens,
      selectedCells: game.activeCells,
      onSelect: onSelect,
      onRotate: onRotate,
    );
    final controls = PieceControls(
      theme: tokens,
      hasSelection: game.selectedPiece != null,
      canRotate: _canRotateCells(game.selectedPiece, game.cfg),
      onRotate: onRotate,
      onDeselect: onDeselect,
      hint: 'Осталось фигур: ${game.currentPlayer.hand.length} · $hint',
    );
    final finishBtn = Center(
      child: TextButton(
        onPressed: onFinish,
        child: Text(
          'Готово →',
          style: TextStyle(color: tokens.p0, fontWeight: FontWeight.w700),
        ),
      ),
    );

    final side = <Widget>[
      timerHeader,
      if (bar != null) ...[const SizedBox(height: 6), bar],
      const SizedBox(height: 16),
      hand,
      const SizedBox(height: 8),
      controls,
      const SizedBox(height: 4),
      finishBtn,
    ];

    if (wide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 460),
              child: boardW,
            ),
          ),
          const SizedBox(width: 22),
          SizedBox(
            width: 300,
            child: Column(mainAxisSize: MainAxisSize.min, children: side),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        timerHeader,
        if (bar != null) ...[const SizedBox(height: 6), bar],
        const SizedBox(height: 12),
        boardW,
        const SizedBox(height: 12),
        hand,
        const SizedBox(height: 8),
        controls,
        const SizedBox(height: 4),
        finishBtn,
      ],
    );
  }
}

/// Фаза запоминания: показ раскладки с обратным отсчётом.
class _ShowPhase extends StatelessWidget {
  final BlockDuelTheme tokens;
  final MemoryDuelState state;
  final bool wide;

  const _ShowPhase({
    required this.tokens,
    required this.state,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final timerHeader = Row(
      children: [
        Expanded(
          child: Text(
            '👀 Запоминай!',
            style: TextStyle(
              color: tokens.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: tokens.fontDisplay,
            ),
          ),
        ),
        Text(
          '${state.phaseRemaining.ceil()} с',
          style: TextStyle(
            color: state.phaseRatio < 0.25 ? tokens.bad : tokens.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: state.phaseRatio,
        minHeight: 6,
        backgroundColor: tokens.line,
        valueColor: AlwaysStoppedAnimation(tokens.p0),
      ),
    );
    final boardW = BoardView(
      state: state.game,
      theme: tokens,
      onPlace: (_, _) {},
      showGhost: false,
    );
    final note = Text(
      'Запомни расположение — сейчас доска очистится и нужно будет повторить.',
      textAlign: TextAlign.center,
      style: TextStyle(color: tokens.muted, fontSize: 13),
    );

    if (wide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 460),
              child: boardW,
            ),
          ),
          const SizedBox(width: 22),
          SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                timerHeader,
                const SizedBox(height: 10),
                bar,
                const SizedBox(height: 20),
                note,
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        timerHeader,
        const SizedBox(height: 8),
        bar,
        const SizedBox(height: 16),
        boardW,
        const SizedBox(height: 16),
        note,
      ],
    );
  }
}

/// Итог раунда: точность воспроизведения активного репродьюсера.
class _RoundResult extends StatelessWidget {
  final BlockDuelTheme tokens;
  final MemoryDuelState state;
  final VoidCallback onNext;

  const _RoundResult({
    required this.tokens,
    required this.state,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    // Защитно: результат раунда может быть ещё не записан (гонка авто-финиша по
    // таймеру). Тогда показываем нулевой итог, а не роняем экран null-unwrap'ом.
    final result = state.reproResult[state.reproducer];
    final pct = ((result?.accuracy ?? 0) * 100).round();
    final last = state.round == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text(
          (result?.perfect ?? false)
              ? '🎯 Идеально!'
              : '✅ Раунд ${state.round + 1} сыгран',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: tokens.ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            fontFamily: tokens.fontDisplay,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_playerName(state.reproducer)} воспроизвёл на $pct%\n'
          '(${result?.correctCells ?? 0}/${result?.totalCells ?? 0} клеток) · '
          '${result?.score ?? 0} очков',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.muted, fontSize: 15, height: 1.5),
        ),
        const Spacer(),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(
            backgroundColor: tokens.p0,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(last ? 'Показать итог' : 'Дальше — меняемся ролями'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Итог дуэли: сравнение результатов обоих игроков.
class _Done extends StatelessWidget {
  final BlockDuelTheme tokens;
  final MemoryDuelState state;
  final VoidCallback onAgain;
  final VoidCallback onMenu;

  const _Done({
    required this.tokens,
    required this.state,
    required this.onAgain,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final winner = state.winner;
    final s0 = state.reproResult[0]?.score ?? 0;
    final s1 = state.reproResult[1]?.score ?? 0;
    final title = winner == null
        ? '🤝 Ничья!'
        : '🏆 ${_playerName(winner)} победил';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: tokens.ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            fontFamily: tokens.fontDisplay,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(tokens.cardRadius),
            border: Border.all(color: tokens.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(tokens: tokens, label: _playerName(0), value: '$s0'),
              _Stat(tokens: tokens, label: _playerName(1), value: '$s1'),
            ],
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onMenu,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.line),
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Ещё раз'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Колонка «значение + подпись».
class _Stat extends StatelessWidget {
  final BlockDuelTheme tokens;
  final String label;
  final String value;

  const _Stat({required this.tokens, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: tokens.ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: tokens.muted, fontSize: 12)),
      ],
    );
  }
}
