/// achievements_controller.dart — ViewModel достижений (MVVM, ViewModel).
///
/// За что отвечает файл:
///   Хранит прогресс достижений (`{id: AchProgress}`), прогоняет движок
///   ([engine.dart]) по итогам офлайн/онлайн-матчей, начисляет XP за впервые
///   разблокированные и персистит. Чистый Riverpod `Notifier` без UI.
///
/// Совместимость хранилища: старый формат `bd_achievements` был списком id —
/// читается как набор разблокированных.
///
/// Соответствие TS: `src/ui/achievements/engine.ts` + хранилище ачивок.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_controller.dart';
import '../storage/prefs.dart';
import 'achievement.dart';
import 'definitions.dart';
import 'engine.dart';

/// Ключ хранилища прогресса достижений.
const String _key = 'bd_achievements';

/// ViewModel достижений: прогресс по id.
class AchievementsController extends Notifier<Map<String, AchProgress>> {
  @override
  Map<String, AchProgress> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        // Старый формат: список id разблокированных.
        return {
          for (final id in decoded.cast<String>())
            id: const AchProgress(current: 1, unlockedAt: 1),
        };
      }
      return {
        for (final e in (decoded as Map<String, dynamic>).entries)
          e.key: AchProgress.fromJson((e.value as Map).cast<String, dynamic>()),
      };
    } catch (_) {
      return {};
    }
  }

  /// Множество разблокированных id (для UI/синхронизации).
  Set<String> get unlocked => {
    for (final e in state.entries)
      if (e.value.unlocked) e.key,
  };

  void _apply(EngineResult result) {
    state = result.progress;
    ref
        .read(sharedPreferencesProvider)
        .setString(
          _key,
          jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}),
        );
    // Начисляем XP за впервые разблокированные.
    var xp = 0;
    for (final def in result.unlocked) {
      xp += def.rewardXp;
    }
    if (xp > 0) ref.read(profileControllerProvider.notifier).addXp(xp);
  }

  int _now() => DateTime.now().millisecondsSinceEpoch;

  /// Применяет офлайн-партию; возвращает впервые разблокированные ачивки.
  List<AchievementDef> recordMatch(MatchContext ctx) {
    final result = processMatch(state, ctx, _now());
    _apply(result);
    return result.unlocked;
  }

  /// Применяет онлайн-матч; возвращает впервые разблокированные ачивки.
  List<AchievementDef> recordOnlineMatch(Stats stats, OnlineMatchInfo info) {
    final result = processOnlineMatch(state, stats, info, _now());
    _apply(result);
    return result.unlocked;
  }

  /// Объединяет с разблокированными из облака [ids].
  void mergeUnlocked(Set<String> ids) {
    final next = {...state};
    var changed = false;
    for (final id in ids) {
      final before = next[id];
      if (before == null || !before.unlocked) {
        final total = achievementsById[id]?.total ?? 1;
        next[id] = AchProgress(current: total, unlockedAt: _now());
        changed = true;
      }
    }
    if (!changed) return;
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setString(
          _key,
          jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}),
        );
  }

  /// Сбрасывает прогресс достижений.
  void reset() {
    state = {};
    ref.read(sharedPreferencesProvider).remove(_key);
  }
}

/// Провайдер ViewModel достижений.
final achievementsControllerProvider =
    NotifierProvider<AchievementsController, Map<String, AchProgress>>(
      AchievementsController.new,
    );
