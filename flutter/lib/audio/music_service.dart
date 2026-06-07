/// music_service.dart — проигрывание фоновой музыки (View/инфраструктура).
///
/// За что отвечает файл:
///   Рендерит цикл трека темы ([renderTrack], с кэшем) и крутит его в петле
///   через `audioplayers` (`ReleaseMode.loop`). Единственное место с плагином;
///   синтез чист ([music.dart], [synth.dart]). Реагирует на настройку музыки и
///   текущую тему через идемпотентный [update].
///
/// Веб-политика автоплея: первый `play()` может быть заблокирован до жеста
/// пользователя — ошибки глушатся, музыка зазвучит после первого взаимодействия.
///
/// Соответствие TS: `music.ts` (setMusicEnabled/setMusicTheme/setMusicVolume).
library;

import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/design_tokens.dart' show ThemeId;
import 'music.dart';

/// Базовый мастер-уровень музыки (как `VOLUME_BASE` в TS).
const double _volumeBase = 0.55;

/// Пользовательский множитель громкости (нет слайдера — фикс, как дефолт TS).
const double _userVolume = 0.5;

/// Сервис фоновой музыки: одна зацикленная тема за раз.
class MusicService {
  /// Плеер петли (создаётся лениво при первом включении).
  AudioPlayer? _player;

  /// Кэш отрендеренных треков по теме.
  final Map<ThemeId, Uint8List> _cache = {};

  /// Включена ли музыка.
  bool _enabled = false;

  /// Текущая играющая тема (null — ничего не играет).
  ThemeId? _current;

  /// Освобождён ли сервис.
  bool _disposed = false;

  /// Идемпотентно синхронизирует состояние: включённость и тему. Безопасно
  /// звать на каждый build — ничего не делает, если ничего не изменилось.
  void update({required bool enabled, required ThemeId theme}) {
    if (_disposed) return;
    if (enabled == _enabled && (!enabled || theme == _current)) return;
    _enabled = enabled;
    if (!enabled) {
      _player?.stop();
      _current = null;
      return;
    }
    _current = theme;
    _playTheme(theme);
  }

  /// Загружает (с кэшем) и запускает в петле трек темы [theme].
  void _playTheme(ThemeId theme) {
    final bytes = _cache.putIfAbsent(theme, () => renderTrack(tracks[theme]!));
    final player = _ensurePlayer();
    // Сменить источник: стоп + старт нового цикла.
    player.stop();
    player.setVolume(_volumeBase * _userVolume);
    player.play(BytesSource(bytes)).catchError((_) {});
  }

  /// Возвращает плеер, создавая его (с режимом петли) при первом обращении.
  AudioPlayer _ensurePlayer() {
    return _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  }

  /// Останавливает и освобождает плеер.
  void dispose() {
    _disposed = true;
    _player?.dispose();
    _player = null;
  }
}

/// Провайдер сервиса фоновой музыки.
final musicServiceProvider = Provider<MusicService>((ref) {
  final service = MusicService();
  ref.onDispose(service.dispose);
  return service;
});
