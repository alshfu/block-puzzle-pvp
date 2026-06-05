/// prefs.dart — доступ к локальному хранилищу (Model/repository-слой).
///
/// За что отвечает файл:
///   Предоставляет общий экземпляр [SharedPreferences] через Riverpod-провайдер
///   (синхронный доступ для ViewModel) и централизует строковые ключи. Сам
///   экземпляр грузится асинхронно в `main()` и подменяется в `ProviderScope`,
///   чтобы контроллеры читали/писали настройки синхронно в `build`.
///
/// Соответствие TS: `src/ui/storage/storage.ts` (обёртка над localStorage).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Провайдер [SharedPreferences]. Должен быть переопределён в `main()` через
/// `overrideWithValue(prefs)` после `SharedPreferences.getInstance()`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider должен быть переопределён в main()',
  ),
);

/// Ключи хранилища (совместимы по смыслу с TS-версией, префикс `bd_`).
abstract final class PrefKeys {
  /// Выбранная тема оформления.
  static const String theme = 'bd_theme';

  /// JSON профиля игрока.
  static const String profile = 'bd_profile';

  /// JSON пользовательских настроек.
  static const String settings = 'bd_settings';
}
