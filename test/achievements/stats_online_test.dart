/// stats_online_test.dart — тесты накопления онлайн-статистики (Фаза 3b).
///
/// За что отвечает файл:
///   Проверяет [StatsController.recordOnline] (порт `applyOnlineMatchToStats`):
///   общие счётчики и серии, карту соперников (уникальные / постоянный соперник
///   / серия реваншей), подсчёт дней подряд по переданной дате, темы и
///   «богатые» max-метрики; плюс round-trip [Stats] с новыми полями.
library;

import 'package:block_duel/achievements/achievement.dart';
import 'package:block_duel/achievements/stats_controller.dart';
import 'package:block_duel/storage/prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Контейнер с mock-хранилищем и авто-очисткой.
Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('recordOnline — общие счётчики и серии', () {
    test('победа наращивает wins/streak/no-loss и темы', () async {
      final c = await _container();
      final ctrl = c.read(statsControllerProvider.notifier);
      final s = ctrl.recordOnline(
        won: true,
        drew: false,
        matchClears: 3,
        perfects: 1,
        maxMultiClear: 4,
        bestCombo: 5,
        turnCount: 20,
        themeId: 'candy',
        opponentId: 'op-1',
        today: '2026-06-09',
      );
      expect(s.onlineGames, 1);
      expect(s.onlineWins, 1);
      expect(s.onlineCurrentWinStreak, 1);
      expect(s.onlineBestWinStreak, 1);
      expect(s.onlineCurrentNoLossStreak, 1);
      expect(s.onlineBestNoLossStreak, 1);
      expect(s.onlineTotalClears, 3);
      expect(s.onlineTotalPerfects, 1);
      expect(s.onlineMaxMultiClear, 4);
      expect(s.onlineBestCombo, 5);
      expect(s.onlineLongestMatchTurns, 20);
      expect(s.onlineThemesPlayed, ['candy']);
      expect(s.onlineUniqueOpponents, 1);
    });

    test('поражение обнуляет win/no-loss стрики, но max сохраняются', () async {
      final c = await _container();
      final ctrl = c.read(statsControllerProvider.notifier);
      ctrl.recordOnline(
        won: true,
        drew: false,
        matchClears: 1,
        perfects: 0,
        maxMultiClear: 2,
        bestCombo: 3,
        turnCount: 10,
        themeId: 'neutral',
        opponentId: 'op-1',
        today: '2026-06-09',
      );
      final s = ctrl.recordOnline(
        won: false,
        drew: false,
        matchClears: 0,
        perfects: 0,
        maxMultiClear: 0,
        bestCombo: 0,
        turnCount: 5,
        themeId: 'neutral',
        opponentId: 'op-1',
        today: '2026-06-09',
      );
      expect(s.onlineLosses, 1);
      expect(s.onlineCurrentWinStreak, 0);
      expect(s.onlineCurrentNoLossStreak, 0);
      expect(s.onlineBestWinStreak, 1);
      expect(s.onlineBestNoLossStreak, 1);
      expect(s.onlineMaxMultiClear, 2); // max не падает
    });

    test('ничья держит no-loss стрик, но не win-стрик', () async {
      final c = await _container();
      final ctrl = c.read(statsControllerProvider.notifier);
      ctrl.recordOnline(
        won: true,
        drew: false,
        matchClears: 0,
        perfects: 0,
        maxMultiClear: 0,
        bestCombo: 0,
        turnCount: 8,
        themeId: 'night',
        opponentId: 'op-1',
        today: '2026-06-09',
      );
      final s = ctrl.recordOnline(
        won: false,
        drew: true,
        matchClears: 0,
        perfects: 0,
        maxMultiClear: 0,
        bestCombo: 0,
        turnCount: 30,
        themeId: 'night',
        opponentId: 'op-2',
        today: '2026-06-09',
      );
      expect(s.onlineDraws, 1);
      expect(s.onlineCurrentWinStreak, 0);
      expect(s.onlineCurrentNoLossStreak, 2); // победа + ничья
    });
  });

  group('recordOnline — соперники и реванши', () {
    test('уникальные и постоянный соперник', () async {
      final c = await _container();
      final ctrl = c.read(statsControllerProvider.notifier);
      for (var i = 0; i < 3; i++) {
        ctrl.recordOnline(
          won: true,
          drew: false,
          matchClears: 0,
          perfects: 0,
          maxMultiClear: 0,
          bestCombo: 0,
          turnCount: 10,
          themeId: 'neutral',
          opponentId: 'rival', // тот же соперник
          today: '2026-06-09',
        );
      }
      final s = ctrl.recordOnline(
        won: true,
        drew: false,
        matchClears: 0,
        perfects: 0,
        maxMultiClear: 0,
        bestCombo: 0,
        turnCount: 10,
        themeId: 'neutral',
        opponentId: 'newbie', // новый соперник
        today: '2026-06-09',
      );
      expect(s.onlineUniqueOpponents, 2);
      expect(s.onlineMostVsSingleOpponent, 3); // против 'rival'
      expect(s.onlineOpponents['rival']!.count, 3);
      expect(s.onlineOpponents['rival']!.wins, 3);
    });

    test('ник соперника сохраняется в записи', () async {
      final c = await _container();
      final ctrl = c.read(statsControllerProvider.notifier);
      final s = ctrl.recordOnline(
        won: true,
        drew: false,
        matchClears: 0,
        perfects: 0,
        maxMultiClear: 0,
        bestCombo: 0,
        turnCount: 10,
        themeId: 'neutral',
        opponentId: 'op-x',
        opponentNick: 'Алиса',
        today: '2026-06-09',
      );
      expect(s.onlineOpponents['op-x']!.nick, 'Алиса');
    });

    test('серия реваншей растёт при победах подряд над одним', () async {
      final c = await _container();
      final ctrl = c.read(statsControllerProvider.notifier);
      Stats s = const Stats();
      for (var i = 0; i < 3; i++) {
        s = ctrl.recordOnline(
          won: true,
          drew: false,
          matchClears: 0,
          perfects: 0,
          maxMultiClear: 0,
          bestCombo: 0,
          turnCount: 10,
          themeId: 'neutral',
          opponentId: 'rival',
          today: '2026-06-09',
        );
      }
      expect(s.onlineMaxRematchWinStreak, greaterThanOrEqualTo(2));
    });
  });

  group('recordOnline — дни подряд', () {
    test('последовательные дни наращивают серию, разрыв сбрасывает', () async {
      final c = await _container();
      final ctrl = c.read(statsControllerProvider.notifier);
      Stats day(String d) => ctrl.recordOnline(
        won: true,
        drew: false,
        matchClears: 0,
        perfects: 0,
        maxMultiClear: 0,
        bestCombo: 0,
        turnCount: 10,
        themeId: 'neutral',
        opponentId: 'op',
        today: d,
      );
      expect(day('2026-06-07').onlineConsecutiveDays, 1);
      expect(day('2026-06-08').onlineConsecutiveDays, 2);
      // тот же день — серия не меняется.
      expect(day('2026-06-08').onlineConsecutiveDays, 2);
      // разрыв в 2 дня — сброс на 1.
      final s = day('2026-06-11');
      expect(s.onlineConsecutiveDays, 1);
      expect(s.onlineMaxConsecutiveDays, 2);
    });
  });

  group('сериализация новых полей', () {
    test('Stats round-trip с соперниками и датой', () {
      const s = Stats(
        onlineGames: 4,
        onlineMaxRematchWinStreak: 3,
        onlineLastPlayedDate: '2026-06-09',
        onlineMaxConsecutiveDays: 5,
        onlineOpponents: {
          'op-1': OnlineOpponentRecord(count: 2, wins: 1, lastResult: 'win'),
        },
      );
      final back = Stats.fromJson(s.toJson());
      expect(back.onlineGames, 4);
      expect(back.onlineMaxRematchWinStreak, 3);
      expect(back.onlineLastPlayedDate, '2026-06-09');
      expect(back.onlineMaxConsecutiveDays, 5);
      expect(back.onlineOpponents['op-1']!.count, 2);
      expect(back.onlineOpponents['op-1']!.lastResult, 'win');
    });
  });
}
