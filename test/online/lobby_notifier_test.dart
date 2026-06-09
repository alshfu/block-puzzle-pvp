/// lobby_notifier_test.dart — тесты ViewModel матчмейкинга на мок-транспорте.
///
/// Через FakeTransport проверяем: на открытии шлётся `queue`, входящие
/// `queued/matched/bot_fallback/error` дают верные LobbyState, `cancel` шлёт
/// `cancel` и возвращает в idle.
library;

import 'package:block_duel/online/lobby_notifier.dart';
import 'package:block_duel/online/online_models.dart';
import 'package:block_duel/online/transport.dart';
import 'package:block_duel/online/transport_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

const _me = OnlineProfile(id: 'u-me', nick: 'Я', avatar: '🙂');

(ProviderContainer, FakeTransport) _setup() {
  final fake = FakeTransport();
  final c = ProviderContainer(
    overrides: [transportFactoryProvider.overrideWithValue((uri) => fake)],
  );
  addTearDown(c.dispose);
  return (c, fake);
}

void main() {
  test('старт в idle', () {
    final (c, _) = _setup();
    expect(c.read(lobbyProvider), isA<LobbyIdle>());
  });

  test('queue → на open шлёт {type:queue}', () async {
    final (c, fake) = _setup();
    c.read(lobbyProvider.notifier).queue(_me);
    fake.emitStatus(TransportStatus.open);
    await Future<void>.delayed(Duration.zero); // дать потоку дойти
    expect(fake.sent.single['type'], 'queue');
    expect((fake.sent.single['profile'] as Map)['id'], 'u-me');
  });

  test('queued → LobbyQueued(position, waited)', () async {
    final (c, fake) = _setup();
    c.read(lobbyProvider.notifier).queue(_me);
    fake.emit({'type': 'queued', 'position': 3, 'waitedSec': 12});
    await Future<void>.delayed(Duration.zero);
    final s = c.read(lobbyProvider);
    expect(s, isA<LobbyQueued>());
    expect((s as LobbyQueued).position, 3);
    expect(s.waitedSec, 12);
  });

  test('matched → LobbyMatched(roomId, opponent)', () async {
    final (c, fake) = _setup();
    c.read(lobbyProvider.notifier).queue(_me);
    fake.emit({
      'type': 'matched',
      'roomId': 'm_1',
      'opponent': {'id': 'u-op', 'nick': 'Соп', 'avatar': '🐼'},
    });
    await Future<void>.delayed(Duration.zero);
    final s = c.read(lobbyProvider);
    expect(s, isA<LobbyMatched>());
    expect((s as LobbyMatched).roomId, 'm_1');
    expect(s.opponent.nick, 'Соп');
  });

  test('bot_fallback и error', () async {
    final (c, fake) = _setup();
    c.read(lobbyProvider.notifier).queue(_me);
    fake.emit({'type': 'bot_fallback'});
    await Future<void>.delayed(Duration.zero);
    expect(c.read(lobbyProvider), isA<LobbyBotFallback>());

    fake.emit({'type': 'error', 'reason': 'занято'});
    await Future<void>.delayed(Duration.zero);
    expect((c.read(lobbyProvider) as LobbyError).reason, 'занято');
  });

  test('cancel шлёт {type:cancel} и возвращает в idle', () async {
    final (c, fake) = _setup();
    c.read(lobbyProvider.notifier).queue(_me);
    c.read(lobbyProvider.notifier).cancel();
    expect(fake.sent.any((m) => m['type'] == 'cancel'), isTrue);
    expect(c.read(lobbyProvider), isA<LobbyIdle>());
  });
}
