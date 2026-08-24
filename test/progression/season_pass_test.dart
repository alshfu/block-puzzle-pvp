/// season_pass_test.dart — тесты сезонного пропуска (§ 10.4): pure + ViewModel.
///
/// Проверяют: маппинг XP→уровень и прогресс в уровне, ключ сезона, рост наград
/// и премиум-джекпот на 50-м; в ViewModel — накопление XP, покупку премиума,
/// одноразовый claim бесплатного и гейтинг премиум-трека.
library;

import 'package:block_duel/progression/season_pass.dart';
import 'package:block_duel/progression/season_pass_controller.dart';
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
  group('pure', () {
    test('XP→уровень и прогресс в уровне', () {
      expect(seasonTierForXp(0), 0);
      expect(seasonTierForXp(seasonXpPerTier - 1), 0);
      expect(seasonTierForXp(seasonXpPerTier), 1);
      expect(seasonTierForXp(seasonXpPerTier * 3), 3);
      expect(seasonXpInTier(seasonXpPerTier + 120), 120);
    });

    test('уровень зажат сверху на seasonTiers', () {
      expect(seasonTierForXp(seasonXpPerTier * 999), seasonTiers);
    });

    test('ключ сезона меняется каждые seasonDays', () {
      expect(seasonKeyForDay(0), seasonKeyForDay(seasonDays - 1));
      expect(seasonKeyForDay(seasonDays), seasonKeyForDay(0) + 1);
    });

    test('награды растут; премиум крупнее; джекпот на 50-м', () {
      expect(seasonFreeReward(10).coins < seasonFreeReward(20).coins, isTrue);
      expect(
        seasonPremiumReward(10).coins > seasonFreeReward(10).coins,
        isTrue,
      );
      expect(seasonPremiumReward(seasonTiers).crystals >= 200, isTrue);
      expect(seasonFreeReward(0).coins, 0);
    });
  });

  group('ViewModel', () {
    test('накопление XP поднимает уровень', () async {
      final c = await _container();
      final vm = c.read(seasonPassControllerProvider.notifier);
      expect(c.read(seasonPassControllerProvider).tier, 0);
      vm.addXp(seasonXpPerTier * 2 + 10);
      expect(c.read(seasonPassControllerProvider).tier, 2);
    });

    test('claim бесплатного: один раз, требует достижения уровня', () async {
      final c = await _container();
      final vm = c.read(seasonPassControllerProvider.notifier);
      vm.addXp(seasonXpPerTier * 3);
      // Уровень не достигнут.
      expect(vm.claimFree(4), isNull);
      // Достигнутый уровень — награда выдаётся один раз.
      expect(vm.claimFree(2), isNotNull);
      expect(vm.claimFree(2), isNull);
    });

    test('премиум-трек закрыт без покупки, открыт после', () async {
      final c = await _container();
      final vm = c.read(seasonPassControllerProvider.notifier);
      vm.addXp(seasonXpPerTier * 2);
      expect(vm.claimPremium(1), isNull);
      vm.buyPremium();
      expect(c.read(seasonPassControllerProvider).premium, isTrue);
      expect(vm.claimPremium(1), isNotNull);
    });

    test('refreshSeason в том же сезоне идемпотентен (прогресс цел)', () async {
      final c = await _container();
      final vm = c.read(seasonPassControllerProvider.notifier);
      vm.addXp(seasonXpPerTier + 5);
      vm.buyPremium();
      final before = c.read(seasonPassControllerProvider);
      vm.refreshSeason(); // тот же сезон — не сбрасывать
      final after = c.read(seasonPassControllerProvider);
      expect(after.seasonKey, before.seasonKey);
      expect(after.xp, before.xp);
      expect(after.premium, isTrue);
    });
  });
}
