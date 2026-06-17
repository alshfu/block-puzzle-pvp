/// quest_test.dart — тесты обобщённого движка квестов (ROADMAP § 8.4).
library;

import 'package:block_duel/quests/quest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pickQuests', () {
    test('детерминирован по ключу периода', () {
      final a = pickQuests(QuestPeriod.weekly, 'W100');
      final b = pickQuests(QuestPeriod.weekly, 'W100');
      expect(a.map((q) => q.id).toList(), b.map((q) => q.id).toList());
    });

    test('выбирает нужное число и из правильного пула', () {
      final w = pickQuests(QuestPeriod.weekly, 'W1');
      final s = pickQuests(QuestPeriod.seasonal, 'S1');
      expect(w.length, questCountWeekly);
      expect(s.length, questCountSeasonal);
      expect(w.every((q) => q.period == QuestPeriod.weekly), isTrue);
      expect(s.every((q) => q.period == QuestPeriod.seasonal), isTrue);
    });

    test('по разным ключам наборы варьируются (не всегда одинаковы)', () {
      final variants = <String>{
        for (final k in ['W1', 'W2', 'W3', 'W5', 'W8', 'W13'])
          pickQuests(QuestPeriod.weekly, k).map((q) => q.id).join(','),
      };
      expect(variants.length, greaterThan(1),
          reason: 'выбор зависит от ключа периода');
    });
  });

  group('QuestEvent.deltaFor', () {
    test('метрики считаются корректно', () {
      const e = QuestEvent(
        won: true,
        perfect: true,
        vsHardBot: true,
        clears: 4,
        winStreak: 3,
      );
      expect(e.deltaFor(QuestMetric.games), 1);
      expect(e.deltaFor(QuestMetric.wins), 1);
      expect(e.deltaFor(QuestMetric.clears), 4);
      expect(e.deltaFor(QuestMetric.perfectClears), 1);
      expect(e.deltaFor(QuestMetric.hardWins), 1);
      expect(e.deltaFor(QuestMetric.onlineWins), 0);
      expect(e.deltaFor(QuestMetric.bestStreak), 3);
    });

    test('поражение не даёт win-метрик', () {
      const e = QuestEvent(won: false, vsHardBot: true);
      expect(e.deltaFor(QuestMetric.wins), 0);
      expect(e.deltaFor(QuestMetric.hardWins), 0);
    });
  });

  group('QuestPeriodState.applyEvent', () {
    test('кумулятивная метрика суммируется и не превышает цель', () {
      var s = QuestPeriodState.fresh(QuestPeriod.weekly, 'W1');
      // Найдём кумулятивный квест на победы, если он в наборе; иначе games.
      final winId = s.questIds.firstWhere(
        (id) => questById(id)!.metric == QuestMetric.wins,
        orElse: () => s.questIds.first,
      );
      final q = questById(winId)!;
      for (var i = 0; i < q.target + 5; i++) {
        s = s.applyEvent(
          QuestEvent(won: true, clears: 1, winStreak: i + 1),
        );
      }
      expect(s.progress[winId], q.target, reason: 'прогресс зажат целью');
    });

    test('не-кумулятивная (bestStreak) берёт максимум, а не сумму', () {
      // Известный streak-квест из недельного пула (cumulative: false).
      var s = const QuestPeriodState(
        periodKey: 'W1',
        questIds: ['w_streak_5'],
        progress: {'w_streak_5': 0},
        claimed: {},
      );
      s = s.applyEvent(const QuestEvent(won: true, winStreak: 3));
      expect(s.progress['w_streak_5'], 3);
      s = s.applyEvent(const QuestEvent(won: true, winStreak: 2));
      expect(s.progress['w_streak_5'], 3, reason: 'меньшая серия не понижает');
      s = s.applyEvent(const QuestEvent(won: true, winStreak: 7));
      expect(s.progress['w_streak_5'], 5, reason: 'зажато целью 5');
    });
  });
}
