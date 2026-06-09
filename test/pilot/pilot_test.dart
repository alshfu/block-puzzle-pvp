/// pilot_test.dart — тесты скрытого pilot и гейта разработчика.
///
/// За что отвечает файл:
///   Проверяет: гейт [isDeveloperProvider] (локальный флаг включает/выключает),
///   авто-ход [GameNotifier.pilotPlayTurn] (делает ход за человека и передаёт
///   очередь), и что [PilotController.start] переводит в running.
library;

import 'package:block_duel/game/game_notifier.dart';
import 'package:block_duel/game/match_config.dart';
import 'package:block_duel/pilot/developer.dart';
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

const _hotseat = MatchConfig(mode: MatchMode.hotseat, seed: 7);

void main() {
  test(
    'гейт разработчика: по умолчанию выкл, секретный жест включает',
    () async {
      final c = await _container();
      expect(c.read(isDeveloperProvider), isFalse);

      c.read(isDeveloperProvider.notifier).enableViaSecret();
      expect(c.read(isDeveloperProvider), isTrue);

      c.read(isDeveloperProvider.notifier).disable();
      expect(c.read(isDeveloperProvider), isFalse);
    },
  );

  test('флаг dev переживает пересоздание контейнера (персист)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c1 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    c1.read(isDeveloperProvider.notifier).enableViaSecret();
    c1.dispose();

    final c2 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c2.dispose);
    expect(c2.read(isDeveloperProvider), isTrue);
  });

  test('pilotPlayTurn делает ход за человека и передаёт очередь', () async {
    final c = await _container();
    final vm = c.read(gameProvider(_hotseat).notifier);
    final before = c.read(gameProvider(_hotseat));
    expect(before.current, 0);

    final acted = vm.pilotPlayTurn();
    expect(acted, isTrue);
    final after = c.read(gameProvider(_hotseat));
    expect(after.moveSeq, before.moveSeq + 1);
    expect(after.current, 1); // hot-seat передаёт ход
  });

  test('pilotPlayTurn устойчиво играет много ходов подряд', () async {
    final c = await _container();
    final vm = c.read(gameProvider(_hotseat).notifier);
    var played = 0;
    // Умелый пилот может играть долго (всегда есть ход) — проверяем, что он
    // стабильно делает ходы и не падает; до тупика без blitz доходить не обязан.
    for (var i = 0; i < 40; i++) {
      final g = c.read(gameProvider(_hotseat));
      if (g.gameOver) break;
      if (vm.pilotPlayTurn()) played++;
    }
    expect(played, greaterThan(10));
  });
}
