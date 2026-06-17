/// broadcast_stub.dart — заглушка захвата трансляции (не-Web платформы).
///
/// За что отвечает файл:
///   На платформах без браузерного `getDisplayMedia`/`MediaRecorder` захват
///   недоступен — [Broadcaster.supported] == false, методы — no-op.
library;

/// Захват трансляции (заглушка для не-Web).
class Broadcaster {
  /// Поддерживается ли захват на этой платформе.
  bool get supported => false;

  /// Идёт ли запись.
  bool get recording => false;

  /// Запускает запись. На не-Web всегда `false`.
  Future<bool> startRecording() async => false;

  /// Останавливает запись и сохраняет клип (no-op на не-Web).
  void stop() {}

  /// Освобождает ресурсы.
  void dispose() {}
}
