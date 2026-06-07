/// audio_service.dart — воспроизведение SFX (View/инфраструктурный слой).
///
/// За что отвечает файл:
///   Единственное место, где живёт плагин `audioplayers`. Рендерит звук из
///   [tonesFor]/[sfxClear] в WAV-байты (с кэшем), проигрывает из памяти через
///   небольшой пул плееров (round-robin) — чтобы накладывающиеся эффекты не
///   обрывали друг друга. Уважает настройку звука (`soundOn`) через колбэк.
///
/// Синтез — чистый ([synth.dart], [sfx.dart]); здесь только проигрывание, так
/// что Model остаётся без платформенных зависимостей.
///
/// Соответствие TS: проигрывающая часть `src/ui/audio.ts` (ensureCtx + tone).
library;

import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import 'sfx.dart';
import 'synth.dart';

/// Общая громкость синтеза (как `soundVolume` в TS).
const double _masterVolume = 0.7;

/// Размер пула плееров для наложения коротких эффектов.
const int _poolSize = 4;

/// Сервис воспроизведения звуковых эффектов.
class AudioService {
  /// Включён ли звук сейчас (читается из настроек на каждый вызов).
  final bool Function() isSoundOn;

  /// Кэш отрендеренных WAV-байтов по ключу эффекта.
  final Map<String, Uint8List> _cache = {};

  /// Пул плееров (ленивая инициализация при первом звуке).
  final List<AudioPlayer> _pool = [];

  /// Индекс следующего плеера в пуле.
  int _next = 0;

  /// Освобождён ли сервис.
  bool _disposed = false;

  /// Создаёт сервис; [isSoundOn] — актуальное значение настройки звука.
  AudioService({required this.isSoundOn});

  /// Проигрывает параметр-независимый эффект [sfx].
  void play(Sfx sfx) => _playTones(sfx.name, tonesFor(sfx));

  /// Проигрывает звук очистки [n] линий (восходящий аккорд).
  void playClear(int n) {
    final count = n.clamp(1, 8);
    _playTones('clear_$count', sfxClear(count));
  }

  /// Рендерит (с кэшем по [key]) и проигрывает тоны [tones].
  void _playTones(String key, List<ToneSpec> tones) {
    if (_disposed || !isSoundOn()) return;
    final bytes = _cache.putIfAbsent(
      key,
      () => renderWav(tones, volume: _masterVolume),
    );
    final player = _player();
    // Ошибки воспроизведения (политика автоплея, отсутствие устройства) — глушим.
    player.play(BytesSource(bytes)).catchError((_) {});
  }

  /// Возвращает следующий плеер пула, инициализируя пул при первом вызове.
  AudioPlayer _player() {
    if (_pool.isEmpty) {
      for (int i = 0; i < _poolSize; i++) {
        _pool.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      }
    }
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    return p;
  }

  /// Останавливает и освобождает плееры.
  void dispose() {
    _disposed = true;
    for (final p in _pool) {
      p.dispose();
    }
    _pool.clear();
  }
}

/// Провайдер сервиса звука. Читает `soundOn` из настроек при каждом эффекте.
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService(
    isSoundOn: () => ref.read(settingsControllerProvider).soundOn,
  );
  ref.onDispose(service.dispose);
  return service;
});
