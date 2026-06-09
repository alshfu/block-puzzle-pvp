/// profile_test.dart — тесты модели и ViewModel профиля (Фаза 4).
///
/// За что отвечает файл:
///   Проверяет треугольную прогрессию уровней, (де)сериализацию профиля и
///   начисление наград/персист через [ProfileController] с mock-хранилищем.
library;

import 'package:block_duel/profile/profile.dart';
import 'package:block_duel/profile/profile_controller.dart';
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
  test('уровень растёт по треугольной кривой', () {
    expect(levelForXp(0), 1);
    expect(xpToReachLevel(1), 0);
    // Уровень 2 — при 50 XP (floor(50·1·2/2)).
    expect(xpToReachLevel(2), 50);
    expect(levelForXp(49), 1);
    expect(levelForXp(50), 2);
    expect(levelForXp(xpToReachLevel(5)), 5);
  });

  test('профиль (де)сериализуется без потерь', () {
    const p = Profile(
      nick: 'Тест',
      avatar: '🦄',
      xp: 123,
      coins: 7,
      gamesPlayed: 4,
      wins: 2,
    );
    final back = Profile.fromJson(p.toJson());
    expect(back.nick, p.nick);
    expect(back.avatar, p.avatar);
    expect(back.xp, p.xp);
    expect(back.coins, p.coins);
    expect(back.wins, p.wins);
  });

  test('recordResult начисляет награды и сохраняет', () async {
    final c = await _container();
    final ctrl = c.read(profileControllerProvider.notifier);

    ctrl.recordResult(won: true);
    final after = c.read(profileControllerProvider);
    expect(after.gamesPlayed, 1);
    expect(after.wins, 1);
    expect(after.xp, greaterThan(0));
    expect(after.coins, greaterThan(0));

    // Персист: новый контейнер с тем же хранилищем видит сохранённое.
    final prefs = await SharedPreferences.getInstance();
    final c2 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c2.dispose);
    expect(c2.read(profileControllerProvider).wins, 1);
  });

  test('ничья не добавляет победу', () async {
    final c = await _container();
    final ctrl = c.read(profileControllerProvider.notifier);
    ctrl.recordResult(won: false, draw: true);
    final after = c.read(profileControllerProvider);
    expect(after.gamesPlayed, 1);
    expect(after.wins, 0);
  });
}
