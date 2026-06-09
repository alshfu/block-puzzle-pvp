/// ts_import_web.dart — импорт прогресса TS-версии из localStorage (web).
///
/// За что отвечает файл:
///   При первом запуске Flutter-web (флаг [_doneKey] не выставлен) копирует
///   значения ключей `bd_*`, которые старая TS-версия писала прямо в
///   `localStorage`, в Flutter-хранилище (shared_preferences хранит web-данные
///   под префиксом `flutter.`, поэтому само по себе оно TS-данные не видит).
///
///   Защитно: НЕ затирает уже существующие Flutter-значения; запускается один
///   раз. Возможное несовпадение JSON-формы безопасно — все контроллеры
///   читают эти ключи через try/catch и откатываются к дефолтам.
library;

// Намеренный web-only шим миграции: dart:html здесь оправдан и изолирован
// (файл подключается только под web через условный экспорт ts_import.dart).
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:shared_preferences/shared_preferences.dart';

/// Флаг «миграция выполнена» — чтобы импорт прошёл ровно один раз.
const String _doneKey = 'bd_ts_import_done';

/// Ключи TS-версии для переноса (логические — те же, что в Flutter PrefKeys).
const List<String> _keys = [
  'bd_profile',
  'bd_stats',
  'bd_settings',
  'bd_achievements',
  'bd_theme',
  'bd_skins',
  'bd_inventory',
];

/// Переносит локальные TS-данные в Flutter-хранилище (один раз, web-only).
Future<void> importLegacyTsData(SharedPreferences prefs) async {
  if (prefs.getBool(_doneKey) ?? false) return;
  try {
    final ls = html.window.localStorage;
    for (final key in _keys) {
      final value = ls[key];
      if (value == null) continue;
      // Не затираем данные, уже записанные Flutter-версией.
      if (prefs.containsKey(key)) continue;
      await prefs.setString(key, value);
    }
  } catch (_) {
    // localStorage недоступен / приватный режим — пропускаем миграцию.
  }
  await prefs.setBool(_doneKey, true);
}
