/// crystal_packs_test.dart — тесты каталога пакетов кристаллов (§ 10.1).
///
/// Проверяют: уникальность id, рост объёма и бонуса, корректность total/
/// bonusPercent и пометки «выгодно».
library;

import 'package:block_duel/shop/crystal_packs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('каталог: 4 пакета с уникальными id', () {
    expect(crystalPacks.length, 4);
    expect(crystalPacks.map((p) => p.id).toSet().length, 4);
  });

  test('объём и бонус растут с ценой', () {
    for (int i = 1; i < crystalPacks.length; i++) {
      expect(crystalPacks[i].baseCrystals > crystalPacks[i - 1].baseCrystals,
          isTrue);
      expect(crystalPacks[i].bonusPercent >= crystalPacks[i - 1].bonusPercent,
          isTrue);
    }
  });

  test('total = база + бонус; малый пакет без бонуса', () {
    final small = crystalPackById('crystals_100')!;
    expect(small.bonusCrystals, 0);
    expect(crystalPackTotal(small), 100);
    final big = crystalPackById('crystals_5000')!;
    expect(big.total, big.baseCrystals + big.bonusCrystals);
    expect(big.bestValue, isTrue);
  });

  test('bonusPercent считается от базы', () {
    expect(crystalPackById('crystals_500')!.bonusPercent, 10);
    expect(crystalPackById('crystals_5000')!.bonusPercent, 35);
  });
}
