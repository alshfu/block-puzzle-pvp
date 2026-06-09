/// daily_test.dart — тесты ежедневных квестов (Фаза 4).
///
/// За что отвечает файл:
///   Проверяет детерминированный выбор квестов по дню, подсчёт прироста метрик
///   и поток прогресс→награда в [DailyController] (с начислением монет в
///   профиль) на mock-хранилище.
library;

import 'package:block_duel/daily/daily.dart';
import 'package:block_duel/daily/daily_controller.dart';
import 'package:block_duel/profile/profile_controller.dart';
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

void main() {
  test('выбор квестов детерминирован по дню и берёт нужное число', () {
    final a = pickQuestsForDay('2026-06-05');
    final b = pickQuestsForDay('2026-06-05');
    final other = pickQuestsForDay('2026-06-06');
    expect(a.length, dailyQuestCount);
    expect(a.map((q) => q.id), b.map((q) => q.id));
    // Разные дни обычно дают другой набор (не строго, но проверим хотя бы id).
    expect(a.map((q) => q.id).toSet().length, dailyQuestCount);
    expect(other.length, dailyQuestCount);
  });

  test('прирост метрики считается верно', () {
    const win = DailyGameEvent(won: true, coinsEarned: 25);
    const loss = DailyGameEvent(won: false, coinsEarned: 5);
    expect(win.deltaFor(DailyMetric.gamesPlayed), 1);
    expect(win.deltaFor(DailyMetric.wins), 1);
    expect(loss.deltaFor(DailyMetric.wins), 0);
    expect(win.deltaFor(DailyMetric.coinsEarned), 25);
  });

  test('recordGame наращивает прогресс, claim начисляет монеты', () async {
    final c = await _container();
    final daily = c.read(dailyControllerProvider.notifier);
    final coinsBefore = c.read(profileControllerProvider).coins;

    // Достаточно много побед с монетами, чтобы выполнить любой из сегодняшних
    // квестов (play_3/5, win_1/3, coins_50).
    for (int i = 0; i < 6; i++) {
      daily.recordGame(const DailyGameEvent(won: true, coinsEarned: 25));
    }

    final state = c.read(dailyControllerProvider);
    // Хотя бы один квест должен быть выполнен.
    final completed = state.questIds.where((id) {
      final q = questById(id)!;
      return (state.progress[id] ?? 0) >= q.target;
    }).toList();
    expect(completed, isNotEmpty);

    // Забираем награды за выполненные — монеты в профиле растут.
    var expectedReward = 0;
    for (final id in completed) {
      expectedReward += questById(id)!.reward;
      daily.claim(id);
    }
    expect(
      c.read(profileControllerProvider).coins,
      coinsBefore + expectedReward,
    );

    // Повторный claim не начисляет дважды.
    for (final id in completed) {
      daily.claim(id);
    }
    expect(
      c.read(profileControllerProvider).coins,
      coinsBefore + expectedReward,
    );
  });
}
