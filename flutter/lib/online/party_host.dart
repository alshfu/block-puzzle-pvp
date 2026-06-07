/// party_host.dart — адрес WS-сервера онлайна (единственный источник URL).
///
/// За что отвечает файл:
///   Хранит хост PartyKit-совместимого Node-сервера и строит WS-URL вида
///   `ws://<host>/parties/<party>/<room>` (party ∈ lobby/room/leaderboard).
///   Хост задаётся при сборке через `--dart-define=PARTY_HOST=...` (аналог
///   `VITE_PARTY_HOST` в TS); дефолт — локальный dev-сервер.
///
/// Соответствие TS: `src/ui/online/client.ts` (PARTY_HOST + URL-сборка).
library;

/// Хост сервера (host:port). Переопределяется `--dart-define=PARTY_HOST=...`.
/// Должен быть `const` — иначе `String.fromEnvironment` не подставит значение.
const String partyHost = String.fromEnvironment(
  'PARTY_HOST',
  defaultValue: 'localhost:1999',
);

/// Использовать ли TLS (`wss`). Включается `--dart-define=PARTY_TLS=true` для
/// проды за HTTPS; по умолчанию `ws` для локального dev.
const bool partyTls = bool.fromEnvironment('PARTY_TLS', defaultValue: false);

/// Строит WS-URL комнаты [room] в «партии» [party]. Для lobby/leaderboard
/// [room] — литерал `'main'`.
Uri partyUri(String party, String room) {
  final scheme = partyTls ? 'wss' : 'ws';
  return Uri.parse('$scheme://$partyHost/parties/$party/$room');
}

/// URL лобби (матчмейкинг).
Uri partyUriLobby() => partyUri('lobby', 'main');

/// URL игровой комнаты [roomId].
Uri partyUriRoom(String roomId) => partyUri('room', roomId);

/// URL лидерборда.
Uri partyUriLeaderboard() => partyUri('leaderboard', 'main');
