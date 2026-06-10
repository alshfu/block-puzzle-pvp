/// online_game_notifier.dart — ViewModel живого онлайн-матча (MVVM, ViewModel).
///
/// За что отвечает файл:
///   Держит соединение с игровой комнатой Node-сервера, шлёт `hello`/`move`/
///   `resign`/`rematch_*`, редьюсит входящие сообщения в [OnlineMatchState] и
///   восстанавливает сессию при разрыве (reconnect с backoff + повторный
///   `hello`). Выбор фигуры — локальное состояние; постановка считает клетки
///   через адаптер [onlineToGameState] (путь ядра `orientations`), поэтому
///   серверный anti-cheat проходит по построению. Без BuildContext.
///   Для разработчиков есть скрытый авто-игрок: [OnlineGameNotifier.pilotPlayTurn]
///   (зеркало офлайн-пилота, паритет с TS `PilotMode = "online"`).
///
/// Соответствие TS: `src/ui/online/useOnlineGame.ts`.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:block_duel/core/core.dart'
    show BotLevel, Coord, RandomSource, chooseBotMove, makeRng, orientations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'online_match_state.dart';
import 'online_models.dart';
import 'online_to_game_state.dart';
import 'online_wire.dart';
import 'party_host.dart';
import 'transport.dart';
import 'transport_provider.dart';

/// Базовая задержка reconnect (удваивается с каждой попыткой).
const Duration _reconnectBase = Duration(milliseconds: 500);

/// Максимальная задержка reconnect.
const Duration _reconnectMax = Duration(seconds: 30);

/// ViewModel онлайн-матча. Семейство по [OnlineMatchArgs] (комната + профиль).
class OnlineGameNotifier extends Notifier<OnlineMatchState> {
  /// Ключ матча (комната + свой профиль).
  final OnlineMatchArgs args;

  ITransport? _transport;
  Timer? _reconnect;
  int _attempt = 0;
  bool _disposed = false;
  final math.Random _rng = math.Random();

  /// Создаёт ViewModel матча [args].
  OnlineGameNotifier(this.args);

  @override
  OnlineMatchState build() {
    ref.onDispose(() {
      _disposed = true;
      _reconnect?.cancel();
      _transport?.close();
    });
    _connect();
    return const OnlineMatchState();
  }

  // ── Соединение ─────────────────────────────────────────────────────────────

  void _connect() {
    if (_disposed) return;
    _transport?.close();
    final factory = ref.read(transportFactoryProvider);
    final transport = factory(partyUriRoom(args.roomId));
    _transport = transport;
    transport.incoming.listen(_onMessage);
    transport.status.listen(_onStatus);
  }

  void _onStatus(TransportStatus s) {
    if (_disposed) return;
    switch (s) {
      case TransportStatus.open:
        _attempt = 0;
        state = state.copyWith(connected: true, clearError: true);
        _transport?.send({
          'type': 'hello',
          'profile': args.me.toJson(),
          if (args.token != null) 'token': args.token,
        });
      case TransportStatus.connecting:
        break;
      case TransportStatus.closed:
        state = state.copyWith(connected: false);
        _scheduleReconnect();
    }
  }

  /// Планирует переподключение, пока матч не завершён.
  void _scheduleReconnect() {
    if (_disposed) return;
    final game = state.game;
    if (game != null && game.isOver) return; // матч окончен — не цепляемся
    _reconnect?.cancel();
    final backoffMs = math.min(
      _reconnectMax.inMilliseconds,
      _reconnectBase.inMilliseconds * (1 << _attempt),
    );
    final jitter = (backoffMs * 0.2 * _rng.nextDouble()).round();
    _attempt = math.min(_attempt + 1, 16);
    _reconnect = Timer(Duration(milliseconds: backoffMs + jitter), _connect);
  }

  // ── Команды View ─────────────────────────────────────────────────────────

  /// Мой ли сейчас ход (можно ли взаимодействовать).
  bool get _myTurn {
    final g = state.game;
    return state.connected && g != null && !g.isOver && g.current == state.you;
  }

  /// Выбирает фигуру из своей руки (сбрасывает ориентацию).
  void selectPiece(String pieceId) {
    if (!_myTurn) return;
    state = state.copyWith(selectedPieceId: pieceId, orientIndex: 0);
  }

  /// Снимает выбор фигуры.
  void deselect() =>
      state = state.copyWith(clearSelection: true, orientIndex: 0);

  /// Поворачивает выбранную фигуру.
  void rotateSelected() {
    if (state.selectedPieceId == null) return;
    state = state.copyWith(orientIndex: state.orientIndex + 1);
  }

  /// Ставит выбранную фигуру с якорем `(r, c)`: считает клетки текущей
  /// ориентации через адаптер и шлёт `move` (сервер валидирует).
  void placeAt(int r, int c) {
    if (!_myTurn) return;
    final game = state.game;
    final pieceId = state.selectedPieceId;
    if (game == null || pieceId == null) return;
    final gs = onlineToGameState(
      game,
      you: state.you,
    ).copyWith(selectedPieceId: pieceId, orientIndex: state.orientIndex);
    final cells = gs.activeCells;
    if (cells == null) return;
    if (!gs.canPlaceAt(r, c)) return; // локальный pre-check; сервер авторитетен
    _transport?.send(moveToJson(pieceId: pieceId, cells: cells, r: r, c: c));
  }

  /// Сдаётся (моментальное поражение).
  void resign() => _transport?.send({'type': 'resign'});

  // ── Pilot (скрытый авто-игрок для разработчиков) ───────────────────────────

  /// Детерминированный rng пилота (свой на инстанс матча, не PRNG партии).
  late final RandomSource _pilotRng = makeRng(31337);

  /// Один ход «пилота» в онлайн-матче: выбирает лучший ход (`chooseBotMove`,
  /// уровень hard) за локального игрока, показывает выбор/ориентацию и шлёт
  /// `move` штатным путём [placeAt] — клетки считаются через `orientations`
  /// ядра, поэтому серверный anti-cheat проходит по построению. Зеркало
  /// офлайн-пилота `GameNotifier.pilotPlayTurn`; TS: `src/ui/pilot` (online).
  /// Возвращает `true`, если ход отправлен.
  bool pilotPlayTurn() {
    if (!_myTurn) return false;
    final game = state.game!;
    final gs = onlineToGameState(game, you: state.you);
    final move = chooseBotMove(
      gs.board,
      gs.currentPlayer.hand,
      BotLevel.hard,
      gs.cfg,
      _pilotRng,
    );
    if (move == null) return false;
    final os = orientations(
      move.type,
      gs.cfg.rotationEnabled,
      gs.cfg.flipEnabled,
    );
    // Показать выбор и ориентацию (наглядно, как реальные действия игрока).
    state = state.copyWith(
      selectedPieceId: move.pieceId,
      orientIndex: _orientIndexOf(os, move.cells),
    );
    placeAt(move.r, move.c);
    return true;
  }

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

  /// Запрашивает ремач.
  void requestRematch() {
    state = state.copyWith(rematchYours: true);
    _transport?.send({'type': 'rematch_request'});
  }

  /// Отменяет запрос ремача.
  void cancelRematch() {
    state = state.copyWith(rematchYours: false);
    _transport?.send({'type': 'rematch_cancel'});
  }

  // ── Редьюсер входящих ──────────────────────────────────────────────────────

  void _onMessage(Map<String, dynamic> msg) {
    if (_disposed) return;
    switch (msg['type']) {
      case 'joined':
        state = state.copyWith(
          game: OnlineGameState.fromJson(msg['state'] as Map<String, dynamic>),
          you: (msg['you'] as num).toInt(),
          connected: true,
          opponentLeft: false,
          clearOpponentTimeout: true,
          clearSelection: true,
          rematchYours: false,
          rematchTheirs: false,
          clearError: true,
          resetMatchAcc:
              true, // новый матч (в т.ч. ремач) — обнуляем накопители
        );
      case 'state':
        final game = OnlineGameState.fromJson(
          msg['state'] as Map<String, dynamic>,
        );
        final owner = (msg['lastMoveOwner'] as num?)?.toInt();
        final perfect = msg['perfect'] as bool? ?? false;
        // Накопители ведём только по СВОИМ ходам (для статистики/PvP-ачивок).
        int? clears, maxMulti, bestCombo, perfects;
        if (owner == state.you) {
          final units = _countClearedUnits(game.lastClearedCells ?? const []);
          clears = state.matchClears + units;
          maxMulti = math.max(state.matchMaxMulti, units);
          final combo = state.you < game.players.length
              ? game.players[state.you].combo
              : 0;
          bestCombo = math.max(state.matchBestCombo, combo);
          perfects = state.matchPerfects + (perfect ? 1 : 0);
        }
        state = state.copyWith(
          game: game,
          moveSeq: state.moveSeq + 1,
          lastMoveOwner: owner,
          lastGained: (msg['gained'] as num?)?.toInt() ?? 0,
          lastPerfect: perfect,
          clearSelection: true,
          rematchYours: game.isOver ? state.rematchYours : false,
          rematchTheirs: game.isOver ? state.rematchTheirs : false,
          matchClears: clears,
          matchMaxMulti: maxMulti,
          matchBestCombo: bestCombo,
          matchPerfects: perfects,
        );
      case 'move_rejected':
        state = state.copyWith(
          lastError: msg['reason'] as String? ?? 'ход отклонён',
          rejectSeq: state.rejectSeq + 1,
        );
      case 'opponent_left':
        state = state.copyWith(
          opponentLeft: true,
          opponentTimeoutMs: (msg['willTimeoutMs'] as num?)?.toInt(),
        );
      case 'opponent_reconnected':
        state = state.copyWith(opponentLeft: false, clearOpponentTimeout: true);
      case 'rematch_status':
        state = state.copyWith(
          rematchYours: msg['yours'] as bool? ?? false,
          rematchTheirs: msg['theirs'] as bool? ?? false,
        );
      case 'error':
        state = state.copyWith(lastError: msg['reason'] as String?);
    }
  }
}

/// Оценивает число очищенных линий/боксов по набору очищенных клеток.
///
/// Сервер присылает только объединённый набор `lastClearedCells` (без счётчика
/// `count`), а протокол мы не меняем (кросс-протокол к старому Node-серверу).
/// Поэтому реконструируем количество полных строк/столбцов/боксов 3×3 в наборе.
/// В редких случаях наложения нескольких очисток оценка может слегка
/// переоценить — для метрик статистики и порогов PvP-ачивок это допустимо.
int _countClearedUnits(List<Coord> cells) {
  if (cells.isEmpty) return 0;
  final set = {for (final c in cells) c.r * 9 + c.c};
  var units = 0;
  for (var r = 0; r < 9; r++) {
    var full = true;
    for (var c = 0; c < 9; c++) {
      if (!set.contains(r * 9 + c)) {
        full = false;
        break;
      }
    }
    if (full) units++;
  }
  for (var c = 0; c < 9; c++) {
    var full = true;
    for (var r = 0; r < 9; r++) {
      if (!set.contains(r * 9 + c)) {
        full = false;
        break;
      }
    }
    if (full) units++;
  }
  for (var b = 0; b < 9; b++) {
    final br = (b ~/ 3) * 3;
    final bc = (b % 3) * 3;
    var full = true;
    for (var r = 0; r < 3 && full; r++) {
      for (var c = 0; c < 3; c++) {
        if (!set.contains((br + r) * 9 + (bc + c))) {
          full = false;
          break;
        }
      }
    }
    if (full) units++;
  }
  return units;
}

/// Провайдер ViewModel онлайн-матча (семейство по [OnlineMatchArgs]).
final onlineGameProvider =
    NotifierProvider.family<
      OnlineGameNotifier,
      OnlineMatchState,
      OnlineMatchArgs
    >(OnlineGameNotifier.new);
