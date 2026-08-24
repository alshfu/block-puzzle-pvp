/// custom_themes_controller.dart — ViewModel кастомных тем (§ 10.2, ViewModel).
///
/// За что отвечает файл:
///   Хранит список пользовательских тем, надетую тему и флаг разблокировки
///   конструктора (покупка за кристаллы), персистит всё в SharedPreferences.
///   Команды: создать/сохранить/удалить/надеть/снять/разблокировать. Поверх
///   этого [activeThemeProvider] отдаёт активные токены [BlockDuelTheme] —
///   надетую кастомную либо текущий пресет — а `app.dart` строит из них тему.
///
/// Соответствие ROADMAP: § 10.2 (конструктор тем; маркетплейс/синк — 🔒).
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/prefs.dart';
import '../design_tokens.dart';
import 'custom_theme.dart';
import 'theme_controller.dart';

/// Стоимость разблокировки конструктора тем (кристаллы, § 10.2).
const int themeBuilderUnlockPrice = 5000;

/// Снимок состояния кастомных тем.
class CustomThemesState {
  /// Сохранённые пользовательские темы.
  final List<CustomTheme> themes;

  /// Id надетой кастомной темы (или `null` — активен пресет).
  final String? equippedId;

  /// Разблокирован ли конструктор (куплен за кристаллы).
  final bool unlocked;

  /// Создаёт снимок.
  const CustomThemesState({
    required this.themes,
    required this.equippedId,
    required this.unlocked,
  });

  /// Надетая кастомная тема (или `null`).
  CustomTheme? get equipped {
    if (equippedId == null) return null;
    for (final t in themes) {
      if (t.id == equippedId) return t;
    }
    return null;
  }

  /// Копия с изменениями (с возможностью обнулить надетую).
  CustomThemesState copyWith({
    List<CustomTheme>? themes,
    String? equippedId,
    bool clearEquipped = false,
    bool? unlocked,
  }) => CustomThemesState(
    themes: themes ?? this.themes,
    equippedId: clearEquipped ? null : (equippedId ?? this.equippedId),
    unlocked: unlocked ?? this.unlocked,
  );
}

/// ViewModel кастомных тем.
class CustomThemesController extends Notifier<CustomThemesState> {
  @override
  CustomThemesState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final unlocked = prefs.getString(PrefKeys.themeBuilderUnlocked) == '1';
    final raw = prefs.getString(PrefKeys.customThemes);
    if (raw == null) {
      return CustomThemesState(
        themes: const [],
        equippedId: null,
        unlocked: unlocked,
      );
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      // Пропускаем битые темы поштучно, а не роняем весь список: одна
      // повреждённая запись не должна стирать остальные пользовательские темы.
      final themes = <CustomTheme>[];
      for (final t in (json['themes'] as List? ?? [])) {
        try {
          themes.add(CustomTheme.fromJson(t as Map<String, dynamic>));
        } catch (_) {
          // битая тема — пропускаем
        }
      }
      return CustomThemesState(
        themes: themes,
        equippedId: json['equipped'] as String?,
        unlocked: unlocked,
      );
    } catch (_) {
      return CustomThemesState(
        themes: const [],
        equippedId: null,
        unlocked: unlocked,
      );
    }
  }

  void _persist() {
    ref.read(sharedPreferencesProvider).setString(
          PrefKeys.customThemes,
          jsonEncode({
            'themes': [for (final t in state.themes) t.toJson()],
            'equipped': state.equippedId,
          }),
        );
  }

  /// Помечает конструктор как разблокированный (вызывающий уже списал кристаллы).
  void unlock() {
    ref.read(sharedPreferencesProvider).setString(
          PrefKeys.themeBuilderUnlocked,
          '1',
        );
    state = state.copyWith(unlocked: true);
  }

  /// Свободный id для новой темы.
  String nextId() => 'custom_${DateTime.now().millisecondsSinceEpoch}';

  /// Сохраняет тему (добавляет или заменяет по id) и надевает её.
  void save(CustomTheme theme) {
    final list = [
      for (final t in state.themes)
        if (t.id != theme.id) t,
      theme,
    ];
    state = state.copyWith(themes: list, equippedId: theme.id);
    _persist();
  }

  /// Удаляет тему [id] (если была надета — снимает).
  void delete(String id) {
    final list = [for (final t in state.themes) if (t.id != id) t];
    final clear = state.equippedId == id;
    state = state.copyWith(themes: list, clearEquipped: clear);
    _persist();
  }

  /// Надевает кастомную тему [id].
  void equip(String id) {
    state = state.copyWith(equippedId: id);
    _persist();
  }

  /// Снимает кастомную тему (активным становится пресет).
  void unequip() {
    if (state.equippedId == null) return;
    state = state.copyWith(clearEquipped: true);
    _persist();
  }
}

/// Провайдер ViewModel кастомных тем.
final customThemesControllerProvider =
    NotifierProvider<CustomThemesController, CustomThemesState>(
  CustomThemesController.new,
);

/// Активные токены темы: надетая кастомная (если есть) либо текущий пресет.
/// `app.dart` строит `ThemeData` именно из них.
final activeThemeProvider = Provider<BlockDuelTheme>((ref) {
  final custom = ref.watch(customThemesControllerProvider).equipped;
  if (custom != null) return custom.toTokens();
  return blockDuelThemes[ref.watch(themeControllerProvider)]!;
});
