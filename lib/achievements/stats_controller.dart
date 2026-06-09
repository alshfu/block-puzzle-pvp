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
  ///
  /// Порт `applyOnlineMatchToStats` (`src/ui/storage/stats.ts`): кроме общих
  /// счётчиков ведёт карту соперников (уникальные/постоянный соперник/серия
  /// реваншей), дни подряд (через [today] = `YYYY-MM-DD`, передаётся снаружи —
  /// без `DateTime.now()` внутри, ядро/Model остаётся детерминированным) и
  /// «богатые» max-метрики (комбо/мульти-клир/длина матча).
  ///
  /// [today] — текущая дата клиента; [opponentId] — стабильный id соперника;
  /// [scoreGap] — мой перевес при победе; [turnCount] — число ходов в матче.
  Stats recordOnline({
    required bool won,
    required bool drew,
    required int matchClears,
    required int perfects,
    required int maxMultiClear,
    required int bestCombo,
    required int turnCount,
    required String themeId,
    required String opponentId,
    required String today,
    String opponentNick = '',
  }) {
    final lost = !won && !drew;
    final winStreak = won ? state.onlineCurrentWinStreak + 1 : 0;
    final noLoss = lost ? 0 : state.onlineCurrentNoLossStreak + 1;
    final themes = state.onlineThemesPlayed.contains(themeId)
        ? state.onlineThemesPlayed
        : [...state.onlineThemesPlayed, themeId];

    // Соперник: запись до матча → обновлённая.
    final prevOp = state.onlineOpponents[opponentId];
    final isNewOpponent = prevOp == null;
    final op = prevOp ?? const OnlineOpponentRecord();
    final updatedOp = OnlineOpponentRecord(
      count: op.count + 1,
      wins: op.wins + (won ? 1 : 0),
      lastResult: won ? 'win' : (drew ? 'draw' : 'loss'),
      nick: opponentNick.isNotEmpty ? opponentNick : op.nick,
    );
    final opponents = {...state.onlineOpponents, opponentId: updatedOp};

    // Серия реваншей: подряд побед против того же соперника (приближение TS —
    // если в прошлый раз с ним тоже выиграли, берём накопленные победы).
    var rematchStreak = state.onlineMaxRematchWinStreak;
    if (won && !isNewOpponent) {
      rematchStreak = math.max(
        rematchStreak,
        op.lastResult == 'win' ? updatedOp.wins : 1,
      );
    }

    // Дни подряд: сравниваем today с датой последнего матча.
    var consecutiveDays = state.onlineConsecutiveDays;
    var lastPlayed = state.onlineLastPlayedDate;
    if (today != state.onlineLastPlayedDate) {
      if (state.onlineLastPlayedDate.isEmpty) {
        consecutiveDays = 1;
      } else {
        final prevD = DateTime.tryParse(state.onlineLastPlayedDate);
        final todayD = DateTime.tryParse(today);
        final diff = (prevD != null && todayD != null)
            ? todayD.difference(prevD).inDays
            : 0;
        consecutiveDays = diff == 1 ? state.onlineConsecutiveDays + 1 : 1;
      }
      lastPlayed = today;
    }

    state = state.copyWith(
      onlineGames: state.onlineGames + 1,
      onlineWins: state.onlineWins + (won ? 1 : 0),
      onlineLosses: state.onlineLosses + (lost ? 1 : 0),
      onlineDraws: state.onlineDraws + (drew ? 1 : 0),
      onlineCurrentWinStreak: winStreak,
      onlineBestWinStreak: math.max(state.onlineBestWinStreak, winStreak),
      onlineCurrentNoLossStreak: noLoss,
      onlineBestNoLossStreak: math.max(state.onlineBestNoLossStreak, noLoss),
      onlineTotalClears: state.onlineTotalClears + matchClears,
      onlineTotalPerfects: state.onlineTotalPerfects + perfects,
      onlineMaxMultiClear: math.max(state.onlineMaxMultiClear, maxMultiClear),
      onlineBestCombo: math.max(state.onlineBestCombo, bestCombo),
      onlineLongestMatchTurns: math.max(
        state.onlineLongestMatchTurns,
        turnCount,
      ),
      onlineThemesPlayed: themes,
      onlineOpponents: opponents,
      onlineUniqueOpponents:
          state.onlineUniqueOpponents + (isNewOpponent ? 1 : 0),
      onlineMostVsSingleOpponent: math.max(
        state.onlineMostVsSingleOpponent,
        updatedOp.count,
      ),
      onlineMaxRematchWinStreak: rematchStreak,
      onlineConsecutiveDays: consecutiveDays,
      onlineMaxConsecutiveDays: math.max(
        state.onlineMaxConsecutiveDays,
        consecutiveDays,
      ),
      onlineLastPlayedDate: lastPlayed,
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
