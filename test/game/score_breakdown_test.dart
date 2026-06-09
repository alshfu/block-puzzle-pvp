/// score_breakdown_test.dart — разбивка очков хода (паритет с TS-офлайн).
///
/// За что отвечает файл:
///   Проверяет, что офлайн-партия считает очки полной формулой
///   ([scoreMoveDetailed]): постановка без очистки начисляет placement-бонус за
///   тип фигуры (раньше офлайн давал 0), а разбивка хода
///   (lastBaseGain/lastBonusGain/lastPerfectGain) суммируется в прирост счёта.
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
  test('постановка без очистки → placement-бонус + разбивка (паритет TS)', () async {
    final c = await _container();
    final vm = c.read(gameProvider(_arcade).notifier);
    final st0 = c.read(gameProvider(_arcade));
    final piece = st0.currentPlayer.hand.first;
    final expectedPlacement = st0.cfg.placementBonus[piece.type] ?? 0;

    vm.selectPiece(piece.id);
    final cells = c.read(gameProvider(_arcade)).activeCells!;
    // Пустая доска — первая подходящая клетка очистку не вызовет.
    int? ar, ac;
    outer:
    for (var r = 0; r < boardSize; r++) {
      for (var col = 0; col < boardSize; col++) {
        if (canPlace(c.read(gameProvider(_arcade)).board, cells, r, col)) {
          ar = r;
          ac = col;
          break outer;
        }
      }
    }
    vm.placeAt(ar!, ac!);

    final st1 = c.read(gameProvider(_arcade));
    expect(st1.lastClearCount, 0, reason: 'на пустой доске очистки нет');
    // Раньше офлайн давал 0 за ход без очистки; теперь — placement-бонус.
    expect(st1.players[0].score, expectedPlacement);
    expect(st1.lastBaseGain, expectedPlacement);
    expect(st1.lastBonusGain, 0);
    expect(st1.lastPerfectGain, 0);
    // Инвариант: сумма разбивки = прирост счёта игрока 0.
    expect(
      st1.lastBaseGain + st1.lastBonusGain + st1.lastPerfectGain,
      st1.players[0].score,
    );
  });

  test('placement-бонусы по типам совпадают с DEFAULT_CONFIG (I=5, O=0)', () {
    expect(defaultConfig.placementBonus[PieceType.i], 5);
    expect(defaultConfig.placementBonus[PieceType.o], 0);
  });
}
