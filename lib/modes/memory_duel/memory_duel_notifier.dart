/// memory_duel_notifier.dart — ViewModel локального «Memory Duel» (MVVM).
///
/// За что отвечает файл:
///   Hot-seat дуэль на память (ROADMAP § 5.3, локальный вариант): игрок A
///   расставляет раскладку на поле 9×9, игрок B несколько секунд её запоминает,
///   затем воспроизводит по памяти теми же фигурами; во втором раунде роли
///   меняются, побеждает более точное воспроизведение. Переиспользует скоринг
///   `scoreMemory` и снимок [GameState] (board+hand+selection) для рендера через
///   готовые [BoardView]/[HandView]. Без `BuildContext`/виджетов.
///
/// Сетевая версия (server-authoritative scoring, анти-чит на time-budget показа,
///   отдельный ELO-ladder) — серверная надстройка, требует живого VPS; здесь
///   реализован проверяемый офлайн-поток. См. ROADMAP § 5.3.
library;

import 'dart:async';

import 'package:block_duel/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/game_state.dart';
import '../memory_solo/memory_solo_puzzle.dart';

/// Сколько фигур расставляет игрок за раунд.
const int memoryDuelPieces = 6;

/// Длительность фазы запоминания (секунды).
const double memoryDuelShowSeconds = 5.0;

/// Бюджет времени на воспроизведение (секунды).
const double memoryDuelReproduceSeconds = 50.0;

/// Период тика таймеров фаз.
const Duration _tick = Duration(milliseconds: 100);

/// Шаг убывания за тик (секунды).
const double _tickStep = 0.1;

/// Соль seed для мешка/перемешивания второго раунда.
const int _round1Salt = 0x85ebca6b;

/// Фаза дуэли.
enum DuelPhase {
  /// Заставка перед расстановкой (кто расставляет; второй не подсматривает).
  introArrange,

  /// Игрок-аранжировщик расставляет фигуры.
  arrange,

  /// Заставка перед запоминанием (кто запоминает).
  introMemorize,

  /// Репродьюсер запоминает раскладку (таймер).
  memorize,

  /// Репродьюсер воспроизводит раскладку (таймер).
  reproduce,

  /// Итог раунда.
  roundResult,

  /// Итог дуэли.
  done,
}

/// Неизменяемое состояние дуэли для View.
class MemoryDuelState {
  /// Текущая фаза.
  final DuelPhase phase;

  /// Номер раунда (0 или 1).
  final int round;

  /// Индекс игрока-аранжировщика (0/1). Репродьюсер = 1 - arranger.
  final int arranger;

  /// Снимок board+hand+selection для рендера.
  final GameState game;

  /// Лимит активной фазы (секунды).
  final double phaseLimit;

  /// Остаток активной фазы (секунды).
  final double phaseRemaining;

  /// Результаты воспроизведения по игроку-репродьюсеру (индекс = игрок).
  final List<MemoryResult?> reproResult;

  /// Создаёт состояние.
  const MemoryDuelState({
    required this.phase,
    required this.round,
    required this.arranger,
    required this.game,
    this.phaseLimit = 0,
    this.phaseRemaining = 0,
    this.reproResult = const [null, null],
  });

  /// Индекс игрока-репродьюсера в этом раунде.
  int get reproducer => 1 - arranger;

  /// Доля оставшегося времени активной фазы (0..1).
  double get phaseRatio =>
      phaseLimit <= 0 ? 0 : (phaseRemaining / phaseLimit).clamp(0.0, 1.0);

  /// Победитель дуэли (0/1) или `null` при равенстве/недоигранной партии.
  int? get winner {
    final a = reproResult[0]?.score ?? 0;
    final b = reproResult[1]?.score ?? 0;
    if (a > b) return 0;
    if (b > a) return 1;
    return null;
  }

  /// Копия с изменёнными полями.
  MemoryDuelState copyWith({
    DuelPhase? phase,
    int? round,
    int? arranger,
    GameState? game,
    double? phaseLimit,
    double? phaseRemaining,
    List<MemoryResult?>? reproResult,
  }) => MemoryDuelState(
    phase: phase ?? this.phase,
    round: round ?? this.round,
    arranger: arranger ?? this.arranger,
    game: game ?? this.game,
    phaseLimit: phaseLimit ?? this.phaseLimit,
    phaseRemaining: phaseRemaining ?? this.phaseRemaining,
    reproResult: reproResult ?? this.reproResult,
  );
}

/// ViewModel локальной дуэли на память.
class MemoryDuelNotifier extends Notifier<MemoryDuelState> {
  /// Правила постановки: повороты/отражения разрешены, blitz выключен.
  static final RuleConfig _cfg = defaultConfig.copyWith(turnTimerEnabled: false);

  /// Сохранённая раскладка аранжировщика текущего раунда.
  Board _arrangedBoard = emptyBoard();

  /// Типы фигур, расставленных аранжировщиком (порядок постановки).
  final List<PieceType> _placedTypes = [];

  /// Seed дуэли.
  int _seed = 0;

  /// Тикер активной фазы.
  Timer? _ticker;

  @override
  MemoryDuelState build() {
    ref.onDispose(() => _ticker?.cancel());
    return _initRound(0xC0FFEE, 0, const [null, null]);
  }

  // ── Команды View ───────────────────────────────────────────────────────────

  /// Полный рестарт дуэли с заданным [seed].
  void restart(int seed) {
    _ticker?.cancel();
    state = _initRound(seed, 0, const [null, null]);
  }

  /// Кнопка «Дальше» на заставках/итоге раунда — продвигает фазу.
  void proceed() {
    switch (state.phase) {
      case DuelPhase.introArrange:
        state = state.copyWith(phase: DuelPhase.arrange);
      case DuelPhase.introMemorize:
        _beginMemorize();
      case DuelPhase.roundResult:
        if (state.round == 0) {
          state = _initRound(_seed, 1, state.reproResult);
        } else {
          state = state.copyWith(phase: DuelPhase.done);
        }
      case DuelPhase.arrange:
      case DuelPhase.memorize:
      case DuelPhase.reproduce:
      case DuelPhase.done:
        break;
    }
  }

  /// Выбирает фигуру руки (в фазах расстановки/воспроизведения).
  void select(String pieceId) {
    if (!_isPlacing) return;
    state = state.copyWith(
      game: state.game.copyWith(selectedPieceId: pieceId, orientIndex: 0),
    );
  }

  /// Поворачивает выбранную фигуру.
  void rotate() {
    if (!_isPlacing || state.game.selectedPiece == null) return;
    state = state.copyWith(
      game: state.game.copyWith(orientIndex: state.game.orientIndex + 1),
    );
  }

  /// Снимает выбор фигуры (в фазах расстановки/воспроизведения).
  void deselect() {
    if (!_isPlacing) return;
    state = state.copyWith(game: state.game.copyWith(clearSelection: true));
  }

  /// Ставит выбранную фигуру с якорем `(r, c)` (без очисток — фиксируем узор).
  void placeAt(int r, int c) {
    if (!_isPlacing) return;
    final g = state.game;
    final cells = g.activeCells;
    final piece = g.selectedPiece;
    if (cells == null || piece == null) return;
    if (!canPlace(g.board, cells, r, c)) return;

    final board = cloneBoard(g.board);
    place(board, cells, r, c, 0);
    final hand = [
      for (final p in g.currentPlayer.hand) if (p.id != piece.id) p,
    ];
    if (state.phase == DuelPhase.arrange) _placedTypes.add(piece.type);
    state = state.copyWith(game: _gameWith(board, hand));

    if (state.phase == DuelPhase.arrange && hand.isEmpty) {
      _finishArrange();
    } else if (state.phase == DuelPhase.reproduce && hand.isEmpty) {
      _finishReproduce();
    }
  }

  /// Завершает расстановку досрочно (кнопка «Готово»).
  void finishArrange() {
    if (state.phase == DuelPhase.arrange) _finishArrange();
  }

  /// Завершает воспроизведение досрочно (кнопка «Готово»).
  void finishReproduce() {
    if (state.phase == DuelPhase.reproduce) _finishReproduce();
  }

  // ── Внутреннее ──────────────────────────────────────────────────────────────

  /// Можно ли сейчас ставить фигуры.
  bool get _isPlacing =>
      state.phase == DuelPhase.arrange || state.phase == DuelPhase.reproduce;

  /// Готовит раунд [round]: аранжировщик = round, рука из [memoryDuelPieces]
  /// фигур, фаза — заставка расстановки. [repro] переносит уже сыгранные итоги.
  MemoryDuelState _initRound(int seed, int round, List<MemoryResult?> repro) {
    _seed = seed;
    _arrangedBoard = emptyBoard();
    _placedTypes.clear();
    final bag = Bag(round == 0 ? seed : seed ^ _round1Salt);
    final hand = <PieceInstance>[];
    for (int i = 0; i < memoryDuelPieces; i++) {
      hand.add(bag.drawAvoiding(hand.map((p) => p.type).toSet()));
    }
    return MemoryDuelState(
      phase: DuelPhase.introArrange,
      round: round,
      arranger: round,
      game: _gameWith(emptyBoard(), hand),
      reproResult: repro,
    );
  }

  /// Сохраняет раскладку аранжировщика и идёт к заставке запоминания.
  void _finishArrange() {
    _arrangedBoard = cloneBoard(state.game.board);
    state = state.copyWith(phase: DuelPhase.introMemorize);
  }

  /// Запускает фазу запоминания: показываем раскладку, заводим таймер.
  void _beginMemorize() {
    state = state.copyWith(
      phase: DuelPhase.memorize,
      game: _gameWith(cloneBoard(_arrangedBoard), const []),
      phaseLimit: memoryDuelShowSeconds,
      phaseRemaining: memoryDuelShowSeconds,
    );
    _arm();
  }

  /// Переходит к воспроизведению: чистое поле + рука из расставленных типов.
  void _beginReproduce() {
    final shuffled = _shuffleTypes(_placedTypes, _seed + state.round);
    final hand = <PieceInstance>[
      for (int i = 0; i < shuffled.length; i++)
        PieceInstance(
          id: 'r$i',
          type: shuffled[i],
          cells: normalize(baseShapes[shuffled[i]]!),
        ),
    ];
    state = state.copyWith(
      phase: DuelPhase.reproduce,
      game: _gameWith(emptyBoard(), hand),
      phaseLimit: memoryDuelReproduceSeconds,
      phaseRemaining: memoryDuelReproduceSeconds,
    );
    _arm();
  }

  /// Считает результат воспроизведения и переходит к итогу раунда.
  void _finishReproduce() {
    _ticker?.cancel();
    final result = scoreMemory(
      _arrangedBoard,
      state.game.board,
      timeRatio: state.phaseRatio,
    );
    final repro = [...state.reproResult];
    repro[state.reproducer] = result;
    state = state.copyWith(
      phase: DuelPhase.roundResult,
      game: _gameWith(cloneBoard(_arrangedBoard), const []),
      reproResult: repro,
    );
  }

  /// Тикер: на нуле — переход memorize→reproduce или завершение reproduce.
  void _arm() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) {
      final remaining = state.phaseRemaining - _tickStep;
      if (remaining > 0) {
        state = state.copyWith(phaseRemaining: remaining);
        return;
      }
      state = state.copyWith(phaseRemaining: 0);
      if (state.phase == DuelPhase.memorize) {
        _beginReproduce();
      } else if (state.phase == DuelPhase.reproduce) {
        _finishReproduce();
      }
    });
  }

  /// Снимок [GameState] с одним игроком (board+hand+selection).
  GameState _gameWith(Board board, List<PieceInstance> hand) => GameState(
    board: board,
    players: [PlayerState(score: 0, combo: 0, hand: hand, name: 'Игрок')],
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

  /// Перемешивание типов (детерминированно от seed).
  List<PieceType> _shuffleTypes(List<PieceType> source, int seed) {
    final rng = makeRng(seed);
    final a = List<PieceType>.from(source);
    for (int i = a.length - 1; i > 0; i--) {
      final j = (rng() * (i + 1)).floor();
      final tmp = a[i];
      a[i] = a[j];
      a[j] = tmp;
    }
    return a;
  }
}

/// Провайдер ViewModel локальной дуэли на память.
final memoryDuelProvider =
    NotifierProvider<MemoryDuelNotifier, MemoryDuelState>(
      MemoryDuelNotifier.new,
    );
