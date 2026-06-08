/// game_notifier.dart — ViewModel партии (MVVM, слой ViewModel).
///
/// За что отвечает файл:
///   Управляет ходом партии поверх чистого ядра (Model): держит мешки и rng,
///   выставляет команды для View (выбор фигуры, поворот/отражение, постановка,
///   новая игра), сам ходит за бота и ведёт blitz-таймер с force-place на
///   таймауте (ТЗ §2.7.1). Никакого `BuildContext`, виджетов и `dart:ui` —
///   только Riverpod + ядро.
///
/// Таймеры:
///   `_botTimer`    — отложенный ход бота (читаемая пауза);
///   `_blitzTicker` — периодический отсчёт времени хода человека (100 мс);
///   оба переинициализируются на каждой смене хода методом [_armTimers] и
///   отменяются при dispose.
///
/// Соответствие TS: `src/ui/useGame.ts` (reducer + refs на bag/rng + бот через
/// setTimeout + blitz tick + forcePlace).
library;

import 'dart:async';

import 'package:block_duel/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import 'game_state.dart';
import 'match_config.dart';
import 'saved_game.dart';
import 'saved_game_store.dart';

/// Задержка перед ходом бота по умолчанию (если настройка недоступна).
const Duration _botThinkDelayDefault = Duration(milliseconds: 350);

/// Период тика blitz-таймера.
const Duration _blitzTick = Duration(milliseconds: 100);

/// Шаг убывания таймера за один тик (секунды) — соответствует [_blitzTick].
const double _blitzStep = 0.1;

/// ViewModel партии. Семейство по [MatchConfig]: конфиг приходит в конструктор
/// (API Riverpod 3.x: `NotifierT Function(ArgT)`), `build()` — без параметров.
class GameNotifier extends Notifier<GameState> {
  /// Конфигурация партии (режим, seed, правила) — ключ семейства.
  final MatchConfig config;

  /// Мешки фигур обоих игроков.
  late List<Bag> _bags;

  /// Источник случайности для решений бота.
  late RandomSource _botRng;

  /// Источник случайности для force-place на таймауте.
  late RandomSource _forceRng;

  /// Таймер отложенного хода бота.
  Timer? _botTimer;

  /// Периодический тикер blitz-таймера хода человека.
  Timer? _blitzTicker;

  /// Таймер снятия подсветки power-up «Подсказка».
  Timer? _hintTimer;

  /// Создаёт ViewModel для конкретной партии [config].
  GameNotifier(this.config);

  @override
  GameState build() {
    ref.onDispose(() {
      _botTimer?.cancel();
      _blitzTicker?.cancel();
      _hintTimer?.cancel();
    });
    // Resume: если просили продолжить и есть сохранёнка с тем же seed.
    if (config.resume) {
      final saved = ref.read(savedGameStoreProvider).load();
      if (saved != null && saved.seed == config.seed) {
        final restored = _restore(saved);
        _armTimers(restored);
        return restored;
      }
    }
    final fresh = _freshState();
    _armTimers(fresh);
    return fresh;
  }

  // ── Команды View ─────────────────────────────────────────────────────────

  /// Выбирает фигуру из руки текущего игрока (сбрасывает ориентацию).
  void selectPiece(String pieceId) {
    if (state.gameOver || config.isBot(state.current)) return;
    state = state.copyWith(selectedPieceId: pieceId, orientIndex: 0);
  }

  /// Снимает выбор фигуры.
  void deselect() =>
      state = state.copyWith(clearSelection: true, orientIndex: 0);

  /// Поворачивает выбранную фигуру на следующую ориентацию.
  void rotateSelected() {
    if (state.selectedPiece == null) return;
    state = state.copyWith(orientIndex: state.orientIndex + 1);
  }

  /// Ставит выбранную фигуру с якорем в `(r, c)`, если это допустимо.
  void placeAt(int r, int c) {
    if (state.gameOver || config.isBot(state.current)) return;
    final piece = state.selectedPiece;
    final cells = state.activeCells;
    if (piece == null || cells == null) return;
    if (!canPlace(state.board, cells, r, c)) return;
    _applyPlacement(piece.id, cells, r, c);
  }

  /// Ставит/снимает партию с паузы: останавливает или перезапускает таймеры.
  void setPaused(bool value) {
    if (state.gameOver || state.paused == value) return;
    state = state.copyWith(paused: value);
    _armTimers(state);
  }

  /// Начинает новую партию с тем же конфигом (сбрасывает сохранёнку).
  void newGame() {
    ref.read(savedGameStoreProvider).clear();
    final fresh = _freshState();
    state = fresh;
    _armTimers(fresh);
  }

  // ── Power-ups (одиночные режимы) ───────────────────────────────────────────
  //
  // Действуют на текущего игрока-человека. Возвращают `true`, если эффект
  // применён (тогда View списывает 1 шт. из инвентаря). Порт `useGame.ts`
  // (powerSwapHand/powerHint/powerAutoPlay/powerClearRow/Col/Bomb).

  /// Доступны ли power-ups сейчас: ход человека и партия идёт.
  bool get _powerReady => !state.gameOver && !config.isBot(state.current);

  /// Обновляет всю руку текущего игрока новыми фигурами из его мешка.
  bool powerSwapHand() {
    if (!_powerReady) return false;
    final p = state.current;
    final players = [...state.players];
    players[p] = players[p].copyWith(
      hand: _dealHand(_bags[p], config.cfg.handSize),
    );
    state = state.copyWith(
      players: players,
      clearSelection: true,
      orientIndex: 0,
      clearHint: true,
      nextPieces: _peekNext(),
    );
    return true;
  }

  /// Подсвечивает лучший ход: выбирает фигуру, подгоняет ориентацию и ставит
  /// подсветку цели на 3 секунды. Возвращает `false`, если ходов нет.
  bool powerHint() {
    if (!_powerReady) return false;
    final move = _bestMove();
    if (move == null) return false;
    final os = orientations(
      move.type,
      config.cfg.rotationEnabled,
      config.cfg.flipEnabled,
    );
    final oi = _orientIndexOf(os, move.cells);
    final hint = [
      for (final cell in move.cells) Coord(move.r + cell.r, move.c + cell.c),
    ];
    state = state.copyWith(
      selectedPieceId: move.pieceId,
      orientIndex: oi,
      hintCells: hint,
    );
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      _hintTimer = null;
      if (!state.gameOver) state = state.copyWith(clearHint: true);
    });
    return true;
  }

  /// Сам находит и применяет лучший ход текущего игрока.
  bool powerAutoPlay() {
    if (!_powerReady) return false;
    final move = _bestMove();
    if (move == null) return false;
    state = state.copyWith(clearHint: true);
    _applyPlacement(move.pieceId, move.cells, move.r, move.c);
    return true;
  }

  /// Очищает строку [row], начисляя очки текущему игроку.
  bool powerClearRow(int row) =>
      _applyArbitraryClear([for (int c = 0; c < boardSize; c++) Coord(row, c)]);

  /// Очищает столбец [col], начисляя очки текущему игроку.
  bool powerClearCol(int col) =>
      _applyArbitraryClear([for (int r = 0; r < boardSize; r++) Coord(r, col)]);

  /// Очищает квадрат 3×3 вокруг `(centerR, centerC)`.
  bool powerBomb(int centerR, int centerC) => _applyArbitraryClear([
    for (int dr = -1; dr <= 1; dr++)
      for (int dc = -1; dc <= 1; dc++) Coord(centerR + dr, centerC + dc),
  ]);

  /// Лучший ход текущего игрока (оценка уровнем `hard`).
  CandidateMove? _bestMove() => chooseBotMove(
    state.board,
    state.currentPlayer.hand,
    BotLevel.hard,
    config.cfg,
    _botRng,
  );

  /// Индекс ориентации в [os], совпадающей с [cells] (или 0).
  int _orientIndexOf(List<List<Coord>> os, List<Coord> cells) {
    for (int i = 0; i < os.length; i++) {
      if (_sameCells(os[i], cells)) return i;
    }
    return 0;
  }

  /// Поэлементное равенство наборов клеток (оба нормализованы ядром).
  bool _sameCells(List<Coord> a, List<Coord> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].r != b[i].r || a[i].c != b[i].c) return false;
    }
    return true;
  }

  /// Очищает произвольный набор клеток (только заполненные), начисляя очки
  /// текущему игроку как одиночную очистку. Ход НЕ передаётся. Возвращает
  /// `false`, если очищать нечего.
  bool _applyArbitraryClear(List<Coord> targets) {
    if (!_powerReady) return false;
    final cleared = <Coord>[
      for (final t in targets)
        if (t.r >= 0 &&
            t.r < boardSize &&
            t.c >= 0 &&
            t.c < boardSize &&
            state.board[t.r][t.c].filled)
          t,
    ];
    if (cleared.isEmpty) return false;
    final board = cloneBoard(state.board);
    applyClears(board, cleared);
    final p = state.current;
    final gained = scoreForMove(1, 0, false, config.cfg);
    final players = [...state.players];
    players[p] = players[p].copyWith(score: players[p].score + gained);
    state = state.copyWith(
      board: board,
      players: players,
      moveSeq: state.moveSeq + 1,
      lastClearCount: 0,
      lastPerfect: false,
      clearHint: true,
    );
    _autoSave();
    return true;
  }

  // ── Старт партии ─────────────────────────────────────────────────────────

  /// Создаёт стартовое состояние: новые мешки, розданные руки, пустая доска.
  GameState _freshState() {
    _bags = [Bag(config.seed), Bag(config.seed ^ 0x9e3779b9)];
    _botRng = makeRng(config.seed + 777);
    _forceRng = makeRng(config.seed + 999);
    final names = [
      'Игрок 1',
      config.mode == MatchMode.hotseat ? 'Игрок 2' : 'Бот',
    ];
    final players = [
      for (int i = 0; i < 2; i++)
        PlayerState(
          score: 0,
          combo: 0,
          hand: _dealHand(_bags[i], config.cfg.handSize),
          name: names[i],
        ),
    ];
    final limit = turnTimeForRound(0, config.cfg);
    return GameState(
      board: emptyBoard(),
      players: players,
      current: 0,
      round: 0,
      gameOver: false,
      winner: null,
      selectedPieceId: null,
      orientIndex: 0,
      turnLimit: limit,
      turnRemaining: limit,
      cfg: config.cfg,
      nextPieces: _peekNext(),
    );
  }

  /// Следующая фигура каждого мешка (для превью «дальше»).
  List<PieceType> _peekNext() => [_bags[0].peek(), _bags[1].peek()];

  /// Раздаёт руку из [k] фигур, по возможности без повторов типов.
  List<PieceInstance> _dealHand(Bag bag, int k) {
    final hand = <PieceInstance>[];
    for (int i = 0; i < k; i++) {
      hand.add(bag.drawAvoiding(hand.map((p) => p.type).toSet()));
    }
    return hand;
  }

  // ── Save / resume ──────────────────────────────────────────────────────────

  /// Восстанавливает состояние из сохранёнки: мешки (точное внутреннее
  /// состояние), руки (клетки выводятся из типа), доска, ход, раунд. rng бота и
  /// force-place воссоздаются от seed (допустимая микро-расхождение).
  GameState _restore(SavedGame saved) {
    _bags = [for (final b in saved.bags) b.toBag()];
    _botRng = makeRng(config.seed + 777);
    _forceRng = makeRng(config.seed + 999);
    final players = [
      for (final sp in saved.players)
        PlayerState(
          score: sp.score,
          combo: sp.combo,
          name: sp.name,
          hand: [
            for (final h in sp.hand)
              PieceInstance(
                id: h.id,
                type: h.type,
                cells: normalize(baseShapes[h.type]!),
              ),
          ],
        ),
    ];
    final limit = turnTimeForRound(saved.round, config.cfg);
    return GameState(
      board: decodeBoard(saved.board),
      players: players,
      current: saved.current,
      round: saved.round,
      gameOver: false,
      winner: null,
      selectedPieceId: null,
      orientIndex: 0,
      turnLimit: limit,
      turnRemaining: limit,
      cfg: config.cfg,
      nextPieces: _peekNext(),
    );
  }

  /// Снимает текущее состояние партии в сериализуемую сохранёнку.
  SavedGame _snapshot() => SavedGame(
    mode: config.mode,
    botLevel: config.botLevel,
    seed: config.seed,
    board: encodeBoard(state.board),
    players: [
      for (final p in state.players)
        SavedPlayer(
          score: p.score,
          combo: p.combo,
          name: p.name,
          hand: [for (final pi in p.hand) (id: pi.id, type: pi.type)],
        ),
    ],
    bags: [for (final b in _bags) BagSnapshot.of(b)],
    current: state.current,
    round: state.round,
  );

  /// Авто-сохранение после хода: пишем снимок (или удаляем сохранёнку по
  /// завершении). Зрительский bot×bot не сохраняем.
  void _autoSave() {
    if (config.mode == MatchMode.botvbot) return;
    final store = ref.read(savedGameStoreProvider);
    if (state.gameOver) {
      store.clear();
    } else {
      store.save(_snapshot());
    }
  }

  // ── Ход ──────────────────────────────────────────────────────────────────

  /// Применяет постановку фигуры [pieceId] (клетки [cells]) с якорем `(r, c)`:
  /// очистка, очки, пополнение руки, передача хода, сброс таймера, тупик.
  void _applyPlacement(String pieceId, List<Coord> cells, int r, int c) {
    final player = state.current;
    final board = cloneBoard(state.board);
    place(board, cells, r, c, player);
    final clears = findClears(board);
    applyClears(board, clears.cleared);
    final perfect = clears.count > 0 && isPerfectClear(board);

    final before = state.players[player];
    final gained = scoreForMove(
      clears.count,
      before.combo,
      perfect,
      config.cfg,
    );
    final newHand = [
      for (final p in before.hand)
        if (p.id != pieceId) p,
    ];
    newHand.add(_bags[player].drawAvoiding(newHand.map((p) => p.type).toSet()));

    final players = [...state.players];
    players[player] = before.copyWith(
      score: before.score + gained,
      combo: clears.count > 0 ? before.combo + 1 : 0,
      hand: newHand,
    );

    final next = 1 - player;
    final round = player == 1 ? state.round + 1 : state.round;
    final limit = turnTimeForRound(round, config.cfg);

    var nextState = state.copyWith(
      board: board,
      players: players,
      current: next,
      round: round,
      clearSelection: true,
      orientIndex: 0,
      turnLimit: limit,
      turnRemaining: limit,
      moveSeq: state.moveSeq + 1,
      lastClearCount: clears.count,
      lastPerfect: perfect,
      nextPieces: _peekNext(),
    );

    // Тупик: следующий игрок не может сходить — партия окончена.
    if (!hasAnyMove(board, players[next].hand, config.cfg)) {
      nextState = _finishGame(nextState);
    }

    state = nextState;
    _armTimers(state);
    _autoSave();
  }

  /// Завершает партию: считает победителя по счёту (равенство — ничья).
  GameState _finishGame(GameState s) {
    final s0 = s.players[0].score;
    final s1 = s.players[1].score;
    final winner = s0 == s1 ? null : (s0 > s1 ? 0 : 1);
    return s.copyWith(
      gameOver: true,
      winner: winner,
      clearWinner: winner == null,
      clearSelection: true,
    );
  }

  // ── Таймеры (бот + blitz) ──────────────────────────────────────────────────

  /// Переинициализирует таймеры под ход состояния [s]: бот — отложенный ход;
  /// человек — запуск blitz-тикера (если таймер включён). Состояние не эмитит
  /// (лимит уже выставлен при смене хода).
  void _armTimers(GameState s) {
    _botTimer?.cancel();
    _blitzTicker?.cancel();
    if (s.gameOver || s.paused) return;
    if (config.isBot(s.current)) {
      final delayMs = ref.read(settingsControllerProvider).botDelayMs;
      _botTimer = Timer(
        delayMs > 0 ? Duration(milliseconds: delayMs) : _botThinkDelayDefault,
        _botMove,
      );
      return;
    }
    if (!s.turnLimit.isFinite) return; // blitz выключен
    _blitzTicker = Timer.periodic(_blitzTick, (_) => _tick());
  }

  /// Один тик blitz-таймера: убывание времени, при нуле — force-place.
  void _tick() {
    final s = state;
    if (s.gameOver || s.paused || config.isBot(s.current)) {
      _blitzTicker?.cancel();
      return;
    }
    final remaining = s.turnRemaining - _blitzStep;
    if (remaining <= 0) {
      _onTimeout();
    } else {
      state = s.copyWith(turnRemaining: remaining);
    }
  }

  /// Таймаут хода: ставит фигуру force-place (предпочитая выбранную), либо
  /// завершает партию при тупике.
  void _onTimeout() {
    _blitzTicker?.cancel();
    final s = state;
    final move = forcePlace(
      s.board,
      s.currentPlayer.hand,
      config.cfg,
      _forceRng,
      preferredPieceId: s.selectedPieceId,
    );
    if (move == null) {
      state = _finishGame(s);
      return;
    }
    _applyPlacement(move.pieceId, move.cells, move.r, move.c);
  }

  /// Ход бота: выбирает и применяет ход, либо завершает партию при тупике.
  void _botMove() {
    if (state.gameOver || !config.isBot(state.current)) return;
    final move = chooseBotMove(
      state.board,
      state.currentPlayer.hand,
      config.botLevel,
      config.cfg,
      _botRng,
    );
    if (move == null) {
      state = _finishGame(state);
      return;
    }
    _applyPlacement(move.pieceId, move.cells, move.r, move.c);
  }
}

/// Провайдер ViewModel партии (семейство по [MatchConfig]).
final gameProvider =
    NotifierProvider.family<GameNotifier, GameState, MatchConfig>(
      GameNotifier.new,
    );
