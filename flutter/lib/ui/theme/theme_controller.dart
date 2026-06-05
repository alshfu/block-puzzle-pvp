/// theme_controller.dart — ViewModel выбора темы (MVVM, слой ViewModel).
///
/// За что отвечает файл:
///   Хранит текущую тему оформления и команды её смены. Это ViewModel: чистый
///   Riverpod-`Notifier` без `BuildContext`/виджетов. View (экраны) читают
///   состояние через `ref.watch(themeControllerProvider)` и дёргают команды
///   [ThemeController.select]/[ThemeController.cycle]. Персист темы в хранилище
///   подключим в Фазе 4 (сейчас — в памяти, дефолт `neutral`).
///
/// Соответствие TS: логика смены темы из `App.tsx` + `ThemeSwitch.tsx`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_tokens.dart';

/// ViewModel темы: текущее значение [ThemeId] + команды смены.
class ThemeController extends Notifier<ThemeId> {
  @override
  ThemeId build() => ThemeId.neutral;

  /// Устанавливает конкретную тему.
  void select(ThemeId id) => state = id;

  /// Переключает на следующую тему по кругу (порядок [themeOrder]).
  void cycle() {
    final i = themeOrder.indexOf(state);
    state = themeOrder[(i + 1) % themeOrder.length];
  }
}

/// Провайдер ViewModel темы. View подписывается на него для перерисовки.
final themeControllerProvider = NotifierProvider<ThemeController, ThemeId>(
  ThemeController.new,
);
