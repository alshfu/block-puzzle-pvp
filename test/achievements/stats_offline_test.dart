/// stats_offline_test.dart — тесты офлайн-статистики (StatsController.recordOffline).
///
/// Онлайн-путь покрыт stats_online_test; офлайн (бот/hot-seat/аркада) до
/// 2026-08-24 не тестировался. Покрывает W/L/D-счётчики, серию побед (инкремент
/// при победе, обнуление иначе), max-метрики и персист.
library;

import 'package:block_duel/achievements/achievement.dart';
import 'package:block_duel/achievements/stats_controller.dart';
import 'package:block_duel/storage/prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

Stats _rec(StatsController ctrl, {required int winner, int clears = 0, int maxMulti = 0, int best = 0}) =>
    ctrl.recordOffline(winner: winner, matchClears: clears, maxMulti: maxMulti, bestScore: best);

void main() {
  test('победа: games/wins/streak растут', () async {
    final c = await _container();
    final ctrl = c.read(statsControllerProvider.notifier);
    final s = _rec(ctrl, winner: 0, clears: 3);
    expect(s.games, 1);
    expect(s.wins, 1);
    expect(s.currentWinStreak, 1);
    expect(s.totalClears, 3);
  });

  test('поражение обнуляет серию побед', () async {
    final c = await _container();
    final ctrl = c.read(statsControllerProvider.notifier);
    _rec(ctrl, winner: 0); // streak 1
    _rec(ctrl, winner: 0); // streak 2
    final s = _rec(ctrl, winner: 1); // поражение → streak 0
    expect(s.currentWinStreak, 0);
    expect(s.bestWinStreak, 2); // максимум сохранён
    expect(s.losses, 1);
    expect(s.wins, 2);
  });

  test('ничья считается в draws, серия обнуляется', () async {
    final c = await _container();
    final ctrl = c.read(statsControllerProvider.notifier);
    _rec(ctrl, winner: 0);
    final s = _rec(ctrl, winner: -1);
    expect(s.draws, 1);
    expect(s.currentWinStreak, 0);
  });

  test('max-метрики (maxMultiClear/bestScore) берут максимум', () async {
    final c = await _container();
    final ctrl = c.read(statsControllerProvider.notifier);
    _rec(ctrl, winner: 0, maxMulti: 4, best: 300);
    final s = _rec(ctrl, winner: 1, maxMulti: 2, best: 500);
    expect(s.maxMultiClear, 4); // не уменьшается
    expect(s.bestScore, 500); // растёт
  });

  test('персист: новый контейнер видит накопленное', () async {
    final c = await _container();
    _rec(c.read(statsControllerProvider.notifier), winner: 0, best: 250);
    final prefs = await SharedPreferences.getInstance();
    final c2 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c2.dispose);
    expect(c2.read(statsControllerProvider).bestScore, 250);
  });
}
