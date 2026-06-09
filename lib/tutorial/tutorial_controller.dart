/// tutorial_controller.dart — ViewModel обучения (MVVM, ViewModel).
///
/// За что отвечает файл:
///   Ведёт прохождение туториала: текущий шаг, рабочая доска/рука/выбор (через
///   облегчённый [GameState] для переиспользования игровых виджетов), проверку
///   цели шага и выдачу награды (один раз) по завершении. Никакого BuildContext.
///
/// Соответствие TS: состояние из `screens/TutorialScreen.tsx`.
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_state.dart';
import '../profile/profile_controller.dart';
import '../storage/prefs.dart';
import 'tutorial_steps.dart';

/// Снимок состояния обучения.
class TutorialState {
  /// Индекс текущего шага (0-based).
  final int stepIdx;

  /// Рабочее игровое состояние (доска + рука игрока 0 + выбор фигуры).
  final GameState game;

  /// Достигнутое в этом шаге комбо.
  final int comboInStep;

  /// Пройден ли текущий шаг (можно жать «Дальше»).
  final bool doneStep;

  /// Сообщение-подсказка под доской.
  final String statusMsg;

  const TutorialState({
    required this.stepIdx,
    required this.game,
    required this.comboInStep,
    required this.doneStep,
    required this.statusMsg,
  });

  /// Прогресс прохождения (0..1) с учётом пройденного шага.
  double get progress => (stepIdx + (doneStep ? 1 : 0)) / tutorialSteps.length;

  TutorialState copyWith({
    int? stepIdx,
    GameState? game,
    int? comboInStep,
    bool? doneStep,
    String? statusMsg,
  }) => TutorialState(
    stepIdx: stepIdx ?? this.stepIdx,
    game: game ?? this.game,
    comboInStep: comboInStep ?? this.comboInStep,
    doneStep: doneStep ?? this.doneStep,
    statusMsg: statusMsg ?? this.statusMsg,
  );
}

/// ViewModel обучения.
class TutorialController extends Notifier<TutorialState> {
  @override
  TutorialState build() => _loadStep(0);

  /// Строит состояние для шага [idx]: свежие доска и рука, сброс прогресса.
  TutorialState _loadStep(int idx) {
    final step = tutorialSteps[idx];
    return TutorialState(
      stepIdx: idx,
      game: _gameFor(step.buildBoard(), step.buildHand()),
      comboInStep: 0,
      doneStep: false,
      statusMsg: step.hint,
    );
  }

  /// Облегчённое [GameState] с одним игроком (для BoardView/HandView).
  GameState _gameFor(Board board, List<PieceInstance> hand) => GameState(
    board: board,
    players: [PlayerState(score: 0, combo: 0, hand: hand, name: 'Ты')],
    current: 0,
    round: 0,
    gameOver: false,
    winner: null,
    selectedPieceId: null,
    orientIndex: 0,
    turnLimit: double.infinity,
    turnRemaining: double.infinity,
    cfg: defaultConfig,
  );

  // ── Команды View ───────────────────────────────────────────────────────

  /// Выбирает фигуру из руки (сбрасывает ориентацию).
  void selectPiece(String pieceId) {
    if (state.doneStep) return;
    state = state.copyWith(
      game: state.game.copyWith(selectedPieceId: pieceId, orientIndex: 0),
    );
  }

  /// Поворачивает выбранную фигуру.
  void rotateSelected() {
    if (state.doneStep || state.game.selectedPiece == null) return;
    state = state.copyWith(
      game: state.game.copyWith(orientIndex: state.game.orientIndex + 1),
    );
  }

  /// Ставит выбранную фигуру с якорем `(r, c)`; проверяет цель шага.
  void placeAt(int r, int c) {
    if (state.doneStep) return;
    final g = state.game;
    final cells = g.activeCells;
    final pieceId = g.selectedPieceId;
    if (cells == null || pieceId == null) return;
    if (!canPlace(g.board, cells, r, c)) {
      state = state.copyWith(statusMsg: 'Сюда не помещается');
      return;
    }
    final board = cloneBoard(g.board);
    place(board, cells, r, c, 0);
    final cl = findClears(board);
    var combo = state.comboInStep;
    if (cl.count > 0) {
      applyClears(board, cl.cleared);
      combo += 1;
    } else {
      combo = 0;
    }
    final newHand = [
      for (final p in g.currentPlayer.hand)
        if (p.id != pieceId) p,
    ];
    final newGame = g.copyWith(
      board: board,
      players: [g.currentPlayer.copyWith(hand: newHand, combo: combo)],
      clearSelection: true,
      orientIndex: 0,
    );
    final boardEmpty = isPerfectClear(board);
    final step = tutorialSteps[state.stepIdx];
    if (step.isGoalMet(cl.count, combo, boardEmpty)) {
      state = state.copyWith(
        game: newGame,
        comboInStep: combo,
        doneStep: true,
        statusMsg: '✓ Готово! Жми «Дальше».',
      );
    } else if (!hasAnyMove(board, newHand, defaultConfig)) {
      state = state.copyWith(
        game: newGame,
        comboInStep: combo,
        statusMsg: 'Не вышло. Жми «Заново», чтобы попробовать снова.',
      );
    } else {
      state = state.copyWith(
        game: newGame,
        comboInStep: combo,
        statusMsg: cl.count > 0
            ? 'Очистка! Продолжай (${step.hint}).'
            : step.hint,
      );
    }
  }

  /// Переходит к следующему шагу. Возвращает `true`, если обучение завершено
  /// (тогда View покидает экран); на последнем шаге выдаёт награду один раз.
  bool next() {
    if (state.stepIdx + 1 >= tutorialSteps.length) {
      _grantRewardOnce();
      return true;
    }
    state = _loadStep(state.stepIdx + 1);
    return false;
  }

  /// Перезапускает текущий шаг.
  void retry() => state = _loadStep(state.stepIdx);

  /// Начисляет награду за обучение один раз (флаг в prefs).
  void _grantRewardOnce() {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getString(PrefKeys.tutorialDone) == '1') return;
    ref.read(profileControllerProvider.notifier).addCoins(tutorialRewardCoins);
    prefs.setString(PrefKeys.tutorialDone, '1');
  }
}

/// Провайдер ViewModel обучения.
final tutorialControllerProvider =
    NotifierProvider<TutorialController, TutorialState>(TutorialController.new);
