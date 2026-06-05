/// game_notifier.dart — ViewModel партии (MVVM, слой ViewModel).
///
/// За что отвечает файл:
///   Управляет ходом партии поверх чистого ядра (Model): держит мешки и rng,
///   выставляет команды для View (выбор фигуры, поворот/отражение, постановка,
///   новая игра) и сам ходит за бота через `Timer`. Никакого `BuildContext`,
///   виджетов и `dart:ui` — только Riverpod + ядро.
///
/// Соответствие TS: `src/ui/useGame.ts` (reducer + refs на bag/rng + бот через
/// setTimeout). Blitz-таймер/force-place подключим в Фазе 3.
library;

import 'dart:async';

import 'package:block_duel/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_state.dart';
import 'match_config.dart';

/// Задержка перед ходом бота — чтобы ход был визуально читаем.
const Duration _botThinkDelay = Duration(milliseconds: 350);

/// ViewModel партии. Семейство по [MatchConfig]: конфиг приходит в конструктор
/// (API Riverpod 3.x: `NotifierT Function(ArgT)`), `build()` — без параметров.
class GameNotifier extends Notifier<GameState> {
  /// Конфигурация партии (режим, seed, правила) — ключ семейства.
  final MatchConfig config;

  /// Мешки фигур обоих игроков.
  late List<Bag> _bags;

  /// Источник случайности для решений бота.
  late RandomSource _botRng;

  /// Таймер отложенного хода бота (отменяется при dispose/смене хода).
  Timer? _botTimer;

  /// Создаёт ViewModel для конкретной партии [config].
  GameNotifier(this.config);

  @override
  GameState build() {
    ref.onDispose(() => _botTimer?.cancel());
    final fresh = _freshState();
    // Если первый ход — за ботом (botvbot), запланировать его после построения.
    _scheduleBotIfNeeded(fresh);
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

  /// Начинает новую партию с тем же конфигом.
  void newGame() {
    _botTimer?.cancel();
    final fresh = _freshState();
    state = fresh;
    _scheduleBotIfNeeded(fresh);
  }

  // ── Внутреннее ─────────────────────────────────────────────────────────────

  /// Создаёт стартовое состояние: новые мешки, розданные руки, пустая доска.
  GameState _freshState() {
    _bags = [Bag(config.seed), Bag(config.seed ^ 0x9e3779b9)];
    _botRng = makeRng(config.seed + 777);
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
    return GameState(
      board: emptyBoard(),
      players: players,
      current: 0,
      round: 0,
      gameOver: false,
      winner: null,
      selectedPieceId: null,
      orientIndex: 0,
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

  /// Применяет постановку фигуры [pieceId] (клетки [cells]) с якорем `(r, c)`:
  /// очистка, очки, пополнение руки, передача хода, проверка тупика.
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

    var nextState = state.copyWith(
      board: board,
      players: players,
      current: next,
      round: round,
      clearSelection: true,
      orientIndex: 0,
    );

    // Тупик: следующий игрок не может сходить — партия окончена.
    if (!hasAnyMove(board, players[next].hand, config.cfg)) {
      nextState = _finishGame(nextState);
    }

    state = nextState;
    if (!state.gameOver) _scheduleBotIfNeeded(state);
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

  /// Планирует ход бота, если сейчас ходит управляемый ботом игрок.
  void _scheduleBotIfNeeded(GameState s) {
    _botTimer?.cancel();
    if (s.gameOver || !config.isBot(s.current)) return;
    _botTimer = Timer(_botThinkDelay, _botMove);
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
