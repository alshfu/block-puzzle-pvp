/// achievements_controller.dart — ViewModel достижений (MVVM, ViewModel).
///
/// За что отвечает файл:
///   Хранит множество разблокированных id, загружает/сохраняет его в хранилище и
///   пересчитывает достижения по текущей статистике профиля ([evaluate]).
///   Чистый Riverpod `Notifier` без UI. Движок оценки — здесь (а не во View).
///
/// Соответствие TS: `src/ui/achievements/engine.ts`.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile.dart';
import '../profile/profile_controller.dart';
import '../storage/prefs.dart';
import 'achievement.dart';
import 'definitions.dart';

/// Ключ хранилища для разблокированных достижений.
const String _unlockedKey = 'bd_achievements';

/// ViewModel достижений: множество разблокированных id.
class AchievementsController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_unlockedKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  /// Снимок статистики из профиля для оценки условий.
  AchievementStats _statsFrom(Profile p) => AchievementStats(
    gamesPlayed: p.gamesPlayed,
    wins: p.wins,
    level: p.level,
    coins: p.coins,
    xp: p.xp,
  );

  /// Пересчитывает достижения по текущему профилю: разблокирует выполненные и
  /// сохраняет. Возвращает список ВНОВЬ разблокированных (для тостов).
  List<Achievement> evaluate() {
    final stats = _statsFrom(ref.read(profileControllerProvider));
    final unlocked = {...state};
    final fresh = <Achievement>[];
    for (final def in achievementDefinitions) {
      if (!unlocked.contains(def.id) && def.isUnlocked(stats)) {
        unlocked.add(def.id);
        fresh.add(def);
      }
    }
    if (fresh.isNotEmpty) {
      state = unlocked;
      ref
          .read(sharedPreferencesProvider)
          .setString(_unlockedKey, jsonEncode(unlocked.toList()));
    }
    return fresh;
  }

  /// Объединяет текущее множество с [ids] (например, из облака) и сохраняет.
  void mergeUnlocked(Set<String> ids) {
    final merged = {...state, ...ids};
    if (merged.length == state.length) return;
    state = merged;
    ref
        .read(sharedPreferencesProvider)
        .setString(_unlockedKey, jsonEncode(merged.toList()));
  }
}

/// Провайдер ViewModel достижений.
final achievementsControllerProvider =
    NotifierProvider<AchievementsController, Set<String>>(
      AchievementsController.new,
    );
