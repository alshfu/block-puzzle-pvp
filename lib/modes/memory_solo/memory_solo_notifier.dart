/// memory_solo_notifier.dart — ViewModel режима «Память: соло» (MVVM).
///
/// За что отвечает файл:
///   Управляет жизненным циклом одной попытки Memory Solo поверх pure-ядра
///   (`memory_solo_puzzle.dart`): выбор сложности → фаза показа раскладки →
///   фаза сборки по памяти → итог. Ведёт обратный отсчёт обеих фаз, принимает
///   команды View (выбор/поворот/постановка фигуры, досрочный финиш, рестарт) и
///   считает результат через [scoreMemory], записывая рекорд в [MemorySoloStore].
///   Никакого `BuildContext`/виджетов — только Riverpod + ядро.
///
/// Переиспользование 9×9-инфраструктуры:
///   состояние сборки держится в [GameState], чтобы переиспользовать готовые
///   [BoardView]/[HandView] (превью-«призрак», валидность постановки, поворот в
///   руке) без дублирования. В отличие от дуэли, постановка НЕ запускает очистки
///   линий — цель режима воспроизвести узор клетка-в-клетку.
///
/// Соответствие ROADMAP: § 5.2 (Memory Solo).
library;

import 'dart:async';

import 'package:block_duel/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/game_state.dart';
import 'memory_solo_puzzle.dart';
import 'memory_solo_store.dart';

/// Фаза попытки Memory Solo.
enum MemoryPhase {
  /// Выбор уровня сложности (стартовый экран режима).
  pickDifficulty,

  /// Показ целевой раскладки (запоминание).
  showing,

  /// Сборка раскладки по памяти.
  reconstruct,

  /// Итог: показан результат и рекорд.
  done,
}

/// Период тика обратного отсчёта фаз.
const Duration _tick = Duration(milliseconds: 100);

/// Шаг убывания за тик (секунды) — соответствует [_tick].
const double _tickStep = 0.1;

/// Неизменяемое состояние режима для View.
class MemorySoloState {
  /// Текущая фаза.
  final MemoryPhase phase;

  /// Выбранный уровень (null до выбора).
  final MemoryDifficulty? difficulty;

  /// Состояние доски/руки/выбора для рендера через [BoardView]/[HandView].
  /// В фазе показа — целевая раскладка (рука пуста); в фазе сборки — рабочая
  /// доска и рука фигур. Null в [MemoryPhase.pickDifficulty].
  final GameState? game;

  /// Лимит текущей фазы (секунды).
  final double phaseLimit;

  /// Остаток времени текущей фазы (секунды).
  final double phaseRemaining;

  /// Результат (только в [MemoryPhase.done]).
  final MemoryResult? result;

  /// Побит ли рекорд этим результатом.
  final bool newRecord;

  /// Текущий рекорд для выбранного уровня (для отображения).
  final int best;

  /// Создаёт состояние.
  const MemorySoloState({
    required this.phase,
    this.difficulty,
    this.game,
    this.phaseLimit = 0,
    this.phaseRemaining = 0,
    this.result,
    this.newRecord = false,
    this.best = 0,
  });

  /// Начальное состояние — выбор сложности.
  const MemorySoloState.initial() : this(phase: MemoryPhase.pickDifficulty);

  /// Доля оставшегося времени текущей фазы (0..1).
  double get phaseRatio =>
      phaseLimit <= 0 ? 0 : (phaseRemaining / phaseLimit).clamp(0.0, 1.0);

  /// Копия с изменёнными полями.
  MemorySoloState copyWith({
    MemoryPhase? phase,
    MemoryDifficulty? difficulty,
    GameState? game,
    double? phaseLimit,
    double? phaseRemaining,
    MemoryResult? result,
    bool? newRecord,
    int? best,
  }) => MemorySoloState(
    phase: phase ?? this.phase,
    difficulty: difficulty ?? this.difficulty,
    game: game ?? this.game,
    phaseLimit: phaseLimit ?? this.phaseLimit,
    phaseRemaining: phaseRemaining ?? this.phaseRemaining,
    result: result ?? this.result,
    newRecord: newRecord ?? this.newRecord,
    best: best ?? this.best,
  );
}

/// ViewModel режима «Память: соло».
class MemorySoloNotifier extends Notifier<MemorySoloState> {
  /// Правила постановки в фазе сборки: повороты/отражения разрешены, blitz
  /// выключен (таймер режима ведёт сам нотифайер, не ядро).
  static final RuleConfig _cfg = defaultConfig.copyWith(turnTimerEnabled: false);

  /// Текущая задача (раскладка + рука). Null до выбора сложности.
  MemoryPuzzle? _puzzle;

  /// Тикер обратного отсчёта активной фазы.
  Timer? _ticker;

  @override
  MemorySoloState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const MemorySoloState.initial();
  }

  // ── Команды View ───────────────────────────────────────────────────────────

  /// Полный сброс к выбору сложности (новый заход на экран / «ещё раз»).
  void reset() {
    _ticker?.cancel();
    _puzzle = null;
    state = const MemorySoloState.initial();
  }

  /// Запускает попытку выбранного [difficulty] от [seed]. Переходит в фазу
  /// показа целевой раскладки.
  void start(MemoryDifficulty difficulty, int seed) {
    _ticker?.cancel();
    final puzzle = generateMemoryPuzzle(difficulty, seed);
    _puzzle = puzzle;
    final best = ref.read(memorySoloStoreProvider).best(difficulty);
    state = MemorySoloState(
      phase: MemoryPhase.showing,
      difficulty: difficulty,
      game: _gameWith(cloneBoard(puzzle.target), const []),
      phaseLimit: difficulty.showSeconds,
      phaseRemaining: difficulty.showSeconds,
      best: best,
    );
    _arm();
  }

  /// Выбирает фигуру руки (сбрасывает ориентацию). Только в фазе сборки.
  void select(String pieceId) {
    if (state.phase != MemoryPhase.reconstruct) return;
    final g = state.game;
    if (g == null) return;
    state = state.copyWith(
      game: g.copyWith(selectedPieceId: pieceId, orientIndex: 0),
    );
  }

  /// Поворачивает выбранную фигуру (следующая ориентация). Только в фазе сборки.
  void rotate() {
    if (state.phase != MemoryPhase.reconstruct) return;
    final g = state.game;
    if (g == null || g.selectedPiece == null) return;
    state = state.copyWith(game: g.copyWith(orientIndex: g.orientIndex + 1));
  }

  /// Ставит выбранную фигуру с якорем `(r, c)`. Очистки линий НЕ применяются
  /// (режим воспроизводит узор). При опустошении руки — финиш.
  void placeAt(int r, int c) {
    if (state.phase != MemoryPhase.reconstruct) return;
    final g = state.game;
    if (g == null) return;
    final cells = g.activeCells;
    final piece = g.selectedPiece;
    if (cells == null || piece == null) return;
    if (!canPlace(g.board, cells, r, c)) return;

    final board = cloneBoard(g.board);
    place(board, cells, r, c, 0);
    final hand = [
      for (final p in g.currentPlayer.hand) if (p.id != piece.id) p,
    ];
    state = state.copyWith(game: _gameWith(board, hand));
    if (hand.isEmpty) _finish();
  }

  /// Досрочно завершает сборку и подсчитывает результат.
  void finishNow() {
    if (state.phase != MemoryPhase.reconstruct) return;
    _finish();
  }

  // ── Внутреннее ──────────────────────────────────────────────────────────────

  /// Собирает [GameState] для рендера: одна «сторона» (игрок 0) держит [hand],
  /// доска — [board]. Таймеры/раунды режиму не нужны.
  GameState _gameWith(Board board, List<PieceInstance> hand) => GameState(
    board: board,
    players: [
      PlayerState(score: 0, combo: 0, hand: hand, name: 'Вы'),
    ],
    current: 0,
    round: 0,
    gameOver: false,
    winner: null,
    selectedPieceId: null,
    orientIndex: 0,
    turnLimit: double.infinity,
    turnRemaining: double.infinity,
    cfg: _cfg,
  );

  /// Запускает тикер активной фазы.
  void _arm() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) => _onTick());
  }

  /// Один тик обратного отсчёта; на нуле — переход фазы.
  void _onTick() {
    final remaining = state.phaseRemaining - _tickStep;
    if (remaining > 0) {
      state = state.copyWith(phaseRemaining: remaining);
      return;
    }
    state = state.copyWith(phaseRemaining: 0);
    if (state.phase == MemoryPhase.showing) {
      _beginReconstruct();
    } else if (state.phase == MemoryPhase.reconstruct) {
      _finish();
    }
  }

  /// Переход к фазе сборки: чистая доска + рука фигур, отсчёт сборки.
  void _beginReconstruct() {
    final puzzle = _puzzle;
    if (puzzle == null) return;
    final limit = puzzle.difficulty.reconstructSeconds;
    state = state.copyWith(
      phase: MemoryPhase.reconstruct,
      game: _gameWith(emptyBoard(), puzzle.hand),
      phaseLimit: limit,
      phaseRemaining: limit,
    );
    _arm();
  }

  /// Подсчёт результата, запись рекорда, переход к итогу.
  void _finish() {
    _ticker?.cancel();
    final puzzle = _puzzle;
    final g = state.game;
    if (puzzle == null || g == null) return;
    final timeRatio = state.phase == MemoryPhase.reconstruct
        ? state.phaseRatio
        : 0.0;
    final result = scoreMemory(puzzle.target, g.board, timeRatio: timeRatio);
    final store = ref.read(memorySoloStoreProvider);
    final prevBest = store.best(puzzle.difficulty);
    final isRecord = result.score > prevBest;
    // Запись рекорда — fire-and-forget (persist асинхронный).
    unawaited(store.submit(puzzle.difficulty, result.score));
    state = state.copyWith(
      phase: MemoryPhase.done,
      // В итоге показываем целевую раскладку для сверки.
      game: _gameWith(cloneBoard(puzzle.target), const []),
      result: result,
      newRecord: isRecord,
      best: isRecord ? result.score : prevBest,
    );
  }
}

/// Провайдер ViewModel режима «Память: соло».
final memorySoloProvider =
    NotifierProvider<MemorySoloNotifier, MemorySoloState>(
      MemorySoloNotifier.new,
    );
