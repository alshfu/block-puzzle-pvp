/// achievements_controller_test.dart — тесты ViewModel достижений.
///
/// Движок (processMatch/processOnlineMatch) покрыт engine_test; сам контроллер
/// (применение результата, начисление XP за впервые разблокированные, отсутствие
/// двойного начисления, cloud-merge без XP, персист, reset) до 2026-08-24 не
/// тестировался — а это критично (двойной XP = дисбаланс экономики).
library;

import 'package:block_duel/achievements/achievement.dart';
import 'package:block_duel/achievements/achievements_controller.dart';
import 'package:block_duel/achievements/definitions.dart';
import 'package:block_duel/achievements/engine.dart';
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

MatchContext _winCtx() => const MatchContext(
      winner: 0,
      hadPerfectClear: false,
      maxMultiClear: 0,
      bestCombo: 0,
      mode: 'bot',
      botLevel: 'medium',
      statsAfter: Stats(games: 1, wins: 1),
      winStreak: 1,
    );

void main() {
  test('recordMatch разблокирует first_blood и начисляет его XP один раз', () async {
    final c = await _container();
    final ach = c.read(achievementsControllerProvider.notifier);
    final xp0 = c.read(profileControllerProvider).xp;

    final unlocked = ach.recordMatch(_winCtx());
    expect(unlocked.any((d) => d.id == 'first_blood'), isTrue);
    final reward = achievementsById['first_blood']!.rewardXp;
    expect(c.read(profileControllerProvider).xp, xp0 + reward);
  });

  test('повторный recordMatch НЕ начисляет XP снова (уже разблокировано)', () async {
    final c = await _container();
    final ach = c.read(achievementsControllerProvider.notifier);
    ach.recordMatch(_winCtx());
    final xpAfterFirst = c.read(profileControllerProvider).xp;
    final again = ach.recordMatch(_winCtx());
    expect(again.any((d) => d.id == 'first_blood'), isFalse); // не «впервые»
    expect(c.read(profileControllerProvider).xp, xpAfterFirst); // XP не вырос
  });

  test('mergeUnlocked помечает облачные ачивки без начисления XP', () async {
    final c = await _container();
    final ach = c.read(achievementsControllerProvider.notifier);
    final xp0 = c.read(profileControllerProvider).xp;
    ach.mergeUnlocked({'first_blood', 'ai_tamer'});
    expect(c.read(achievementsControllerProvider)['first_blood']!.unlocked, isTrue);
    expect(c.read(achievementsControllerProvider)['ai_tamer']!.unlocked, isTrue);
    // Облачный xp уже включает награды — двойного начисления быть не должно.
    expect(c.read(profileControllerProvider).xp, xp0);
  });

  test('reset очищает прогресс', () async {
    final c = await _container();
    final ach = c.read(achievementsControllerProvider.notifier);
    ach.recordMatch(_winCtx());
    expect(c.read(achievementsControllerProvider), isNotEmpty);
    ach.reset();
    expect(c.read(achievementsControllerProvider), isEmpty);
  });

  test('персист: разблокировки видны в новом контейнере', () async {
    final c = await _container();
    c.read(achievementsControllerProvider.notifier).recordMatch(_winCtx());
    final prefs = await SharedPreferences.getInstance();
    final c2 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c2.dispose);
    expect(c2.read(achievementsControllerProvider)['first_blood']!.unlocked, isTrue);
  });
}
