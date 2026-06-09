/// firebase_options.dart — параметры Firebase по платформам (Model/конфиг).
///
/// За что отвечает файл:
///   Отдаёт [FirebaseOptions] для текущей платформы. Сейчас сконфигурирован
///   только **web** (миграция web-first) — значения из консоли проекта
///   `blockduel-web`. Нативные платформы (Android/iOS/macOS) бросают
///   [UnsupportedError] до отдельной настройки (`flutterfire configure`).
///
/// Аналог автогенерации `flutterfire configure`, но заполнен вручную (без CLI).
/// apiKey web-приложения Firebase публичен (уходит в клиент; доступ ограничен
/// Firestore-правилами) — это не секрет.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

/// Параметры Firebase по платформам.
class DefaultFirebaseOptions {
  /// Опции для текущей платформы (пока только web).
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Firebase для ${defaultTargetPlatform.name} ещё не сконфигурирован — '
      'добавь платформу через flutterfire configure. Сейчас поддержан web.',
    );
  }

  /// Конфигурация web-приложения проекта `blockduel-web`.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAlqPb9Nzg82-oelVQdTADZFrXEZL9pF7o',
    authDomain: 'blockduel-web.firebaseapp.com',
    projectId: 'blockduel-web',
    storageBucket: 'blockduel-web.firebasestorage.app',
    messagingSenderId: '585493330974',
    appId: '1:585493330974:web:b44d6bc13832c7faee420f',
    measurementId: 'G-71CVYVT2GX',
  );
}
