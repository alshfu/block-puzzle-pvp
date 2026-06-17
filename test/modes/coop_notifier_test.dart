/// coop_notifier_test.dart — тесты ViewModel «Co-op Tetris».
///
/// Проверяют механику hot-seat без UI: детерминизм раздачи, смену хода и
/// пополнение руки при постановке, поворот, отказ невалидной постановки, а
/// также целостность инвариантов в симуляции целой партии (очистка строк
/// начисляет очки, партия сходится к тупику).
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/modes/coop/coop_core.dart';
import 'package:block_duel/modes/coop/coop_notifier.dart';
import 'package:block_duel/modes/coop/coop_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Контейнер провайдеров с авто-очисткой.
ProviderContainer _c() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

/// Находит первый легальный ход (фигура, ориентация, якорь) для текущего
/// игрока. Возвращает `null`, если ходов нет.
({String id, int orient, int r, int c})? _firstMove(
  CoopState s,
) {
  for (final piece in s.currentPlayer.hand) {
    final os = orientations(
      piece.type,
      s.cfg.rotationEnabled,
      s.cfg.flipEnabled,
    );
    for (int o = 0; o < os.length; o++) {
      for (int r = 0; r < coopHeight; r++) {
        for (int col = 0; col < coopWidth; col++) {
          if (coopCanPlace(s.board, os[o], r, col)) {
            return (id: piece.id, orient: o, r: r, c: col);
          }
        }
      }
    }
  }
  return null;
}

void main() {
  test('новая игра: ход игрока 0, у обоих рука из 3 фигур', () {
    final c = _c();
    final vm = c.read(coopProvider.notifier);
    vm.newGame(777);
    final s = c.read(coopProvider);
    expect(s.current, 0);
    expect(s.gameOver, isFalse);
    expect(s.players[0].hand.length, coopHandSize);
    expect(s.players[1].hand.length, coopHandSize);
  });

  test('детерминизм: тот же seed → те же руки', () {
    final c1 = _c();
    final c2 = _c();
    c1.read(coopProvider.notifier).newGame(42);
    c2.read(coopProvider.notifier).newGame(42);
    final a = c1.read(coopProvider);
    final b = c2.read(coopProvider);
    expect(a.players[0].hand.map((p) => p.type).toList(),
        b.players[0].hand.map((p) => p.type).toList());
    expect(a.players[1].hand.map((p) => p.type).toList(),
        b.players[1].hand.map((p) => p.type).toList());
  });

  test('постановка переключает ход и пополняет руку', () {
    final c = _c();
    final vm = c.read(coopProvider.notifier);
    vm.newGame(5);
    final firstId = c.read(coopProvider).players[0].hand.first.id;
    vm.selectPiece(firstId);
    expect(c.read(coopProvider).selectedPieceId, firstId);
    // Нормализованная фигура всегда встаёт в (0,0) на пустом поле.
    expect(c.read(coopProvider).canPlaceAt(0, 0), isTrue);
    vm.placeAt(0, 0);
    final after = c.read(coopProvider);
    expect(after.current, 1, reason: 'ход перешёл');
    expect(after.selectedPieceId, isNull);
    expect(after.players[0].hand.length, coopHandSize,
        reason: 'рука пополнена');
    var filled = 0;
    for (final row in after.board) {
      for (final cell in row) {
        if (cell.filled) filled++;
      }
    }
    expect(filled, 4);
  });

  test('снятие выбора очищает выбранную фигуру', () {
    final c = _c();
    final vm = c.read(coopProvider.notifier);
    vm.newGame(9);
    vm.selectPiece(c.read(coopProvider).players[0].hand.first.id);
    expect(c.read(coopProvider).selectedPieceId, isNotNull);
    vm.deselect();
    expect(c.read(coopProvider).selectedPieceId, isNull);
  });

  test('поворот меняет ориентацию выбранной фигуры', () {
    final c = _c();
    final vm = c.read(coopProvider.notifier);
    vm.newGame(9);
    vm.selectPiece(c.read(coopProvider).players[0].hand.first.id);
    final before = c.read(coopProvider).orientIndex;
    vm.rotate();
    expect(c.read(coopProvider).orientIndex, before + 1);
  });

  test('невалидная постановка отвергается', () {
    final c = _c();
    final vm = c.read(coopProvider.notifier);
    vm.newGame(3);
    // Без выбора фигуры постановка ничего не делает.
    vm.placeAt(0, 0);
    final s = c.read(coopProvider);
    expect(s.current, 0);
    var filled = 0;
    for (final row in s.board) {
      for (final cell in row) {
        if (cell.filled) filled++;
      }
    }
    expect(filled, 0);
  });

  test('симуляция партии: очки начисляются, партия сходится к тупику', () {
    final c = _c();
    final vm = c.read(coopProvider.notifier);
    vm.newGame(2026);
    var sawClear = false;
    var guard = 0;
    while (!c.read(coopProvider).gameOver && guard < 2000) {
      guard++;
      final s = c.read(coopProvider);
      // Инвариант: пока играем — у текущего рука из 3 фигур.
      expect(s.currentPlayer.hand.length, coopHandSize);
      final move = _firstMove(s);
      expect(move, isNotNull, reason: 'не gameOver → ход обязан быть');
      vm.selectPiece(move!.id);
      for (int i = 0; i < move.orient; i++) {
        vm.rotate();
      }
      vm.placeAt(move.r, move.c);
      if (c.read(coopProvider).lastGain > 0) sawClear = true;
    }
    final end = c.read(coopProvider);
    expect(end.gameOver, isTrue, reason: 'партия завершилась тупиком');
    expect(end.players[0].score, greaterThanOrEqualTo(0));
    expect(end.players[1].score, greaterThanOrEqualTo(0));
    expect(sawClear, isTrue,
        reason: 'за партию хотя бы раз очистилась строка с очками');
  });
}
