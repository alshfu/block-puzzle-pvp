/// broadcast_web.dart — браузерный захват + онлайн-трансляция (Web).
///
/// За что отвечает файл:
///   Клиентский слой стриминга Авто-шоу. Два режима:
///     • запись клипа: `getDisplayMedia` → `MediaRecorder` → скачивание WebM
///       для ручной загрузки как YouTube Shorts;
///     • онлайн-эфир: захват → `MediaRecorder` с timeslice → отправка WebM-чанков
///       по WebSocket на сервер-релей (`server/stream-relay.ts`), который через
///       ffmpeg пушит RTMP на YouTube Live. Ключ трансляции (из YouTube Studio)
///       передаётся релею первым сообщением — OAuth не нужен.
///
///   Прямой RTMP из браузера невозможен — поэтому нужен релей (🔒 деплой на VPS
///   + ffmpeg). Запись клипа работает без сервера.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Захват/запись/трансляция через браузерные media-API.
class Broadcaster {
  web.MediaRecorder? _rec;
  web.MediaStream? _stream;
  web.WebSocket? _ws;
  final List<web.Blob> _chunks = [];
  bool _recording = false;
  bool _streaming = false;

  /// Колбэк статусов эфира от релея ('live' / 'error: ...' / 'ended').
  void Function(String status)? onStatus;

  /// На Web захват поддерживается (доступность решается при запуске).
  bool get supported => true;

  /// Идёт ли локальная запись клипа.
  bool get recording => _recording;

  /// Идёт ли онлайн-трансляция.
  bool get streaming => _streaming;

  // ── Запись клипа (без сервера) ──────────────────────────────────────────────

  /// Запускает захват экрана/вкладки и локальную запись клипа.
  Future<bool> startRecording() async {
    final stream = await _capture();
    if (stream == null) return false;
    _chunks.clear();
    final rec = _makeRecorder(stream);
    rec.ondataavailable = (web.BlobEvent event) {
      if (event.data.size > 0) _chunks.add(event.data);
    }.toJS;
    rec.onstop = (web.Event _) {
      _download();
      _stopTracks();
    }.toJS;
    rec.start();
    _rec = rec;
    _recording = true;
    return true;
  }

  // ── Онлайн-трансляция на YouTube через релей ────────────────────────────────

  /// Запускает онлайн-эфир: захват → WebSocket-релей [relayUrl] с ключом
  /// [streamKey]. Возвращает `false` при отказе в захвате/подключении.
  Future<bool> startStreaming(String relayUrl, String streamKey) async {
    final stream = await _capture();
    if (stream == null) return false;
    final ws = web.WebSocket(relayUrl);
    final opened = Completer<bool>();
    ws.onopen = (web.Event _) {
      if (!opened.isCompleted) opened.complete(true);
    }.toJS;
    ws.onerror = (web.Event _) {
      if (!opened.isCompleted) opened.complete(false);
    }.toJS;
    ws.onmessage = (web.MessageEvent e) {
      final data = e.data;
      if (data.isA<JSString>()) onStatus?.call((data as JSString).toDart);
    }.toJS;
    final ok = await opened.future;
    if (!ok) {
      _stopTracks();
      return false;
    }
    ws.send('{"type":"start","streamKey":"$streamKey"}'.toJS);
    final rec = _makeRecorder(stream);
    rec.ondataavailable = (web.BlobEvent event) {
      if (event.data.size > 0 && ws.readyState == web.WebSocket.OPEN) {
        event.data.arrayBuffer().toDart.then((buf) {
          if (ws.readyState == web.WebSocket.OPEN) ws.send(buf);
        });
      }
    }.toJS;
    rec.onstop = (web.Event _) {
      _stopTracks();
      if (ws.readyState == web.WebSocket.OPEN) ws.close();
    }.toJS;
    rec.start(1000); // чанк раз в секунду
    _rec = rec;
    _ws = ws;
    _streaming = true;
    return true;
  }

  /// Останавливает запись/эфир.
  void stop() {
    if (!_recording && !_streaming) return;
    _recording = false;
    _streaming = false;
    _rec?.stop();
    _rec = null;
  }

  /// Освобождает ресурсы.
  void dispose() {
    _stopTracks();
    _ws?.close();
    _ws = null;
    _rec = null;
  }

  // ── Внутреннее ──────────────────────────────────────────────────────────────

  /// Запрашивает захват экрана/вкладки. `null` при отказе/ошибке.
  Future<web.MediaStream?> _capture() async {
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
      return stream;
    } catch (_) {
      return null;
    }
  }

  web.MediaRecorder _makeRecorder(web.MediaStream stream) => web.MediaRecorder(
    stream,
    web.MediaRecorderOptions(mimeType: 'video/webm'),
  );

  void _stopTracks() {
    final tracks = _stream?.getTracks().toDart ?? const [];
    for (final t in tracks) {
      t.stop();
    }
    _stream = null;
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
    // Отзываем object-URL и чистим чанки ОТЛОЖЕННО: скачивание крупного blob'а
    // (запись экрана — мегабайты) стартует асинхронно, и синхронный revoke сразу
    // после click() в части браузеров отзывает URL до чтения данных → пустой/
    // битый файл. 30 с с запасом достаточно, чтобы загрузка началась.
    Timer(const Duration(seconds: 30), () {
      web.URL.revokeObjectURL(url);
      _chunks.clear();
    });
  }
}
