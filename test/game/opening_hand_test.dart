/// opening_hand_test.dart — тесты гарантии валидного стартового hand (§ 8.3).
///
/// Проверяют: на пустой доске стартовая рука ВСЕГДА имеет ход (1000 сидов, ни
/// одного «мёртвого» старта); раздача детерминирована и на пустой доске
/// идентична обычной (reroll не срабатывает); на полностью занятой доске
/// функция не зацикливается и возвращает руку нужного размера.
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/game/opening_hand.dart';
import 'package:flutter_test/flutter_test.dart';

/// Раздача без гарантии (эталон) — для проверки идентичности на пустой доске.
List<PieceInstance> _plainDeal(Bag bag, int k) {
  final hand = <PieceInstance>[];
  for (int i = 0; i < k; i++) {
    hand.add(bag.drawAvoiding(hand.map((p) => p.type).toSet()));
  }
  return hand;
}

void main() {
  test('1000 свежих стартов: у новичка всегда есть ход', () {
    for (int seed = 0; seed < 1000; seed++) {
      final hand = dealOpeningHand(
        Bag(seed),
        defaultConfig.handSize,
        emptyBoard(),
        defaultConfig,
      );
      expect(
        hasAnyMove(emptyBoard(), hand, defaultConfig),
        isTrue,
        reason: 'seed=$seed дал мёртвый старт',
      );
    }
  });

  test('на пустой доске reroll не срабатывает — раздача та же', () {
    const k = 3;
    for (int seed = 0; seed < 50; seed++) {
      final guarded = dealOpeningHand(Bag(seed), k, emptyBoard(), defaultConfig);
      final plain = _plainDeal(Bag(seed), k);
      expect(
        guarded.map((p) => p.type).toList(),
        plain.map((p) => p.type).toList(),
      );
    }
  });

  test('на полностью занятой доске не зацикливается, возвращает k фигур', () {
    final full = emptyBoard();
    for (final row in full) {
      for (final cell in row) {
        cell.filled = true;
      }
    }
    final hand = dealOpeningHand(Bag(1), 3, full, defaultConfig);
    expect(hand.length, 3);
  });
}
