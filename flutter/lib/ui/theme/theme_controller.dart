/// theme_controller.dart — ViewModel выбора темы (MVVM, слой ViewModel).
///
/// За что отвечает файл:
///   Хранит текущую тему оформления, загружает её из локального хранилища и
///   сохраняет при смене. Это ViewModel: чистый Riverpod-`Notifier` без
///   `BuildContext`. View читают `ref.watch(themeControllerProvider)` и зовут
///   команды [ThemeController.select]/[ThemeController.cycle].
///
/// Соответствие TS: смена темы из `App.tsx` + `ThemeSwitch.tsx` (+ persist
/// через `THEME_STORAGE_KEY`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/prefs.dart';
import '../design_tokens.dart';

/// ViewModel темы: текущее значение [ThemeId] + команды смены с персистом.
class ThemeController extends Notifier<ThemeId> {
  @override
  ThemeId build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(PrefKeys.theme);
    return ThemeId.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => ThemeId.neutral,
    );
  }

  /// Устанавливает конкретную тему и сохраняет выбор.
  void select(ThemeId id) {
    state = id;
    ref.read(sharedPreferencesProvider).setString(PrefKeys.theme, id.name);
  }

  /// Переключает на следующую тему по кругу (порядок [themeOrder]).
  void cycle() {
    final i = themeOrder.indexOf(state);
    select(themeOrder[(i + 1) % themeOrder.length]);
  }
}

/// Провайдер ViewModel темы. View подписывается на него для перерисовки.
final themeControllerProvider = NotifierProvider<ThemeController, ThemeId>(
  ThemeController.new,
);
