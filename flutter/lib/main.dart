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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'storage/prefs.dart';

/// З   апускает приложение: грузит хранилище и поднимает DI-корень MVVM.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BlockDuelApp(),
    ),
  );
}
