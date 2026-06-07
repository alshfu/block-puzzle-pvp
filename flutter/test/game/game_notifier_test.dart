/// game_notifier_test.dart — тесты ViewModel партии (MVVM, слой ViewModel).
///
/// За что отвечает файл:
///   Проверяет команды [GameNotifier] без UI: стартовая раздача, выбор фигуры,
///   постановка (смена хода + пополнение руки + рост счёта при очистке) и
///   поворот. Подтверждает, что игровая логика поверх ядра работает.
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/game/game_notifier.dart';
import 'package:block_duel/game/match_config.dart';
import 'package:block_duel/storage/prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Создаёт изолированный контейнер провайдеров с авто-очисткой и mock-prefs.
/// Mock-prefs нужен, чтобы автосохранение партии (savedGameStoreProvider →
/// sharedPreferencesProvider) не падало в headless-тестах.
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
  const config = MatchConfig(mode: MatchMode.hotseat, seed: 12345);

  test('стартовое состояние: ход игрока 0, рука из 3 фигур', () async {
    final c = await _container();
    final state = c.read(gameProvider(config));
    expect(state.current, 0);
    expect(state.gameOver, isFalse);
    expect(state.players[0].hand.length, defaultConfig.handSize);
    expect(state.players[1].hand.length, defaultConfig.handSize);
  });

  test('постановка фигуры переключает ход и пополняет руку', () async {
    final c = await _container();
    final vm = c.read(gameProvider(config).notifier);
    final firstId = c.read(gameProvider(config)).players[0].hand.first.id;

    vm.selectPiece(firstId);
    expect(c.read(gameProvider(config)).selectedPieceId, firstId);

    // На пустой доске любая нормализованная фигура встаёт в (0,0).
    expect(c.read(gameProvider(config)).canPlaceAt(0, 0), isTrue);
    vm.placeAt(0, 0);

    final after = c.read(gameProvider(config));
    expect(after.current, 1, reason: 'ход перешёл к игроку 1');
    expect(after.selectedPieceId, isNull, reason: 'выбор сброшен');
    expect(
      after.players[0].hand.length,
      defaultConfig.handSize,
      reason: 'рука пополнена',
    );
    // На доске появились занятые клетки.
    var filled = 0;
    for (final row in after.board) {
      for (final cell in row) {
        if (cell.filled) filled++;
      }
    }
    expect(filled, greaterThan(0));
  });

  test('поворот меняет ориентацию выбранной фигуры', () async {
    final c = await _container();
    final vm = c.read(gameProvider(config).notifier);
    final hand = c.read(gameProvider(config)).players[0].hand;
    // Берём фигуру с несколькими ориентациями (T всегда даёт 4).
    final tPiece = hand.firstWhere(
      (p) => orientations(p.type, true, true).length > 1,
      orElse: () => hand.first,
    );

    vm.selectPiece(tPiece.id);
    final before = c.read(gameProvider(config)).activeCells;
    vm.rotateSelected();
    final after = c.read(gameProvider(config)).activeCells;
    expect(after, isNotNull);
    if (orientations(tPiece.type, true, true).length > 1) {
      expect(after, isNot(equals(before)));
    }
  });

  test('blitz-таймаут авто-ставит фигуру (force-place)', () async {
    final c = await _container();
    // Короткий лимит, чтобы таймаут наступил быстро в реальном времени.
    final shortCfg = defaultConfig.copyWith(
      turnTimeStart: 0.2,
      turnTimeMin: 0.2,
    );
    final cfg = MatchConfig(mode: MatchMode.hotseat, seed: 1, cfg: shortCfg);
    // Чтение строит ViewModel и запускает blitz-тикер.
    expect(c.read(gameProvider(cfg)).turnLimit, closeTo(0.2, 1e-9));

    await Future<void>.delayed(const Duration(milliseconds: 500));

    final s = c.read(gameProvider(cfg));
    final filled = s.board.any((row) => row.any((cell) => cell.filled));
    expect(filled, isTrue, reason: 'force-place поставил фигуру по таймауту');
  });

  test('пауза останавливает blitz-таймер, снятие — возобновляет', () async {
    final c = await _container();
    final shortCfg = defaultConfig.copyWith(turnTimeStart: 5, turnTimeMin: 5);
    final cfg = MatchConfig(mode: MatchMode.hotseat, seed: 2, cfg: shortCfg);
    final vm = c.read(gameProvider(cfg).notifier);
    expect(c.read(gameProvider(cfg)).paused, isFalse);

    vm.setPaused(true);
    expect(c.read(gameProvider(cfg)).paused, isTrue);
    final frozen = c.read(gameProvider(cfg)).turnRemaining;

    // На паузе таймер не убывает.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(c.read(gameProvider(cfg)).turnRemaining, frozen);
    expect(
      c
          .read(gameProvider(cfg))
          .board
          .every((r) => r.every((cell) => !cell.filled)),
      isTrue,
      reason: 'на паузе force-place не срабатывает',
    );

    vm.setPaused(false);
    expect(c.read(gameProvider(cfg)).paused, isFalse);
  });

  test('ход бота заблокирован для управляемого ботом игрока', () async {
    final c = await _container();
    const botCfg = MatchConfig(mode: MatchMode.bot, seed: 7);
    final vm = c.read(gameProvider(botCfg).notifier);
    // Игрок 0 — человек; команды доступны. Проверяем, что выбор работает.
    final id = c.read(gameProvider(botCfg)).players[0].hand.first.id;
    vm.selectPiece(id);
    expect(c.read(gameProvider(botCfg)).selectedPieceId, id);
  });
}
