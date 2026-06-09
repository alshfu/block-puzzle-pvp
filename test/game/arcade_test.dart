/// arcade_test.dart — тесты соло-режима «Аркада» (ход не передаётся).
///
/// За что отвечает файл:
///   Проверяет, что в аркаде ходит только игрок 0: после постановки очередь
///   остаётся за ним, имя соло-игрока «Ты», скорборд-режим solo через
///   [MatchConfig.isSolo].
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/game/game_notifier.dart';
import 'package:block_duel/game/match_config.dart';
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

const _arcade = MatchConfig(mode: MatchMode.arcade, seed: 42);

void main() {
  test('isSolo и парсинг режима', () {
    expect(_arcade.isSolo, isTrue);
    expect(MatchConfig.modeFromString('arcade'), MatchMode.arcade);
    expect(const MatchConfig(mode: MatchMode.bot, seed: 1).isSolo, isFalse);
  });

  test('в аркаде ход остаётся за игроком 0 и нет бота', () async {
    final c = await _container();
    final vm = c.read(gameProvider(_arcade).notifier);
    final st0 = c.read(gameProvider(_arcade));
    expect(st0.current, 0);
    expect(st0.players[0].name, 'Ты');
    expect(_arcade.isBot(0), isFalse);
    expect(_arcade.isBot(1), isFalse);

    // Поставим фигуру игрока 0.
    final piece = st0.currentPlayer.hand.first;
    vm.selectPiece(piece.id);
    final cells = c.read(gameProvider(_arcade)).activeCells!;
    int? ar, ac;
    outer:
    for (int r = 0; r < boardSize; r++) {
      for (int col = 0; col < boardSize; col++) {
        if (canPlace(c.read(gameProvider(_arcade)).board, cells, r, col)) {
          ar = r;
          ac = col;
          break outer;
        }
      }
    }
    vm.placeAt(ar!, ac!);

    final st1 = c.read(gameProvider(_arcade));
    // Ход НЕ передан — по-прежнему игрок 0; раунд вырос.
    expect(st1.current, 0);
    expect(st1.round, st0.round + 1);
    expect(st1.moveSeq, st0.moveSeq + 1);
  });
}
