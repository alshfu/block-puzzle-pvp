/// online_pilot_test.dart — тесты онлайн-пилота (OnlineGameNotifier.pilotPlayTurn).
///
/// Через FakeTransport проверяем: пилот в свой ход выбирает фигуру из руки,
/// шлёт валидный `move` (клетки — ровно одна из ориентаций ядра, т.е. проходит
/// серверный anti-cheat по построению) и возвращает true; в чужой ход и до
/// `joined` ничего не делает и возвращает false.
library;

import 'package:block_duel/core/core.dart'
    show Coord, PieceType, normalize, orientations;
import 'package:block_duel/online/online_game_notifier.dart';
import 'package:block_duel/online/online_match_state.dart';
import 'package:block_duel/online/online_models.dart';
import 'package:block_duel/online/transport_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';
import 'online_samples.dart';

const _me = OnlineProfile(id: 'u-me', nick: 'Я', avatar: '🙂');
const _args = OnlineMatchArgs(roomId: 'm_pilot', me: _me);

(ProviderContainer, FakeTransport) _setup() {
  final fake = FakeTransport();
  final c = ProviderContainer(
    overrides: [transportFactoryProvider.overrideWithValue((uri) => fake)],
  );
  addTearDown(c.dispose);
  c.read(onlineGameProvider(_args));
  return (c, fake);
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('pilotPlayTurn в свой ход шлёт валидный move и возвращает true',
      () async {
    final (c, fake) = _setup();
    fake.emit({'type': 'joined', 'you': 0, 'state': sampleStateJson()});
    await _tick();

    final vm = c.read(onlineGameProvider(_args).notifier);
    expect(vm.pilotPlayTurn(), isTrue);

    final move = fake.sent.firstWhere((m) => m['type'] == 'move');
    // Фигура — из руки игрока 0 (образец: p0/T, p1/I).
    final pieceId = move['pieceId'] as String;
    expect(['p0', 'p1'], contains(pieceId));

    // Anti-cheat по построению: нормализованные клетки — одна из легальных
    // ориентаций типа фигуры (rotation+flip включены в sampleCfgJson).
    final type = pieceId == 'p0' ? PieceType.t : PieceType.i;
    final cells = normalize([
      for (final c2 in move['cells'] as List)
        Coord((c2 as List)[0] as int, c2[1] as int),
    ]);
    final legal = orientations(type, true, true);
    bool same(List<Coord> a, List<Coord> b) =>
        a.length == b.length &&
        [for (int i = 0; i < a.length; i++) a[i].r == b[i].r && a[i].c == b[i].c]
            .every((x) => x);
    expect(legal.any((o) => same(o, cells)), isTrue);

    // Выбор показан в состоянии (как у живого игрока).
    expect(c.read(onlineGameProvider(_args)).selectedPieceId, pieceId);
  });

  test('pilotPlayTurn в чужой ход — false и без move', () async {
    final (c, fake) = _setup();
    // Мы — игрок 1, а ходит игрок 0.
    fake.emit({'type': 'joined', 'you': 1, 'state': sampleStateJson()});
    await _tick();

    final vm = c.read(onlineGameProvider(_args).notifier);
    expect(vm.pilotPlayTurn(), isFalse);
    expect(fake.sent.where((m) => m['type'] == 'move'), isEmpty);
  });

  test('pilotPlayTurn до joined — false', () async {
    final (c, _) = _setup();
    final vm = c.read(onlineGameProvider(_args).notifier);
    expect(vm.pilotPlayTurn(), isFalse);
  });
}
