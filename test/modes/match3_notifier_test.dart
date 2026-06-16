/// match3_notifier_test.dart — тесты ViewModel «Match-3 PvP».
///
/// Проверяют: старт (есть ход, лимит ходов), выбор/снятие выбора клетки и
/// симуляцию полной партии (легальные свопы дают очки, партия завершается по
/// лимиту ходов с определённым победителем).
library;

import 'package:block_duel/modes/match3/match3_core.dart';
import 'package:block_duel/modes/match3/match3_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _c() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

/// Находит первый легальный своп (создающий серию) на сетке.
({Cellxy a, Cellxy b})? _legalSwap(Match3Grid grid) {
  for (int r = 0; r < match3Size; r++) {
    for (int col = 0; col < match3Size; col++) {
      if (col + 1 < match3Size &&
          wouldMatch(grid, (r: r, c: col), (r: r, c: col + 1))) {
        return (a: (r: r, c: col), b: (r: r, c: col + 1));
      }
      if (r + 1 < match3Size &&
          wouldMatch(grid, (r: r, c: col), (r: r + 1, c: col))) {
        return (a: (r: r, c: col), b: (r: r + 1, c: col));
      }
    }
  }
  return null;
}

void main() {
  test('новая игра: ход 0, лимит ходов, есть легальный ход', () {
    final c = _c();
    c.read(match3Provider.notifier).newGame(2026);
    final s = c.read(match3Provider);
    expect(s.current, 0);
    expect(s.gameOver, isFalse);
    expect(s.turnsLeft, match3MaxTurns);
    expect(hasAnyValidMove(s.grid), isTrue);
  });

  test('тап выбирает клетку, повторный тап снимает выбор', () {
    final c = _c();
    final vm = c.read(match3Provider.notifier);
    vm.newGame(1);
    vm.tapCell((r: 0, c: 0));
    expect(c.read(match3Provider).selected, (r: 0, c: 0));
    vm.tapCell((r: 0, c: 0));
    expect(c.read(match3Provider).selected, isNull);
  });

  test('нелегальный/далёкий тап переносит выбор', () {
    final c = _c();
    final vm = c.read(match3Provider.notifier);
    vm.newGame(1);
    vm.tapCell((r: 0, c: 0));
    vm.tapCell((r: 5, c: 5)); // далеко → перенос выбора
    expect(c.read(match3Provider).selected, (r: 5, c: 5));
    expect(c.read(match3Provider).turnsPlayed, 0, reason: 'хода не было');
  });

  test('симуляция: легальные свопы дают очки, партия кончается по лимиту', () {
    final c = _c();
    final vm = c.read(match3Provider.notifier);
    vm.newGame(2026);
    var sawGain = false;
    var guard = 0;
    while (!c.read(match3Provider).gameOver && guard < 200) {
      guard++;
      final mv = _legalSwap(c.read(match3Provider).grid);
      expect(mv, isNotNull, reason: 'на поле всегда есть легальный своп');
      vm.tapCell(mv!.a);
      vm.tapCell(mv.b);
      if (c.read(match3Provider).lastGain > 0) sawGain = true;
    }
    final end = c.read(match3Provider);
    expect(end.gameOver, isTrue);
    expect(end.turnsPlayed, match3MaxTurns);
    expect(sawGain, isTrue, reason: 'свопы создавали серии и очки');
    expect(end.scores[0], greaterThanOrEqualTo(0));
    expect([0, 1, null], contains(end.winner));
  });
}
