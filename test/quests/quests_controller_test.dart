/// quests_controller_test.dart — тесты ViewModel недельных/сезонных квестов.
///
/// Покрывает накопление прогресса по событиям и идемпотентную ротацию периодов
/// (`refreshPeriods`) — тот же класс защиты, что у DailyController: провайдер
/// keepAlive, build() вычисляет ключи однажды, при работе через границу
/// недели/сезона нельзя копить прогресс на старом периоде.
library;

import 'package:block_duel/quests/quest.dart';
import 'package:block_duel/quests/quests_controller.dart';
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
  test('recordEvent копит прогресс в обоих периодах', () async {
    final c = await _container();
    final ctrl = c.read(questsControllerProvider.notifier);
    for (var i = 0; i < 5; i++) {
      ctrl.recordEvent(const QuestEvent(won: true, clears: 3));
    }
    final s = c.read(questsControllerProvider);
    final wkTotal = s.weekly.progress.values.fold<int>(0, (a, b) => a + b);
    final snTotal = s.seasonal.progress.values.fold<int>(0, (a, b) => a + b);
    expect(wkTotal, greaterThan(0));
    expect(snTotal, greaterThan(0));
  });

  test('refreshPeriods в тот же период идемпотентен (прогресс цел)', () async {
    final c = await _container();
    final ctrl = c.read(questsControllerProvider.notifier);
    ctrl.recordEvent(const QuestEvent(won: true, clears: 2));
    final before = c.read(questsControllerProvider);
    ctrl.refreshPeriods(); // тот же период — не должно сбросить
    final after = c.read(questsControllerProvider);
    expect(after.weekly.periodKey, before.weekly.periodKey);
    expect(after.seasonal.periodKey, before.seasonal.periodKey);
    expect(after.weekly.progress, before.weekly.progress);
    expect(after.seasonal.progress, before.seasonal.progress);
  });
}
