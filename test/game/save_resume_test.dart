/// save_resume_test.dart — тесты сохранения и продолжения партии (Фаза 4).
///
/// За что отвечает файл:
///   Проверяет детерминистичный resume 7-bag (snapshot/restore мешка дают ту же
///   последовательность) и сквозной раунд-трип партии через хранилище: ход →
///   авто-сохранение → восстановление с тем же состоянием.
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/game/game_notifier.dart';
import 'package:block_duel/game/match_config.dart';
import 'package:block_duel/game/saved_game.dart';
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
  test('Bag.fromState даёт ту же последовательность, что живой мешок', () {
    final bag = Bag(4242);
    // Протянем несколько фигур, затем снимем состояние.
    for (int i = 0; i < 5; i++) {
      bag.drawAvoiding({});
    }
    final restored = Bag.fromState(
      queue: bag.queueSnapshot,
      counter: bag.counter,
      rngState: bag.rngState,
    );
    // Дальнейшие выдачи обоих мешков совпадают (тип и id).
    for (int i = 0; i < 14; i++) {
      final a = bag.draw();
      final b = restored.draw();
      expect(b.type, a.type, reason: 'тип на шаге $i');
      expect(b.id, a.id, reason: 'id на шаге $i');
    }
  });

  test('SavedGame (де)сериализуется без потерь', () {
    const saved = SavedGame(
      mode: MatchMode.bot,
      botLevel: BotLevel.hard,
      seed: 99,
      board:
          '0........'
          '.........'
          '.........'
          '.........'
          '....1....'
          '.........'
          '.........'
          '.........'
          '.........',
      players: [
        SavedPlayer(
          score: 30,
          combo: 1,
          name: 'A',
          hand: [(id: 'p7', type: PieceType.t)],
        ),
        SavedPlayer(score: 10, combo: 0, name: 'B', hand: []),
      ],
      bags: [
        BagSnapshot(queue: [PieceType.i, PieceType.o], counter: 9, rngState: 7),
        BagSnapshot(queue: [], counter: 3, rngState: 1),
      ],
      current: 1,
      round: 2,
    );
    final back = SavedGame.fromJson(saved.toJson());
    expect(back.mode, saved.mode);
    expect(back.seed, 99);
    expect(back.board, saved.board);
    expect(back.players[0].hand.first.type, PieceType.t);
    expect(back.bags[0].queue, [PieceType.i, PieceType.o]);
    expect(back.current, 1);
  });

  test('раунд-трип: ход → авто-сохранение → resume восстанавливает', () async {
    final c = await _container();
    const config = MatchConfig(mode: MatchMode.hotseat, seed: 555);
    final vm = c.read(gameProvider(config).notifier);
    final firstId = c.read(gameProvider(config)).players[0].hand.first.id;
    vm.selectPiece(firstId);
    vm.placeAt(0, 0);

    final after = c.read(gameProvider(config));

    // Resume другим ключом семейства (тот же seed + resume) из того же хранилища.
    const resumeCfg = MatchConfig(
      mode: MatchMode.hotseat,
      seed: 555,
      resume: true,
    );
    final restored = c.read(gameProvider(resumeCfg));

    expect(restored.current, after.current);
    expect(encodeBoard(restored.board), encodeBoard(after.board));
    expect(restored.players[0].score, after.players[0].score);
    expect(
      restored.players[after.current].hand.map((p) => p.id).toList(),
      after.players[after.current].hand.map((p) => p.id).toList(),
    );
  });
}
