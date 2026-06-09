/// powerups_test.dart — тесты эффектов power-ups в партии (Фаза 7.3).
///
/// За что отвечает файл:
///   Проверяет команды [GameNotifier] для power-ups: очистка строки/столбца/
///   бомбы начисляет очки текущему игроку без передачи хода; обмен руки выдаёт
///   новые фигуры; подсказка выбирает фигуру и ставит подсветку; умный ход
///   применяет лучший ход и передаёт ход.
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

/// Hot-seat конфиг (оба игрока — люди, без бота в тесте).
const _config = MatchConfig(mode: MatchMode.hotseat, seed: 12345);

void main() {
  test('powerClearRow очищает занятые клетки строки и даёт очки текущему', () async {
    final c = await _container();
    final vm = c.read(gameProvider(_config).notifier);

    // Заполним строку 0 вручную через постановку невозможно — используем то, что
    // на старте доска пустая → очищать нечего → false.
    expect(vm.powerClearRow(0), isFalse);

    // Поставим фигуру игрока 0, затем очистим её строку power-up'ом.
    final st = c.read(gameProvider(_config));
    final piece = st.currentPlayer.hand.first;
    vm.selectPiece(piece.id);
    // Найдём допустимый якорь.
    final cells = c.read(gameProvider(_config)).activeCells!;
    int? ar, ac;
    outer:
    for (int r = 0; r < boardSize; r++) {
      for (int col = 0; col < boardSize; col++) {
        if (canPlace(c.read(gameProvider(_config)).board, cells, r, col)) {
          ar = r;
          ac = col;
          break outer;
        }
      }
    }
    vm.placeAt(ar!, ac!);

    // Теперь ход игрока 1. Очистим строку с положенными клетками power-up'ом.
    final placedRow = ar + cells.first.r;
    final before = c.read(gameProvider(_config)).players[1].score;
    final ok = vm.powerClearRow(placedRow);
    expect(ok, isTrue);
    final after = c.read(gameProvider(_config));
    // Очки достались текущему игроку (1), ход не сменился.
    expect(after.players[1].score, greaterThan(before));
    expect(after.current, 1);
    // Клетки строки очищены.
    expect(after.board[placedRow][ac].filled, isFalse);
  });

  test('powerSwapHand выдаёт новую руку того же размера', () async {
    final c = await _container();
    final vm = c.read(gameProvider(_config).notifier);
    final handBefore = [
      for (final p in c.read(gameProvider(_config)).currentPlayer.hand) p.id,
    ];
    expect(vm.powerSwapHand(), isTrue);
    final handAfter = c.read(gameProvider(_config)).currentPlayer.hand;
    expect(handAfter.length, handBefore.length);
    // Новые id (мешок выдаёт свежие экземпляры).
    expect(handAfter.map((p) => p.id).toSet().intersection(handBefore.toSet()),
        isEmpty);
  });

  test('powerHint выбирает фигуру и ставит подсветку', () async {
    final c = await _container();
    final vm = c.read(gameProvider(_config).notifier);
    expect(vm.powerHint(), isTrue);
    final st = c.read(gameProvider(_config));
    expect(st.selectedPieceId, isNotNull);
    expect(st.hintCells, isNotEmpty);
  });

  test('powerAutoPlay применяет ход и передаёт очередь', () async {
    final c = await _container();
    final vm = c.read(gameProvider(_config).notifier);
    final seqBefore = c.read(gameProvider(_config)).moveSeq;
    expect(vm.powerAutoPlay(), isTrue);
    final st = c.read(gameProvider(_config));
    expect(st.moveSeq, seqBefore + 1);
    expect(st.current, 1); // ход передан
  });
}
