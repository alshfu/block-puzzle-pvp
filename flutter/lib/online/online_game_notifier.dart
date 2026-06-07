/// online_game_notifier.dart — ViewModel живого онлайн-матча (MVVM, ViewModel).
///
/// За что отвечает файл:
///   Держит соединение с игровой комнатой Node-сервера, шлёт `hello`/`move`/
///   `resign`/`rematch_*`, редьюсит входящие сообщения в [OnlineMatchState] и
///   восстанавливает сессию при разрыве (reconnect с backoff + повторный
///   `hello`). Выбор фигуры — локальное состояние; постановка считает клетки
///   через адаптер [onlineToGameState] (путь ядра `orientations`), поэтому
///   серверный anti-cheat проходит по построению. Без BuildContext.
///
/// Соответствие TS: `src/ui/online/useOnlineGame.ts`.
library;

import 'dart:async';
import 'dart:math' as math;

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
        _transport?.send({'type': 'hello', 'profile': args.me.toJson()});
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
        );
      case 'state':
        final game = OnlineGameState.fromJson(
          msg['state'] as Map<String, dynamic>,
        );
        state = state.copyWith(
          game: game,
          moveSeq: state.moveSeq + 1,
          lastMoveOwner: (msg['lastMoveOwner'] as num?)?.toInt(),
          lastGained: (msg['gained'] as num?)?.toInt() ?? 0,
          lastPerfect: msg['perfect'] as bool? ?? false,
          clearSelection: true,
          rematchYours: game.isOver ? state.rematchYours : false,
          rematchTheirs: game.isOver ? state.rematchTheirs : false,
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

/// Провайдер ViewModel онлайн-матча (семейство по [OnlineMatchArgs]).
final onlineGameProvider =
    NotifierProvider.family<
      OnlineGameNotifier,
      OnlineMatchState,
      OnlineMatchArgs
    >(OnlineGameNotifier.new);
