/// fake_transport.dart — мок транспорта для тестов нотифайеров онлайна.
///
/// Реализует [ITransport] на управляемых StreamController'ах: тест пушит
/// входящие сообщения и статусы, а исходящие `send` копятся в [sent].
library;

import 'dart:async';

import 'package:block_duel/online/transport.dart';

/// Поддельный транспорт: ручное управление входящими/статусом + лог исходящих.
class FakeTransport implements ITransport {
  final StreamController<Map<String, dynamic>> _in =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<TransportStatus> _status =
      StreamController<TransportStatus>.broadcast();

  /// Все отправленные сообщения (в порядке отправки).
  final List<Map<String, dynamic>> sent = [];

  /// Закрыт ли транспорт.
  bool closed = false;

  /// Эмулирует входящее сообщение от сервера.
  void emit(Map<String, dynamic> message) => _in.add(message);

  /// Эмулирует смену статуса соединения.
  void emitStatus(TransportStatus s) => _status.add(s);

  @override
  Stream<Map<String, dynamic>> get incoming => _in.stream;

  @override
  Stream<TransportStatus> get status => _status.stream;

  @override
  void send(Map<String, dynamic> message) => sent.add(message);

  @override
  Future<void> close() async {
    closed = true;
    if (!_in.isClosed) await _in.close();
    if (!_status.isClosed) await _status.close();
  }
}
