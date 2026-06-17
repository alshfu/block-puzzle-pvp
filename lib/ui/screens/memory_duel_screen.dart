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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../modes/memory_duel/memory_duel_notifier.dart';
import '../decor/theme_backdrop.dart';
import '../design_tokens.dart';
import '../game/confetti_overlay.dart';
import '../widgets/board_view.dart';
import '../widgets/hand_view.dart';

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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
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
                      onFinish: notifier.finishArrange,
                      showTimer: false,
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
                    DuelPhase.memorize => _ShowPhase(tokens: tokens, state: state),
                    DuelPhase.reproduce => _PlacePhase(
                      tokens: tokens,
                      state: state,
                      title: '🧠 ${_playerName(state.reproducer)}: повтори',
                      hint: 'Воспроизведи раскладку по памяти.',
                      onPlace: notifier.placeAt,
                      onSelect: notifier.select,
                      onRotate: notifier.rotate,
                      onFinish: notifier.finishReproduce,
                      showTimer: true,
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
  final VoidCallback onFinish;
  final bool showTimer;

  const _PlacePhase({
    required this.tokens,
    required this.state,
    required this.title,
    required this.hint,
    required this.onPlace,
    required this.onSelect,
    required this.onRotate,
    required this.onFinish,
    required this.showTimer,
  });

  @override
  Widget build(BuildContext context) {
    final game = state.game;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
        ),
        if (showTimer) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.phaseRatio,
              minHeight: 6,
              backgroundColor: tokens.line,
              valueColor: AlwaysStoppedAnimation(tokens.good),
            ),
          ),
        ],
        const SizedBox(height: 12),
        BoardView(
          state: game,
          theme: tokens,
          onPlace: onPlace,
        ),
        const SizedBox(height: 12),
        HandView(
          hand: game.currentPlayer.hand,
          selectedId: game.selectedPieceId,
          interactive: true,
          owner: 0,
          theme: tokens,
          selectedCells: game.activeCells,
          onSelect: onSelect,
          onRotate: onRotate,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Осталось фигур: ${game.currentPlayer.hand.length}',
              style: TextStyle(color: tokens.muted, fontSize: 12),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: onFinish,
              child: Text(
                'Готово →',
                style: TextStyle(color: tokens.p0, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.muted, fontSize: 12),
        ),
      ],
    );
  }
}

/// Фаза запоминания: показ раскладки с обратным отсчётом.
class _ShowPhase extends StatelessWidget {
  final BlockDuelTheme tokens;
  final MemoryDuelState state;

  const _ShowPhase({required this.tokens, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '👀 Запоминай!',
              style: TextStyle(
                color: tokens.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: tokens.fontDisplay,
              ),
            ),
            const Spacer(),
            Text(
              '${state.phaseRemaining.ceil()} с',
              style: TextStyle(
                color: state.phaseRatio < 0.25 ? tokens.bad : tokens.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: state.phaseRatio,
            minHeight: 6,
            backgroundColor: tokens.line,
            valueColor: AlwaysStoppedAnimation(tokens.p0),
          ),
        ),
        const SizedBox(height: 16),
        BoardView(
          state: state.game,
          theme: tokens,
          onPlace: (_, _) {},
          showGhost: false,
        ),
        const SizedBox(height: 16),
        Text(
          'Запомни расположение — сейчас доска очистится и нужно будет повторить.',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.muted, fontSize: 13),
        ),
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
    final result = state.reproResult[state.reproducer]!;
    final pct = (result.accuracy * 100).round();
    final last = state.round == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text(
          result.perfect ? '🎯 Идеально!' : '✅ Раунд ${state.round + 1} сыгран',
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
          '(${result.correctCells}/${result.totalCells} клеток) · '
          '${result.score} очков',
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
