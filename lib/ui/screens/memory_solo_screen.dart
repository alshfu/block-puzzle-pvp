/// memory_solo_screen.dart — экран режима «Память: соло» (View).
///
/// За что отвечает файл:
///   Тонкий View поверх [MemorySoloNotifier]: рисует четыре фазы режима —
///   выбор сложности, показ раскладки с обратным отсчётом, сборку по памяти
///   (через переиспользуемые [BoardView]/[HandView]) и экран итога с точностью,
///   счётом и рекордом. Логики игры здесь нет — всё делегируется ViewModel.
///   Seed попытки берётся из системного времени (UI-слой, ядро остаётся
///   детерминированным от seed).
///
/// Соответствие ROADMAP: § 5.2 (Memory Solo).
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../modes/memory_solo/memory_solo_notifier.dart';
import '../../modes/memory_solo/memory_solo_puzzle.dart';
import '../../modes/memory_solo/memory_solo_store.dart';
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

/// Экран режима «Память: соло».
class MemorySoloScreen extends ConsumerStatefulWidget {
  /// Создаёт экран.
  const MemorySoloScreen({super.key});

  @override
  ConsumerState<MemorySoloScreen> createState() => _MemorySoloScreenState();
}

class _MemorySoloScreenState extends ConsumerState<MemorySoloScreen> {
  /// Flame-движок конфетти (празднование точного воспроизведения).
  final ConfettiGame _confetti = ConfettiGame();

  @override
  void initState() {
    super.initState();
    // Свежий заход на экран — всегда с выбора сложности.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(memorySoloProvider.notifier).reset();
    });
  }

  /// Запускает попытку выбранного уровня со seed от системного времени.
  void _start(MemoryDifficulty difficulty) {
    final seed =
        DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    ref.read(memorySoloProvider.notifier).start(difficulty, seed);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    final state = ref.watch(memorySoloProvider);

    // Конфетти на точном/отличном воспроизведении.
    ref.listen(memorySoloProvider, (prev, next) {
      if (next.phase == MemoryPhase.done &&
          prev?.phase != MemoryPhase.done &&
          next.result != null &&
          next.result!.accuracy >= 0.8) {
        _confetti.burst([tokens.p0, tokens.good, tokens.p1]);
      }
    });

    final body = switch (state.phase) {
      MemoryPhase.pickDifficulty => _PickDifficulty(
        tokens: tokens,
        onPick: _start,
        onBack: () => context.go('/'),
      ),
      MemoryPhase.showing => _PlayPhase(
        tokens: tokens,
        state: state,
        showing: true,
      ),
      MemoryPhase.reconstruct => _PlayPhase(
        tokens: tokens,
        state: state,
        showing: false,
      ),
      MemoryPhase.done => _DonePhase(
        tokens: tokens,
        state: state,
        onAgain: () => ref.read(memorySoloProvider.notifier).reset(),
        onMenu: () => context.go('/'),
      ),
    };

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
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(
                      key: ValueKey(state.phase),
                      child: body,
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

/// Фаза выбора сложности: карточки уровней с рекордами.
class _PickDifficulty extends ConsumerWidget {
  final BlockDuelTheme tokens;
  final void Function(MemoryDifficulty) onPick;
  final VoidCallback onBack;

  const _PickDifficulty({
    required this.tokens,
    required this.onPick,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final best = ref.watch(memorySoloStoreProvider).all();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back, color: tokens.ink),
            ),
            const SizedBox(width: 4),
            Text(
              '🧠 Память: соло',
              style: TextStyle(
                color: tokens.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: tokens.fontDisplay,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Запомни раскладку за несколько секунд, затем собери её по памяти '
            'теми же фигурами. Чем точнее и быстрее — тем выше счёт.',
            style: TextStyle(color: tokens.muted, fontSize: 13, height: 1.35),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              for (final diff in MemoryDifficulty.values)
                _DifficultyCard(
                  tokens: tokens,
                  difficulty: diff,
                  best: best[diff] ?? 0,
                  onTap: () => onPick(diff),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Карточка одного уровня сложности.
class _DifficultyCard extends StatelessWidget {
  final BlockDuelTheme tokens;
  final MemoryDifficulty difficulty;
  final int best;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.tokens,
    required this.difficulty,
    required this.best,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.cardRadius),
              border: Border.all(color: tokens.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        difficulty.label,
                        style: TextStyle(
                          color: tokens.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${difficulty.pieceCount} фигур · показ '
                        '${difficulty.showSeconds.toStringAsFixed(0)} с · '
                        'сборка ${difficulty.reconstructSeconds.toStringAsFixed(0)} с',
                        style: TextStyle(color: tokens.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (best > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '🏆 $best',
                        style: TextStyle(
                          color: tokens.p0,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'рекорд',
                        style: TextStyle(color: tokens.muted, fontSize: 10),
                      ),
                    ],
                  ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: tokens.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Фаза показа раскладки или сборки по памяти.
class _PlayPhase extends ConsumerWidget {
  final BlockDuelTheme tokens;
  final MemorySoloState state;

  /// true — фаза показа (доска видна, без взаимодействия), false — сборка.
  final bool showing;

  const _PlayPhase({
    required this.tokens,
    required this.state,
    required this.showing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = state.game!;
    final notifier = ref.read(memorySoloProvider.notifier);
    final title = showing ? '👀 Запомни раскладку' : '🧩 Собери по памяти';
    final placed = showing
        ? 0
        : state.game!.currentPlayer.hand.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title,
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
            valueColor: AlwaysStoppedAnimation(
              showing ? tokens.p0 : tokens.good,
            ),
          ),
        ),
        const SizedBox(height: 14),
        BoardView(
          state: game,
          theme: tokens,
          // В фазе показа постановка отключена.
          onPlace: showing ? (_, _) {} : notifier.placeAt,
          showGhost: !showing,
        ),
        const SizedBox(height: 14),
        if (showing)
          Text(
            'Запоминай позиции фигур — доска вот-вот очистится.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.muted, fontSize: 13),
          )
        else ...[
          HandView(
            hand: game.currentPlayer.hand,
            selectedId: game.selectedPieceId,
            interactive: true,
            owner: 0,
            theme: tokens,
            selectedCells: game.activeCells,
            onSelect: notifier.select,
            onRotate: notifier.rotate,
          ),
          const SizedBox(height: 8),
          PieceControls(
            theme: tokens,
            hasSelection: game.selectedPiece != null,
            canRotate: _canRotateCells(game.selectedPiece, game.cfg),
            onRotate: notifier.rotate,
            onDeselect: notifier.deselect,
            hint: 'Осталось фигур: $placed · выбери и тапни по доске',
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: notifier.finishNow,
              child: Text(
                'Готово →',
                style: TextStyle(
                  color: tokens.p0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Экран итога попытки.
class _DonePhase extends StatelessWidget {
  final BlockDuelTheme tokens;
  final MemorySoloState state;
  final VoidCallback onAgain;
  final VoidCallback onMenu;

  const _DonePhase({
    required this.tokens,
    required this.state,
    required this.onAgain,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final result = state.result!;
    final pct = (result.accuracy * 100).round();
    final headline = result.perfect
        ? '🎉 Идеально!'
        : pct >= 80
        ? '👏 Отлично!'
        : pct >= 50
        ? '🙂 Неплохо'
        : '🧐 Тренируйся ещё';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: tokens.ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            fontFamily: tokens.fontDisplay,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          state.difficulty?.label ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.muted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(tokens.cardRadius),
            border: Border.all(
              color: state.newRecord ? tokens.p0 : tokens.line,
              width: state.newRecord ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(tokens: tokens, label: 'Точность', value: '$pct%'),
              _Stat(
                tokens: tokens,
                label: 'Клетки',
                value: '${result.correctCells}/${result.totalCells}',
              ),
              _Stat(tokens: tokens, label: 'Счёт', value: '${result.score}'),
            ],
          ),
        ),
        if (state.newRecord) ...[
          const SizedBox(height: 8),
          Text(
            '🏆 Новый рекорд!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.p0,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          'Целевая раскладка:',
          style: TextStyle(color: tokens.muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        BoardView(
          state: state.game!,
          theme: tokens,
          onPlace: (_, _) {},
          showGhost: false,
        ),
        const SizedBox(height: 16),
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
      ],
    );
  }
}

/// Колонка «значение + подпись» в панели итога.
class _Stat extends StatelessWidget {
  final BlockDuelTheme tokens;
  final String label;
  final String value;

  const _Stat({
    required this.tokens,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: tokens.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: tokens.muted, fontSize: 11)),
      ],
    );
  }
}
