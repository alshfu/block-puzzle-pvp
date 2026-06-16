/// memory_solo_notifier_test.dart — тесты ViewModel режима «Память: соло».
///
/// Проверяют жизненный цикл попытки без UI: старт → фаза показа (целевая
/// раскладка), авто-переход в сборку по таймеру (через [fakeAsync]), постановку
/// фигуры из руки, досрочный финиш с подсчётом результата и запись рекорда, а
/// также сброс к выбору сложности и игнор команд вне фазы сборки.
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/modes/memory_solo/memory_solo_notifier.dart';
import 'package:block_duel/modes/memory_solo/memory_solo_puzzle.dart';
import 'package:block_duel/modes/memory_solo/memory_solo_store.dart';
import 'package:block_duel/storage/prefs.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Готовит mock-prefs (рекорды Memory Solo пишутся в SharedPreferences).
Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

/// Контейнер с подменённым [sharedPreferencesProvider].
ProviderContainer _container(SharedPreferences prefs) => ProviderContainer(
  overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
);

/// Считает заполненные клетки доски.
int _filled(Board b) {
  var n = 0;
  for (final row in b) {
    for (final cell in row) {
      if (cell.filled) n++;
    }
  }
  return n;
}

void main() {
  test('start → фаза показа с целевой раскладкой и нулевым рекордом', () async {
    final prefs = await _prefs();
    final c = _container(prefs);
    addTearDown(c.dispose);
    final vm = c.read(memorySoloProvider.notifier);

    vm.start(MemoryDifficulty.tutorial, 123);
    final s = c.read(memorySoloProvider);
    expect(s.phase, MemoryPhase.showing);
    expect(s.difficulty, MemoryDifficulty.tutorial);
    expect(s.best, 0);
    // Показанная доска совпадает с детерминированной раскладкой того же seed.
    final puzzle = generateMemoryPuzzle(MemoryDifficulty.tutorial, 123);
    expect(_filled(s.game!.board), _filled(puzzle.target));
    expect(_filled(s.game!.board), MemoryDifficulty.tutorial.pieceCount * 4);
  });

  test('команды сборки игнорируются в фазе показа', () async {
    final prefs = await _prefs();
    final c = _container(prefs);
    addTearDown(c.dispose);
    final vm = c.read(memorySoloProvider.notifier);
    vm.start(MemoryDifficulty.tutorial, 1);
    vm.placeAt(0, 0); // не должно ничего поставить
    expect(_filled(c.read(memorySoloProvider).game!.board),
        MemoryDifficulty.tutorial.pieceCount * 4,
        reason: 'доска показа не меняется постановкой');
  });

  test('таймер переводит показ → сборку → финиш', () async {
    final prefs = await _prefs();
    fakeAsync((async) {
      final c = _container(prefs);
      final vm = c.read(memorySoloProvider.notifier);
      vm.start(MemoryDifficulty.tutorial, 42);

      // Промотать фазу показа.
      async.elapse(
        Duration(
          milliseconds:
              (MemoryDifficulty.tutorial.showSeconds * 1000).round() + 200,
        ),
      );
      final mid = c.read(memorySoloProvider);
      expect(mid.phase, MemoryPhase.reconstruct);
      expect(_filled(mid.game!.board), 0, reason: 'доска сборки пуста');
      expect(mid.game!.currentPlayer.hand.length,
          MemoryDifficulty.tutorial.pieceCount);

      // Промотать фазу сборки до таймаута → финиш.
      async.elapse(
        Duration(
          milliseconds:
              (MemoryDifficulty.tutorial.reconstructSeconds * 1000).round() +
                  200,
        ),
      );
      final done = c.read(memorySoloProvider);
      expect(done.phase, MemoryPhase.done);
      expect(done.result, isNotNull);
      expect(done.result!.totalCells,
          MemoryDifficulty.tutorial.pieceCount * 4);
      c.dispose();
    });
  });

  test('постановка фигуры заполняет доску и уменьшает руку', () async {
    final prefs = await _prefs();
    fakeAsync((async) {
      final c = _container(prefs);
      final vm = c.read(memorySoloProvider.notifier);
      vm.start(MemoryDifficulty.tutorial, 7);
      async.elapse(const Duration(seconds: 4)); // в фазу сборки

      final before = c.read(memorySoloProvider);
      expect(before.phase, MemoryPhase.reconstruct);
      final pieceId = before.game!.currentPlayer.hand.first.id;
      vm.select(pieceId);
      vm.placeAt(0, 0); // пустая доска — нормализованная фигура встаёт в (0,0)

      final after = c.read(memorySoloProvider);
      expect(_filled(after.game!.board), 4, reason: 'тетромино = 4 клетки');
      expect(after.game!.currentPlayer.hand.length,
          MemoryDifficulty.tutorial.pieceCount - 1);
      c.dispose();
    });
  });

  test('finishNow считает результат и пишет рекорд', () async {
    final prefs = await _prefs();
    fakeAsync((async) {
      final c = _container(prefs);
      final vm = c.read(memorySoloProvider.notifier);
      vm.start(MemoryDifficulty.tutorial, 7);
      async.elapse(const Duration(seconds: 4)); // в фазу сборки

      // Точно воспроизводим раскладку: ставим все фигуры по записанным
      // позициям эталонной генерации того же seed недоступно (рука
      // перемешана), поэтому просто финишируем — проверяем механику записи.
      vm.finishNow();
      async.flushMicrotasks();
      final done = c.read(memorySoloProvider);
      expect(done.phase, MemoryPhase.done);
      // Рекорд в сторе соответствует посчитанному счёту (>= 0).
      final best = c.read(memorySoloStoreProvider).best(MemoryDifficulty.tutorial);
      expect(best, done.result!.score);
      c.dispose();
    });
  });

  test('reset возвращает к выбору сложности', () async {
    final prefs = await _prefs();
    final c = _container(prefs);
    addTearDown(c.dispose);
    final vm = c.read(memorySoloProvider.notifier);
    vm.start(MemoryDifficulty.easy, 5);
    expect(c.read(memorySoloProvider).phase, MemoryPhase.showing);
    vm.reset();
    final s = c.read(memorySoloProvider);
    expect(s.phase, MemoryPhase.pickDifficulty);
    expect(s.game, isNull);
  });
}
