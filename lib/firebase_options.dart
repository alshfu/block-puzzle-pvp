/// firebase_options.dart — параметры Firebase по платформам (Model/конфиг).
///
/// За что отвечает файл:
///   Отдаёт [FirebaseOptions] для текущей платформы. Сконфигурированы **web** и
///   **macOS** (значения из консоли проекта `blockduel-web`). Остальные нативные
///   платформы (Android/iOS) пока бросают [UnsupportedError] до отдельной
///   настройки (`flutterfire configure`).
///
/// Аналог автогенерации `flutterfire configure`, но заполнен вручную (без CLI).
/// apiKey Firebase публичен (уходит в клиент; доступ ограничен Firestore-
/// правилами) — это не секрет.
///
/// ⚠️ macOS: поля [macos] с префиксом `REPLACE_ME_` — заглушки. Пока они не
/// заменены реальными значениями из Firebase Console (регистрация macOS-app в
/// проекте `blockduel-web`), [currentPlatform] на macOS бросает понятную ошибку,
/// инициализация Firebase в `main.dart` её гасит, и авторизация остаётся
/// недоступной (без падения). Шаги — см. `MACOS_AUTH_SETUP.md`.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Параметры Firebase по платформам.
class DefaultFirebaseOptions {
  /// Опции для текущей платформы (web + macOS).
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        if (!macosConfigured) {
          throw UnsupportedError(
            'Firebase macOS не сконфигурирован: замени REPLACE_ME-поля в '
            'DefaultFirebaseOptions.macos на значения из Firebase Console '
            '(см. MACOS_AUTH_SETUP.md).',
          );
        }
        return macos;
      default:
        throw UnsupportedError(
          'Firebase для ${defaultTargetPlatform.name} ещё не сконфигурирован — '
          'добавь платформу через flutterfire configure. Поддержаны web/macOS.',
        );
    }
  }

  /// true, когда macOS-конфиг заполнен реальными значениями (не заглушками).
  static bool get macosConfigured => !macos.appId.startsWith('REPLACE_ME');

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

  /// Конфигурация macOS-приложения проекта `blockduel-web`.
  /// Поля проекта (projectId/sender/bucket/bundleId) известны; apiKey и appId —
  /// заглушки `REPLACE_ME_*`: взять из Firebase Console после регистрации
  /// macOS-приложения (bundle id `com.alshfu.blockDuel`). См. MACOS_AUTH_SETUP.md.
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_ME_macos_apiKey',
    appId: 'REPLACE_ME_macos_appId',
    messagingSenderId: '585493330974',
    projectId: 'blockduel-web',
    storageBucket: 'blockduel-web.firebasestorage.app',
    iosBundleId: 'com.alshfu.blockDuel',
  );
}
