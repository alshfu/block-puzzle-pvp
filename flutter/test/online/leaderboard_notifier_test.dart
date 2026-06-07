/// leaderboard_notifier_test.dart — тесты ViewModel таблицы лидеров.
///
/// Через FakeTransport: на open шлётся `subscribe` с myId; `snapshot` даёт
/// entries/you/yourRank/total (поле `totalPlayers`).
library;

import 'package:block_duel/online/leaderboard_notifier.dart';
import 'package:block_duel/online/transport.dart';
import 'package:block_duel/online/transport_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

(ProviderContainer, FakeTransport) _setup() {
  final fake = FakeTransport();
  final c = ProviderContainer(
    overrides: [transportFactoryProvider.overrideWithValue((uri) => fake)],
  );
  addTearDown(c.dispose);
  c.read(leaderboardProvider('u-me'));
  return (c, fake);
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('на open шлёт subscribe с myId', () async {
    final (_, fake) = _setup();
    fake.emitStatus(TransportStatus.open);
    await _tick();
    expect(fake.sent.single, {'type': 'subscribe', 'myId': 'u-me'});
  });

  test('snapshot → entries/you/yourRank/total', () async {
    final (c, fake) = _setup();
    fake.emit({
      'type': 'snapshot',
      'top': [
        {
          'id': 'u-a',
          'nick': 'A',
          'avatar': '🦊',
          'elo': 1200,
          'wins': 10,
          'losses': 2,
          'draws': 1,
          'updatedAt': 1,
        },
        {
          'id': 'u-me',
          'nick': 'Я',
          'avatar': '🙂',
          'elo': 1100,
          'wins': 5,
          'losses': 5,
          'draws': 0,
          'updatedAt': 2,
        },
      ],
      'you': {
        'id': 'u-me',
        'nick': 'Я',
        'avatar': '🙂',
        'elo': 1100,
        'wins': 5,
        'losses': 5,
        'draws': 0,
        'updatedAt': 2,
      },
      'yourRank': 2,
      'totalPlayers': 42,
    });
    await _tick();
    final s = c.read(leaderboardProvider('u-me'));
    expect(s.entries.length, 2);
    expect(s.entries.first.elo, 1200);
    expect(s.you!.id, 'u-me');
    expect(s.yourRank, 2);
    expect(s.total, 42);
  });
}
