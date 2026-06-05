/// settings_controller.dart — ViewModel настроек (MVVM, слой ViewModel).
///
/// За что отвечает файл:
///   Загружает настройки из хранилища, отдаёт их View и сохраняет изменения.
///   Чистый Riverpod `Notifier` без UI.
///
/// Соответствие TS: логика чтения/записи настроек из `storage/settings.ts`.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs.dart';
import 'settings.dart';

/// ViewModel пользовательских настроек.
class SettingsController extends Notifier<Settings> {
  @override
  Settings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(PrefKeys.settings);
    if (raw == null) return Settings.initial;
    try {
      return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Settings.initial;
    }
  }

  /// Сохраняет текущие настройки.
  void _persist() {
    ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.settings, jsonEncode(state.toJson()));
  }

  /// Переключает звуковые эффекты.
  void toggleSound() {
    state = state.copyWith(soundOn: !state.soundOn);
    _persist();
  }

  /// Переключает фоновую музыку.
  void toggleMusic() {
    state = state.copyWith(musicOn: !state.musicOn);
    _persist();
  }

  /// Переключает уменьшение анимаций.
  void toggleReduceMotion() {
    state = state.copyWith(reduceMotion: !state.reduceMotion);
    _persist();
  }
}

/// Провайдер ViewModel настроек.
final settingsControllerProvider =
    NotifierProvider<SettingsController, Settings>(SettingsController.new);
