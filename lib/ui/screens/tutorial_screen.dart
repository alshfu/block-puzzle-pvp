/// tutorial_screen.dart — экран обучения (View).
///
/// За что отвечает файл:
///   Пятишаговый интерактивный туториал: прогресс-бар, карточка шага, доска и
///   рука (переиспользуют игровые виджеты [BoardView]/[HandView]), строка
///   статуса и кнопки «Дальше»/«Заново»/«Завершить». Логика — в
///   [TutorialController]; View только рисует и шлёт команды.
///
/// Соответствие TS: `screens/TutorialScreen.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shop/skins.dart';
import '../../shop/skins_controller.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_steps.dart';
import '../design_tokens.dart';
import '../widgets/board_view.dart';
import '../widgets/hand_view.dart';

/// Экран обучения.
class TutorialScreen extends ConsumerWidget {
  /// Создаёт экран обучения.
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    final st = ref.watch(tutorialControllerProvider);
    final vm = ref.read(tutorialControllerProvider.notifier);
    final step = tutorialSteps[st.stepIdx];
    final last = st.stepIdx + 1 == tutorialSteps.length;
    final skin = skinStyleOf(ref.watch(skinsControllerProvider).equipped);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // R — поворот выбранной фигуры (десктоп). Шаг 3 как раз про поворот.
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyR) {
          vm.rotateSelected();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: theme.bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Шапка: назад + бейдж шага.
                    Row(
                      children: [
                        _BackButton(theme: theme, onTap: () => context.go('/')),
                        const SizedBox(width: 10),
                        Text(
                          'Обучение · ${st.stepIdx + 1} / ${tutorialSteps.length}',
                          style: TextStyle(
                            color: theme.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Прогресс-бар.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: st.progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: theme.panel,
                        valueColor: AlwaysStoppedAnimation(theme.p0),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Карточка шага.
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
                            step.title,
                            style: TextStyle(
                              color: theme.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFamily: theme.fontDisplay,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            step.description,
                            style: TextStyle(
                              color: theme.muted,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    BoardView(
                      state: st.game,
                      theme: theme,
                      onPlace: vm.placeAt,
                      skin: skin,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      st.statusMsg,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: st.doneStep ? theme.good : theme.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    HandView(
                      hand: st.game.currentPlayer.hand,
                      selectedId: st.game.selectedPieceId,
                      selectedCells: st.game.activeCells,
                      interactive: !st.doneStep,
                      owner: 0,
                      theme: theme,
                      onSelect: vm.selectPiece,
                      onRotate: vm.rotateSelected,
                    ),
                    const SizedBox(height: 16),
                    // Действия.
                    if (st.doneStep)
                      _PrimaryButton(
                        theme: theme,
                        label: last
                            ? '🪙 Завершить · +$tutorialRewardCoins'
                            : 'Дальше →',
                        onTap: () {
                          if (vm.next()) context.go('/');
                        },
                      )
                    else
                      Center(
                        child: TextButton(
                          onPressed: vm.retry,
                          child: Text(
                            '↻ Заново',
                            style: TextStyle(color: theme.muted),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Кнопка «назад».
class _BackButton extends StatelessWidget {
  final BlockDuelTheme theme;
  final VoidCallback onTap;
  const _BackButton({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: theme.panel,
    borderRadius: BorderRadius.circular(theme.btnRadius),
    child: InkWell(
      borderRadius: BorderRadius.circular(theme.btnRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text('←', style: TextStyle(color: theme.ink, fontSize: 16)),
      ),
    ),
  );
}

/// Основная кнопка действия.
class _PrimaryButton extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.theme,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: theme.p0,
    borderRadius: BorderRadius.circular(theme.btnRadius),
    child: InkWell(
      borderRadius: BorderRadius.circular(theme.btnRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: theme.bg,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}
