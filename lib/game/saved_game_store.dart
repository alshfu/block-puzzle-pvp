/// saved_game_store.dart — хранилище сохранёнки (Model/repository-слой).
///
/// За что отвечает файл:
///   Читает/пишет/очищает единственный слот сохранённой партии в
///   [SharedPreferences] (JSON). ViewModel вызывает его для авто-сохранения и
///   resume; View — для показа карточки «Продолжить».
///
/// Соответствие TS: `src/ui/storage/saveGame.ts`.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/prefs.dart';
import 'saved_game.dart';

/// Ключ слота сохранённой партии.
const String _saveKey = 'bd_savegame';

/// Хранилище одной сохранённой партии.
class SavedGameStore {
  /// Хранилище ключ-значение.
  final SharedPreferences _prefs;

  /// Создаёт хранилище поверх [_prefs].
  const SavedGameStore(this._prefs);

  /// Загружает сохранённую партию или `null`, если её нет/повреждена.
  SavedGame? load() {
    final raw = _prefs.getString(_saveKey);
    if (raw == null) return null;
    try {
      return SavedGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Сохраняет партию [game].
  void save(SavedGame game) {
    _prefs.setString(_saveKey, jsonEncode(game.toJson()));
  }

  /// Удаляет сохранённую партию (например, по завершении).
  void clear() {
    _prefs.remove(_saveKey);
  }
}

/// Провайдер хранилища сохранёнки.
final savedGameStoreProvider = Provider<SavedGameStore>(
  (ref) => SavedGameStore(ref.watch(sharedPreferencesProvider)),
);
