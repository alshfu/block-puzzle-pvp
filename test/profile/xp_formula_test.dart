/// xp_formula_test.dart — тесты структурированной XP-формулы (ROADMAP § 8.1).
library;

import 'package:block_duel/core/core.dart' show BotLevel;
import 'package:block_duel/profile/xp_formula.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resultMultiplier', () {
    test('победа 1.0 / ничья 0.5 / поражение 0.0', () {
      expect(resultMultiplier(MatchOutcome.win), 1.0);
      expect(resultMultiplier(MatchOutcome.draw), 0.5);
      expect(resultMultiplier(MatchOutcome.loss), 0.0);
    });
  });

  group('diffMult', () {
    test('по уровню бота', () {
      expect(diffMultForBot(BotLevel.easy), 0.7);
      expect(diffMultForBot(BotLevel.medium), 1.0);
      expect(diffMultForBot(BotLevel.hard), 1.3);
    });

    test('по ELO: сильнее соперник → больше, зажат в [0.7, 1.6]', () {
      expect(diffMultForElo(1000, 1000), 1.0);
      expect(diffMultForElo(1000, 1250), greaterThan(1.0));
      expect(diffMultForElo(1000, 1100), closeTo(1.2, 1e-9));
      expect(diffMultForElo(1000, 5000), maxDiffMult); // клип сверху
      expect(diffMultForElo(5000, 1000), minDiffMult); // клип снизу
    });
  });

  group('streakBonus', () {
    test('растёт на 0.05 за победу, cap 1.5', () {
      expect(streakBonus(0), 1.0);
      expect(streakBonus(1), closeTo(1.05, 1e-9));
      expect(streakBonus(5), closeTo(1.25, 1e-9));
      expect(streakBonus(10), 1.5);
      expect(streakBonus(20), 1.5); // не выше cap
    });
  });

  group('xpForMatch', () {
    test('базовая победа без бонусов = floor(50·1·1·1) = 50', () {
      expect(
        xpForMatch(outcome: MatchOutcome.win),
        50,
      );
    });

    test('поражение → 0 XP по формуле', () {
      expect(
        xpForMatch(outcome: MatchOutcome.loss, diffMult: 1.3, winStreak: 5),
        0,
      );
    });

    test('ничья = floor(50·0.5) = 25', () {
      expect(xpForMatch(outcome: MatchOutcome.draw), 25);
    });

    test('победа над hard со стриком 5: floor(50·1·1.3·1.25) = 81', () {
      expect(
        xpForMatch(
          outcome: MatchOutcome.win,
          diffMult: diffMultForBot(BotLevel.hard),
          winStreak: 5,
        ),
        (50 * 1.3 * 1.25).floor(),
      );
    });

    test('diffMult зажимается в допустимый диапазон', () {
      // diffMult 5.0 → клип до 1.6: floor(50·1.6)=80.
      expect(xpForMatch(outcome: MatchOutcome.win, diffMult: 5.0), 80);
    });

    test('монотонность: сильнее соперник и длиннее серия → больше XP', () {
      final base = xpForMatch(outcome: MatchOutcome.win);
      final strong = xpForMatch(
        outcome: MatchOutcome.win,
        diffMult: 1.3,
        winStreak: 4,
      );
      expect(strong, greaterThan(base));
    });
  });
}
