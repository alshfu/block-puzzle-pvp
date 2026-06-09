/// lobby_notifier.dart — ViewModel матчмейкинга (MVVM, ViewModel).
///
/// За что отвечает файл:
///   Управляет очередью поиска соперника поверх lobby-«партии» Node-сервера:
///   подключается к `/parties/lobby/main`, шлёт `queue`/`cancel`, редьюсит
///   ответы (`queued`/`matched`/`bot_fallback`/`error`) в [LobbyState]. View
///   слушает состояние и навигирует на матч/бота. Без BuildContext.
///
/// Соответствие TS: `src/ui/online/client.ts` (openLobby) + лоббийная часть
/// `OnlineMenuScreen`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'online_models.dart';
import 'party_host.dart';
import 'transport.dart';
import 'transport_provider.dart';

/// Состояние лобби (поиска соперника).
sealed class LobbyState {
  const LobbyState();
}

/// Очередь не запущена.
class LobbyIdle extends LobbyState {
  const LobbyIdle();
}

/// В очереди: позиция и сколько секунд ждём.
class LobbyQueued extends LobbyState {
  final int position;
  final int waitedSec;
  const LobbyQueued(this.position, this.waitedSec);
}

/// Найден соперник: комната, его профиль и токен слота (SEC-2, для hello).
class LobbyMatched extends LobbyState {
  final String roomId;
  final OnlineProfile opponent;

  /// Одноразовый секрет слота из `matched` (может отсутствовать у старого
  /// сервера до раскатки SEC-2).
  final String? token;

  const LobbyMatched(this.roomId, this.opponent, {this.token});
}

/// Ждали слишком долго — предлагаем игру с ботом локально.
class LobbyBotFallback extends LobbyState {
  const LobbyBotFallback();
}

/// Ошибка лобби.
class LobbyError extends LobbyState {
  final String reason;
  const LobbyError(this.reason);
}

/// ViewModel матчмейкинга.
class LobbyNotifier extends Notifier<LobbyState> {
  ITransport? _transport;

  @override
  LobbyState build() {
    ref.onDispose(() => _transport?.close());
    return const LobbyIdle();
  }

  /// Встаёт в очередь поиска под профилем [me].
  void queue(OnlineProfile me) {
    _transport?.close();
    final factory = ref.read(transportFactoryProvider);
    final transport = factory(partyUriLobby());
    _transport = transport;
    transport.incoming.listen(_onMessage);
    transport.status.listen((s) {
      if (s == TransportStatus.open) {
        transport.send({'type': 'queue', 'profile': me.toJson()});
      } else if (s == TransportStatus.closed && state is LobbyQueued) {
        state = const LobbyError('соединение потеряно');
      }
    });
  }

  /// Отменяет поиск и возвращает в idle.
  void cancel() {
    _transport?.send({'type': 'cancel'});
    _transport?.close();
    _transport = null;
    state = const LobbyIdle();
  }

  void _onMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'queued':
        state = LobbyQueued(
          (msg['position'] as num?)?.toInt() ?? 0,
          (msg['waitedSec'] as num?)?.toInt() ?? 0,
        );
      case 'matched':
        state = LobbyMatched(
          msg['roomId'] as String,
          OnlineProfile.fromJson(msg['opponent'] as Map<String, dynamic>),
          token: msg['token'] as String?,
        );
      case 'bot_fallback':
        state = const LobbyBotFallback();
      case 'error':
        state = LobbyError(msg['reason'] as String? ?? 'ошибка');
    }
  }
}

/// Провайдер ViewModel лобби.
final lobbyProvider = NotifierProvider<LobbyNotifier, LobbyState>(
  LobbyNotifier.new,
);
