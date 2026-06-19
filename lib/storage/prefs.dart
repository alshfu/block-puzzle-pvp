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

  /// JSON накопительной статистики (для достижений).
  static const String stats = 'bd_stats';

  /// JSON состояния скинов (разблокированные + надетый).
  static const String skins = 'bd_skins';

  /// JSON инвентаря power-ups (id → количество).
  static const String inventory = 'bd_inventory';

  /// Флаг выданной награды за обучение (`'1'` — уже выдана).
  static const String tutorialDone = 'bd_tutorial_done';

  /// Флаг режима разработчика (`'1'` — включён скрытый pilot).
  static const String pilotDev = 'bd_pilot';

  /// JSON рекордов режима «Память: соло» (уровень сложности → лучший счёт).
  static const String memorySoloBest = 'bd_memory_solo_best';

  /// JSON состояния кастомных тем (список + надетая) — конструктор тем § 10.2.
  static const String customThemes = 'bd_custom_themes';

  /// Флаг разблокировки конструктора тем (`'1'` — куплен за кристаллы).
  static const String themeBuilderUnlocked = 'bd_theme_builder';

  /// JSON прогресса сезонного пропуска (§ 10.4): xp + premium + claimed.
  static const String seasonPass = 'bd_season_pass';

  /// JSON opt-in push-уведомлений (§ 11.2): мастер + категории.
  static const String notifications = 'bd_notifications';

  /// JSON состояния запроса оценки приложения (§ 11.5): счётчик + статус.
  static const String rating = 'bd_rating';
}
