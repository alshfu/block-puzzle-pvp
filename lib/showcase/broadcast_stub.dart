/// broadcast_stub.dart — заглушка захвата/трансляции (не-Web платформы).
///
/// За что отвечает файл:
///   На платформах без браузерных `getDisplayMedia`/`MediaRecorder`/`WebSocket`
///   захват и онлайн-эфир недоступны — [Broadcaster.supported] == false,
///   методы — no-op.
library;

/// Захват/запись/трансляция (заглушка для не-Web).
class Broadcaster {
  /// Колбэк статусов эфира (на не-Web не вызывается).
  void Function(String status)? onStatus;

  /// Поддерживается ли захват на этой платформе.
  bool get supported => false;

  /// Идёт ли запись.
  bool get recording => false;

  /// Идёт ли онлайн-трансляция.
  bool get streaming => false;

  /// Запускает запись клипа. На не-Web всегда `false`.
  Future<bool> startRecording() async => false;

  /// Запускает онлайн-эфир. На не-Web всегда `false`.
  Future<bool> startStreaming(String relayUrl, String streamKey) async => false;

  /// Останавливает запись/эфир (no-op на не-Web).
  void stop() {}

  /// Освобождает ресурсы.
  void dispose() {}
}
