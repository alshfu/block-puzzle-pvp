/// transport_provider.dart — провайдер фабрики транспорта (DI-шов).
///
/// За что отвечает файл:
///   Отдаёт фабрику [ITransport] по [Uri]. По умолчанию — реальный
///   [WsTransport]; в тестах переопределяется на `FakeTransport`, что позволяет
///   гонять нотифайеры онлайна без сети.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'transport.dart';

/// Фабрика транспорта (инъекция). Тесты переопределяют через
/// `transportFactoryProvider.overrideWithValue((uri) => fakeTransport)`.
final transportFactoryProvider = Provider<TransportFactory>(
  (ref) => defaultTransportFactory,
);
