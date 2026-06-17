/// level_rewards_test.dart — тесты таблицы наград за уровни (ROADMAP § 8.2).
library;

import 'package:block_duel/profile/level_rewards.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rewardForLevel', () {
    test('уровень 1 и ниже — без награды', () {
      expect(rewardForLevel(1).coins, 0);
      expect(rewardForLevel(1).crystals, 0);
      expect(rewardForLevel(1).unlock, isNull);
    });

    test('монеты растут с уровнем', () {
      expect(rewardForLevel(2).coins, 20);
      expect(rewardForLevel(3).coins, 25);
      expect(rewardForLevel(10).coins, 60);
      expect(rewardForLevel(2).coins, lessThan(rewardForLevel(50).coins));
    });

    test('кристаллы на вехах', () {
      expect(rewardForLevel(4).crystals, 0);
      expect(rewardForLevel(5).crystals, 5);
      expect(rewardForLevel(10).crystals, 10);
      expect(rewardForLevel(25).crystals, 25);
      expect(rewardForLevel(50).crystals, 25);
      expect(rewardForLevel(100).crystals, 100);
    });

    test('уровень 100 разблокирует зеркальный набор', () {
      expect(rewardForLevel(100).unlock, mirrorPiecesUnlock);
      expect(rewardForLevel(99).unlock, isNull);
    });
  });

  group('rewardsForLevelUp', () {
    test('переход на 2+ уровня суммирует награды', () {
      final r = rewardsForLevelUp(1, 3);
      expect(r.coins, rewardForLevel(2).coins + rewardForLevel(3).coins);
      expect(r.crystals, 0);
      expect(r.unlocks, isEmpty);
    });

    test('to <= from — нулевая награда', () {
      final r = rewardsForLevelUp(5, 5);
      expect(r.coins, 0);
      expect(r.crystals, 0);
      expect(r.unlocks, isEmpty);
    });

    test('пересечение веха с кристаллами и unlock на 100', () {
      final r = rewardsForLevelUp(98, 100);
      expect(r.crystals, 100); // ровно 100-й уровень даёт 100
      expect(r.unlocks, contains(mirrorPiecesUnlock));
    });
  });
}
