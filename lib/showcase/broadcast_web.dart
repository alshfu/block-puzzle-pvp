/// broadcast_web.dart — браузерный захват трансляции для Авто-шоу (Web).
///
/// За что отвечает файл:
///   Реальный клиентский слой стриминг-пайплайна: захват экрана/вкладки через
///   `getDisplayMedia`, запись `MediaRecorder` в WebM и скачивание клипа для
///   YouTube Shorts. Пользователь жмёт «В эфир» → выбирает вкладку с
///   вертикальным Авто-шоу → запись → «Стоп» → файл скачивается.
///
///   Прямой RTMP-эфир на YouTube из браузера невозможен — это делается серверным
///   релеем (🔒). Здесь — запись готового вертикального ролика.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Захват/запись трансляции через браузерные media-API.
class Broadcaster {
  web.MediaRecorder? _rec;
  web.MediaStream? _stream;
  final List<web.Blob> _chunks = [];
  bool _recording = false;

  /// На Web захват в принципе поддерживается (доступность решается при запуске).
  bool get supported => true;

  /// Идёт ли запись.
  bool get recording => _recording;

  /// Запускает захват экрана/вкладки и запись. Возвращает `false`, если
  /// пользователь отказал в доступе или API недоступно.
  Future<bool> startRecording() async {
    try {
      final stream = await web.window.navigator.mediaDevices
          .getDisplayMedia(
            web.DisplayMediaStreamOptions(
              video: true.toJS,
              audio: false.toJS,
            ),
          )
          .toDart;
      _stream = stream;
      _chunks.clear();
      final rec = web.MediaRecorder(
        stream,
        web.MediaRecorderOptions(mimeType: 'video/webm'),
      );
      rec.ondataavailable = (web.BlobEvent event) {
        if (event.data.size > 0) _chunks.add(event.data);
      }.toJS;
      rec.onstop = (web.Event _) {
        _download();
        final tracks = _stream?.getTracks().toDart ?? const [];
        for (final t in tracks) {
          t.stop();
        }
        _stream = null;
      }.toJS;
      rec.start();
      _rec = rec;
      _recording = true;
      return true;
    } catch (_) {
      _recording = false;
      return false;
    }
  }

  /// Останавливает запись — по `onstop` клип скачивается.
  void stop() {
    if (!_recording) return;
    _recording = false;
    _rec?.stop();
    _rec = null;
  }

  /// Освобождает поток, если остался активным.
  void dispose() {
    final tracks = _stream?.getTracks().toDart ?? const [];
    for (final t in tracks) {
      t.stop();
    }
    _stream = null;
    _rec = null;
  }

  /// Собирает WebM из чанков и инициирует скачивание файла.
  void _download() {
    if (_chunks.isEmpty) return;
    final blob = web.Blob(
      _chunks.toJS,
      web.BlobPropertyBag(type: 'video/webm'),
    );
    final url = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = 'blockduel-shorts.webm';
    a.click();
    web.URL.revokeObjectURL(url);
    _chunks.clear();
  }
}
