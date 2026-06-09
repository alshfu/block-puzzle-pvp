/// transport.dart — транспорт WebSocket для онлайна (граница ввода-вывода).
///
/// За что отвечает файл:
///   Абстракция [ITransport] над одним WS-соединением: поток входящих
///   JSON-сообщений, поток статуса соединения и отправка. Конкретная
///   реализация [WsTransport] оборачивает `WebSocketChannel` (работает и на
///   web/CanvasKit). Транспорт «тупой» — без reconnect и без знания протокола;
///   reconnect и редьюсеры живут в нотифайерах. Это делает границу мокаемой в
///   тестах ([FakeTransport] в тестовом коде).
///
/// Соответствие TS: низкоуровневая часть `src/ui/online/client.ts` (open/send/
/// close поверх PartySocket).
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Статус WS-соединения.
enum TransportStatus { connecting, open, closed }

/// Транспорт: поток входящих сообщений + статус + отправка.
abstract interface class ITransport {
  /// Декодированные входящие JSON-объекты (broadcast).
  Stream<Map<String, dynamic>> get incoming;

  /// Изменения статуса соединения (broadcast).
  Stream<TransportStatus> get status;

  /// Отправляет JSON-сообщение (кодируется в текст).
  void send(Map<String, dynamic> message);

  /// Закрывает соединение и освобождает ресурсы.
  Future<void> close();
}

/// Фабрика транспорта по URI (инъекция для тестов).
typedef TransportFactory = ITransport Function(Uri uri);

/// Реальный WS-транспорт поверх [WebSocketChannel].
class WsTransport implements ITransport {
  /// Адрес сервера.
  final Uri uri;

  final StreamController<Map<String, dynamic>> _in =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<TransportStatus> _status =
      StreamController<TransportStatus>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _closed = false;

  /// Создаёт транспорт и сразу подключается к [uri].
  WsTransport(this.uri) {
    _connect();
  }

  void _connect() {
    _status.add(TransportStatus.connecting);
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    // ready завершится при успешном апгрейде; ошибки придут в onError.
    channel.ready
        .then((_) {
          if (!_closed) _status.add(TransportStatus.open);
        })
        .catchError((_) {
          if (!_closed) _status.add(TransportStatus.closed);
        });
    _sub = channel.stream.listen(
      (dynamic data) {
        if (data is String) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map<String, dynamic>) _in.add(decoded);
          } catch (_) {
            // не-JSON или мусор — игнорируем
          }
        }
      },
      onError: (_) {
        if (!_closed) _status.add(TransportStatus.closed);
      },
      onDone: () {
        if (!_closed) _status.add(TransportStatus.closed);
      },
      cancelOnError: false,
    );
  }

  @override
  Stream<Map<String, dynamic>> get incoming => _in.stream;

  @override
  Stream<TransportStatus> get status => _status.stream;

  @override
  void send(Map<String, dynamic> message) {
    final sink = _channel?.sink;
    if (sink == null || _closed) return;
    sink.add(jsonEncode(message));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sub?.cancel();
    await _channel?.sink.close();
    if (!_in.isClosed) await _in.close();
    if (!_status.isClosed) await _status.close();
  }
}

/// Транспорт по умолчанию: реальный [WsTransport].
ITransport defaultTransportFactory(Uri uri) => WsTransport(uri);
