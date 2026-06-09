/// leaderboard_notifier.dart — ViewModel таблицы лидеров (MVVM, ViewModel).
///
/// За что отвечает файл:
///   Подключается к leaderboard-«партии» Node-сервера, подписывается на
///   обновления (`subscribe` со своим id) и редьюсит `snapshot` (топ + своя
///   запись + ранг) в [LeaderboardState]. Без BuildContext.
///
/// Соответствие TS: `src/ui/online/client.ts` (openLeaderboard) +
/// `LeaderboardScreen`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'online_models.dart';
import 'party_host.dart';
import 'transport.dart';
import 'transport_provider.dart';

/// Состояние таблицы лидеров.
class LeaderboardState {
  /// Есть ли соединение.
  final bool connected;

  /// Топ игроков (по ELO).
  final List<LeaderboardEntry> entries;

  /// Своя запись (если найдена).
  final LeaderboardEntry? you;

  /// Свой ранг (1-индексный), даже вне топа.
  final int? yourRank;

  /// Всего игроков в таблице.
  final int total;

  const LeaderboardState({
    this.connected = false,
    this.entries = const [],
    this.you,
    this.yourRank,
    this.total = 0,
  });
}

/// ViewModel таблицы лидеров. [myId] — id для подсветки своей строки/ранга.
class LeaderboardNotifier extends Notifier<LeaderboardState> {
  /// Id текущего игрока (или null — без своего ранга).
  final String? myId;

  ITransport? _transport;

  /// Создаёт ViewModel для игрока [myId].
  LeaderboardNotifier(this.myId);

  @override
  LeaderboardState build() {
    ref.onDispose(() => _transport?.close());
    _connect();
    return const LeaderboardState();
  }

  void _connect() {
    final factory = ref.read(transportFactoryProvider);
    final transport = factory(partyUriLeaderboard());
    _transport = transport;
    transport.incoming.listen(_onMessage);
    transport.status.listen((s) {
      if (s == TransportStatus.open) {
        state = LeaderboardState(
          connected: true,
          entries: state.entries,
          you: state.you,
          yourRank: state.yourRank,
          total: state.total,
        );
        transport.send({'type': 'subscribe', 'myId': myId});
      } else if (s == TransportStatus.closed) {
        state = LeaderboardState(
          connected: false,
          entries: state.entries,
          you: state.you,
          yourRank: state.yourRank,
          total: state.total,
        );
      }
    });
  }

  void _onMessage(Map<String, dynamic> msg) {
    if (msg['type'] != 'snapshot') return;
    state = LeaderboardState(
      connected: true,
      entries: [
        for (final e in msg['top'] as List<dynamic>)
          LeaderboardEntry.fromJson(e as Map<String, dynamic>),
      ],
      you: msg['you'] == null
          ? null
          : LeaderboardEntry.fromJson(msg['you'] as Map<String, dynamic>),
      yourRank: (msg['yourRank'] as num?)?.toInt(),
      total: (msg['totalPlayers'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Провайдер ViewModel таблицы лидеров (семейство по id игрока).
final leaderboardProvider =
    NotifierProvider.family<LeaderboardNotifier, LeaderboardState, String?>(
      LeaderboardNotifier.new,
    );
