/// shop_test.dart — тесты экономики магазина (Фаза 7).
///
/// За что отвечает файл:
///   Проверяет начисление кристаллов из очков, покупку/надевание скинов за
///   монеты, покупку/расход power-ups за кристаллы и персист через mock-prefs.
library;

import 'package:block_duel/profile/profile_controller.dart';
import 'package:block_duel/shop/inventory_controller.dart';
import 'package:block_duel/shop/powerups.dart';
import 'package:block_duel/shop/skins.dart';
import 'package:block_duel/shop/skins_controller.dart';
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
  test('определения магазина консистентны', () {
    expect(skinsById['default']!.price, 0);
    expect(skinDefs.first.id, 'default');
    expect(powerupsById.length, powerupDefs.length);
    expect(skinsById.length, skinDefs.length);
  });

  test('кристаллы начисляются за каждые 150 очков, остаток копится', () async {
    final c = await _container();
    final ctrl = c.read(profileControllerProvider.notifier);

    ctrl.earnCrystalsFromScore(100);
    expect(c.read(profileControllerProvider).crystals, 0);

    // 100 + 80 = 180 → 1 кристалл, остаток 30.
    ctrl.earnCrystalsFromScore(80);
    final p = c.read(profileControllerProvider);
    expect(p.crystals, 1);
    expect(p.scoreForCrystals, 30);

    // 30 + 320 = 350 → 2 кристалла, остаток 50 (всего 3).
    ctrl.earnCrystalsFromScore(320);
    expect(c.read(profileControllerProvider).crystals, 3);
    expect(c.read(profileControllerProvider).scoreForCrystals, 50);
  });

  test('покупка скина списывает монеты и разблокирует, надевание работает',
      () async {
    final c = await _container();
    final profile = c.read(profileControllerProvider.notifier);
    final skins = c.read(skinsControllerProvider.notifier);
    profile.addCoins(200);

    final gem = skinsById['gem']!;
    expect(skins.buy('gem'), isTrue);
    expect(c.read(profileControllerProvider).coins, 200 - gem.price);
    expect(c.read(skinsControllerProvider).unlocked.contains('gem'), isTrue);

    // Повторная покупка не списывает.
    expect(skins.buy('gem'), isFalse);

    skins.equip('gem');
    expect(c.read(skinsControllerProvider).equipped, 'gem');

    // Нельзя надеть не купленный.
    skins.equip('neon');
    expect(c.read(skinsControllerProvider).equipped, 'gem');
  });

  test('покупка скина без монет проваливается', () async {
    final c = await _container();
    final skins = c.read(skinsControllerProvider.notifier);
    expect(skins.buy('gem'), isFalse);
    expect(c.read(skinsControllerProvider).unlocked.contains('gem'), isFalse);
  });

  test('power-up покупается за кристаллы и расходуется', () async {
    final c = await _container();
    final profile = c.read(profileControllerProvider.notifier);
    final inv = c.read(inventoryControllerProvider.notifier);

    // Без кристаллов покупка проваливается.
    expect(inv.buy('hint'), isFalse);

    // Накопим кристаллы (3 шт = 450 очков).
    profile.earnCrystalsFromScore(450);
    expect(c.read(profileControllerProvider).crystals, 3);

    final hint = powerupsById['hint']!;
    expect(inv.buy('hint'), isTrue);
    expect(inv.count('hint'), 1);
    expect(c.read(profileControllerProvider).crystals, 3 - hint.price);

    // Расход уменьшает счётчик.
    expect(inv.consume('hint'), isTrue);
    expect(inv.count('hint'), 0);
    expect(inv.consume('hint'), isFalse);
  });

  test('состояние магазина переживает пересоздание контейнера (персист)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c1 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    c1.read(profileControllerProvider.notifier).addCoins(200);
    c1.read(skinsControllerProvider.notifier).buy('gem');
    c1.read(skinsControllerProvider.notifier).equip('gem');
    c1.dispose();

    final c2 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c2.dispose);
    expect(c2.read(skinsControllerProvider).equipped, 'gem');
    expect(c2.read(skinsControllerProvider).unlocked.contains('gem'), isTrue);
  });
}
