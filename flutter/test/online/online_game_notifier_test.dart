/// online_game_notifier_test.dart — тесты ViewModel онлайн-матча (мок-транспорт).
///
/// Через FakeTransport проверяем: на open шлётся `hello`; `joined`/`state`/
/// `move_rejected`/`opponent_left`/`rematch_status` дают верный
/// OnlineMatchState; `placeAt` шлёт корректный `move`.
library;

import 'package:block_duel/online/online_game_notifier.dart';
import 'package:block_duel/online/online_match_state.dart';
import 'package:block_duel/online/online_models.dart';
import 'package:block_duel/online/transport.dart';
import 'package:block_duel/online/transport_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';
import 'online_samples.dart';

const _me = OnlineProfile(id: 'u-me', nick: 'Я', avatar: '🙂');
const _args = OnlineMatchArgs(roomId: 'm_1', me: _me);

(ProviderContainer, FakeTransport) _setup() {
  final fake = FakeTransport();
  final c = ProviderContainer(
    overrides: [transportFactoryProvider.overrideWithValue((uri) => fake)],
  );
  addTearDown(c.dispose);
  // Чтение строит нотифайер → _connect → подписки на fake.
  c.read(onlineGameProvider(_args));
  return (c, fake);
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('на open шлёт hello с профилем', () async {
    final (_, fake) = _setup();
    fake.emitStatus(TransportStatus.open);
    await _tick();
    expect(fake.sent.single['type'], 'hello');
    expect((fake.sent.single['profile'] as Map)['id'], 'u-me');
  });

  test('joined → game/you/connected', () async {
    final (c, fake) = _setup();
    fake.emit({'type': 'joined', 'you': 1, 'state': sampleStateJson()});
    await _tick();
    final s = c.read(onlineGameProvider(_args));
    expect(s.you, 1);
    expect(s.connected, isTrue);
    expect(s.game, isNotNull);
    expect(s.game!.players[0].nick, 'Алиса');
  });

  test('state → moveSeq++, lastMoveOwner/gained/perfect', () async {
    final (c, fake) = _setup();
    fake.emit({'type': 'joined', 'you': 0, 'state': sampleStateJson()});
    await _tick();
    fake.emit({
      'type': 'state',
      'state': sampleStateJson(current: 1),
      'lastMoveOwner': 0,
      'gained': 30,
      'perfect': true,
    });
    await _tick();
    final s = c.read(onlineGameProvider(_args));
    expect(s.moveSeq, 1);
    expect(s.lastMoveOwner, 0);
    expect(s.lastGained, 30);
    expect(s.lastPerfect, isTrue);
    expect(s.game!.current, 1);
  });

  test('move_rejected → rejectSeq++ и lastError', () async {
    final (c, fake) = _setup();
    fake.emit({'type': 'joined', 'you': 0, 'state': sampleStateJson()});
    await _tick();
    fake.emit({'type': 'move_rejected', 'reason': 'not your turn'});
    await _tick();
    final s = c.read(onlineGameProvider(_args));
    expect(s.rejectSeq, 1);
    expect(s.lastError, 'not your turn');
  });

  test('opponent_left / reconnected', () async {
    final (c, fake) = _setup();
    fake.emit({'type': 'joined', 'you': 0, 'state': sampleStateJson()});
    await _tick();
    fake.emit({'type': 'opponent_left', 'willTimeoutMs': 30000});
    await _tick();
    expect(c.read(onlineGameProvider(_args)).opponentLeft, isTrue);
    expect(c.read(onlineGameProvider(_args)).opponentTimeoutMs, 30000);
    fake.emit({'type': 'opponent_reconnected'});
    await _tick();
    expect(c.read(onlineGameProvider(_args)).opponentLeft, isFalse);
  });

  test('rematch_status', () async {
    final (c, fake) = _setup();
    fake.emit({'type': 'rematch_status', 'yours': true, 'theirs': false});
    await _tick();
    final s = c.read(onlineGameProvider(_args));
    expect(s.rematchYours, isTrue);
    expect(s.rematchTheirs, isFalse);
  });

  test('placeAt шлёт move с нормализованными клетками', () async {
    final (c, fake) = _setup();
    fake.emit({'type': 'joined', 'you': 0, 'state': sampleStateJson()});
    await _tick();
    final vm = c.read(onlineGameProvider(_args).notifier);
    vm.selectPiece('p0'); // T-фигура в руке игрока 0 (его ход)
    vm.placeAt(0, 0);
    final move = fake.sent.firstWhere((m) => m['type'] == 'move');
    expect(move['pieceId'], 'p0');
    expect(move['r'], 0);
    expect(move['c'], 0);
    expect(move['cells'], isA<List<dynamic>>());
    expect((move['cells'] as List).first, isA<List<dynamic>>());
  });

  test('on closed → connected=false', () async {
    final (c, fake) = _setup();
    fake.emit({'type': 'joined', 'you': 0, 'state': sampleStateJson()});
    await _tick();
    fake.emitStatus(TransportStatus.closed);
    await _tick();
    expect(c.read(onlineGameProvider(_args)).connected, isFalse);
  });
}
