/// main.dart — точка входа Flutter-приложения BlockDuel 9×9 (Dart-порт).
///
/// За что отвечает файл:
///   Bootstrap приложения: инициализирует биндинги, загружает
///   [SharedPreferences] (чтобы ViewModel читали тему/настройки/профиль
///   синхронно) и запускает корневой [BlockDuelApp] под Riverpod
///   `ProviderScope` с подменённым провайдером хранилища. Вся логика — во
///   View/ViewModel/Model слоях.
///
/// Соответствие TS: `src/main.tsx`.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'storage/prefs.dart';
import 'storage/ts_import.dart';

/// Запускает приложение: грузит хранилище, поднимает Firebase (мягко) и
/// DI-корень MVVM. Сбой инициализации Firebase не валит приложение — авторизация
/// и облачный синк просто остаются недоступными (см. `AuthController`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Cut-over: один раз переносим локальный прогресс старой TS-версии (web-only;
  // на других платформах no-op). До build() ViewModel — чтобы они прочитали.
  await importLegacyTsData(prefs);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Нативная платформа без конфигурации / офлайн — продолжаем без Firebase.
  }
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BlockDuelApp(),
    ),
  );
}
