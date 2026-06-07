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

import 'game_state.dart';
import 'match_config.dart';
import 'saved_game.dart';
import 'saved_game_store.dart';

/// Задержка перед ходом бота — чтобы ход был визуально читаем.
const Duration _botThinkDelay = Duration(milliseconds: 350);

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

  /// Создаёт ViewModel для конкретной партии [config].
  GameNotifier(this.config);

  @override
  GameState build() {
    ref.onDispose(() {
      _botTimer?.cancel();
      _blitzTicker?.cancel();
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

  /// Начинает новую партию с тем же конфигом (сбрасывает сохранёнку).
  void newGame() {
    ref.read(savedGameStoreProvider).clear();
    final fresh = _freshState();
    state = fresh;
    _armTimers(fresh);
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
    );
  }

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
    if (s.gameOver) return;
    if (config.isBot(s.current)) {
      _botTimer = Timer(_botThinkDelay, _botMove);
      return;
    }
    if (!s.turnLimit.isFinite) return; // blitz выключен
    _blitzTicker = Timer.periodic(_blitzTick, (_) => _tick());
  }

  /// Один тик blitz-таймера: убывание времени, при нуле — force-place.
  void _tick() {
    final s = state;
    if (s.gameOver || config.isBot(s.current)) {
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
