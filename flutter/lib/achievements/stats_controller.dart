/// stats_controller.dart — ViewModel накопительной статистики (MVVM).
///
/// За что отвечает файл:
///   Хранит и обновляет накопительную [Stats] (для достижений): по итогам
///   офлайн-партий и онлайн-матчей наращивает счётчики, серии, очистки. Чистый
///   Riverpod `Notifier` с персистом в [SharedPreferences].
///
/// Соответствие TS: `src/ui/storage/stats.ts` (applyMatch/applyOnlineMatch).
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs.dart';
import 'achievement.dart';

/// ViewModel накопительной статистики.
class StatsController extends Notifier<Stats> {
  @override
  Stats build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(PrefKeys.stats);
    if (raw == null) return Stats.initial;
    try {
      return Stats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Stats.initial;
    }
  }

  void _persist() {
    ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.stats, jsonEncode(state.toJson()));
  }

  /// Наращивает статистику по офлайн-партии и возвращает её снимок ПОСЛЕ.
  /// [winner]: 0 (ты)/1/-1; [matchClears]/[maxMulti] — очистки игрока 0 за матч;
  /// [bestScore] — финальный счёт игрока 0.
  Stats recordOffline({
    required int winner,
    required int matchClears,
    required int maxMulti,
    required int bestScore,
  }) {
    final won = winner == 0;
    final streak = won ? state.currentWinStreak + 1 : 0;
    state = state.copyWith(
      games: state.games + 1,
      wins: state.wins + (won ? 1 : 0),
      losses: state.losses + (winner == 1 ? 1 : 0),
      draws: state.draws + (winner == -1 ? 1 : 0),
      totalClears: state.totalClears + matchClears,
      maxMultiClear: math.max(state.maxMultiClear, maxMulti),
      bestScore: math.max(state.bestScore, bestScore),
      currentWinStreak: streak,
      bestWinStreak: math.max(state.bestWinStreak, streak),
    );
    _persist();
    return state;
  }

  /// Наращивает статистику по онлайн-матчу и возвращает снимок ПОСЛЕ.
  Stats recordOnline({
    required bool won,
    required bool drew,
    required int matchClears,
    required int perfects,
    required String themeId,
  }) {
    final lost = !won && !drew;
    final winStreak = won ? state.onlineCurrentWinStreak + 1 : 0;
    final noLoss = lost ? 0 : state.onlineCurrentNoLossStreak + 1;
    final themes = state.onlineThemesPlayed.contains(themeId)
        ? state.onlineThemesPlayed
        : [...state.onlineThemesPlayed, themeId];
    state = state.copyWith(
      onlineGames: state.onlineGames + 1,
      onlineWins: state.onlineWins + (won ? 1 : 0),
      onlineLosses: state.onlineLosses + (lost ? 1 : 0),
      onlineDraws: state.onlineDraws + (drew ? 1 : 0),
      onlineCurrentWinStreak: winStreak,
      onlineBestWinStreak: math.max(state.onlineBestWinStreak, winStreak),
      onlineCurrentNoLossStreak: noLoss,
      onlineTotalClears: state.onlineTotalClears + matchClears,
      onlineTotalPerfects: state.onlineTotalPerfects + perfects,
      onlineThemesPlayed: themes,
    );
    _persist();
    return state;
  }

  /// Сбрасывает статистику (сброс прогресса).
  void reset() {
    state = Stats.initial;
    ref.read(sharedPreferencesProvider).remove(PrefKeys.stats);
  }
}

/// Провайдер ViewModel статистики.
final statsControllerProvider = NotifierProvider<StatsController, Stats>(
  StatsController.new,
);
