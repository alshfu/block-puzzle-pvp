/// memory_duel_test.dart — тесты ViewModel локального «Memory Duel».
///
/// Прогоняют полную дуэль из двух раундов через [fakeAsync]: расстановка →
/// запоминание (таймер) → воспроизведение (таймер/рука) → итог раунда → смена
/// ролей → итог дуэли. Проверяют корректность фаз, смену аранжировщика и
/// вычисление результатов воспроизведения для обоих игроков.
library;

import 'package:block_duel/modes/memory_duel/memory_duel_notifier.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Расставляет всю руку текущего игрока (первый валидный якорь для каждой
/// фигуры). Завершается, когда рука опустела (нотифайер сам финиширует фазу).
void _placeAll(ProviderContainer c, MemoryDuelNotifier vm) {
  var guard = 0;
  while (guard < 100) {
    guard++;
    final s = c.read(memoryDuelProvider);
    if (s.phase != DuelPhase.arrange && s.phase != DuelPhase.reproduce) break;
    final hand = s.game.currentPlayer.hand;
    if (hand.isEmpty) break;
    vm.select(hand.first.id);
    final g = c.read(memoryDuelProvider).game;
    var placed = false;
    for (int r = 0; r < 9 && !placed; r++) {
      for (int col = 0; col < 9 && !placed; col++) {
        if (g.canPlaceAt(r, col)) {
          vm.placeAt(r, col);
          placed = true;
        }
      }
    }
    if (!placed) break;
  }
}

void main() {
  test('полная дуэль: два раунда со сменой ролей и вычислением итогов', () {
    fakeAsync((async) {
      final c = ProviderContainer();
      final vm = c.read(memoryDuelProvider.notifier);
      vm.restart(123);

      // Раунд 0: аранжировщик 0, репродьюсер 1.
      var s = c.read(memoryDuelProvider);
      expect(s.phase, DuelPhase.introArrange);
      expect(s.round, 0);
      expect(s.arranger, 0);
      expect(s.game.currentPlayer.hand.length, memoryDuelPieces);

      vm.proceed(); // → arrange
      expect(c.read(memoryDuelProvider).phase, DuelPhase.arrange);
      _placeAll(c, vm); // расставил всё → introMemorize
      expect(c.read(memoryDuelProvider).phase, DuelPhase.introMemorize);

      vm.proceed(); // → memorize (таймер)
      expect(c.read(memoryDuelProvider).phase, DuelPhase.memorize);
      async.elapse(const Duration(seconds: 6)); // показ истёк → reproduce
      expect(c.read(memoryDuelProvider).phase, DuelPhase.reproduce);
      expect(c.read(memoryDuelProvider).game.currentPlayer.hand.length,
          memoryDuelPieces);

      _placeAll(c, vm); // воспроизвёл → roundResult
      s = c.read(memoryDuelProvider);
      expect(s.phase, DuelPhase.roundResult);
      expect(s.reproResult[1], isNotNull, reason: 'результат игрока 1 посчитан');

      vm.proceed(); // → раунд 1
      s = c.read(memoryDuelProvider);
      expect(s.round, 1);
      expect(s.arranger, 1);
      expect(s.phase, DuelPhase.introArrange);

      vm.proceed(); // arrange (роли сменились)
      _placeAll(c, vm);
      vm.proceed(); // memorize
      async.elapse(const Duration(seconds: 6));
      _placeAll(c, vm); // reproduce → roundResult
      s = c.read(memoryDuelProvider);
      expect(s.phase, DuelPhase.roundResult);
      expect(s.reproResult[0], isNotNull, reason: 'результат игрока 0 посчитан');

      vm.proceed(); // → done
      s = c.read(memoryDuelProvider);
      expect(s.phase, DuelPhase.done);
      // Победитель определён без ошибок (0/1/ничья).
      expect([0, 1, null], contains(s.winner));

      c.dispose();
    });
  });

  test('воспроизведение по таймауту считает результат (рука не пуста)', () {
    fakeAsync((async) {
      final c = ProviderContainer();
      final vm = c.read(memoryDuelProvider.notifier);
      vm.restart(7);
      vm.proceed();
      _placeAll(c, vm); // introMemorize
      vm.proceed(); // memorize
      async.elapse(const Duration(seconds: 6)); // → reproduce
      expect(c.read(memoryDuelProvider).phase, DuelPhase.reproduce);
      // НЕ расставляем — ждём таймаут воспроизведения.
      async.elapse(const Duration(seconds: 51));
      final s = c.read(memoryDuelProvider);
      expect(s.phase, DuelPhase.roundResult);
      expect(s.reproResult[1], isNotNull);
      expect(s.reproResult[1]!.accuracy, 0.0,
          reason: 'ничего не воспроизведено → точность 0');
      c.dispose();
    });
  });

  test('restart возвращает к раунду 0 заставке расстановки', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(memoryDuelProvider.notifier);
    vm.restart(1);
    vm.proceed();
    expect(c.read(memoryDuelProvider).phase, DuelPhase.arrange);
    vm.restart(2);
    final s = c.read(memoryDuelProvider);
    expect(s.phase, DuelPhase.introArrange);
    expect(s.round, 0);
  });
}
