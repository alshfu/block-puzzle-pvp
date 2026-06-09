/// saved_game.dart — сериализуемый снимок партии для resume (Model-слой).
///
/// За что отвечает файл:
///   Полное состояние партии, достаточное для точного продолжения: режим,
///   доска, игроки с руками, чей ход, таймер и — главное — внутреннее состояние
///   мешков (очередь + счётчик + состояние PRNG). Последнее даёт
///   детерминистичный resume 7-bag без replay по drawCounts.
///
/// Кодировка доски — 81 символ ('.'/'0'/'1'), как в golden-дампе.
///
/// Соответствие TS: `src/ui/storage/saveGame.ts` (snapshot + drawCounts).
library;

import 'package:block_duel/core/core.dart';

import 'match_config.dart';

/// Снимок состояния одного мешка для resume.
class BagSnapshot {
  /// Остаток очереди текущего мешка (имена типов).
  final List<PieceType> queue;

  /// Счётчик выданных фигур (для id).
  final int counter;

  /// Внутреннее состояние PRNG.
  final int rngState;

  /// Создаёт снимок мешка.
  const BagSnapshot({
    required this.queue,
    required this.counter,
    required this.rngState,
  });

  /// Снимает состояние живого [bag].
  factory BagSnapshot.of(Bag bag) => BagSnapshot(
    queue: bag.queueSnapshot,
    counter: bag.counter,
    rngState: bag.rngState,
  );

  /// Воссоздаёт мешок из снимка.
  Bag toBag() =>
      Bag.fromState(queue: queue, counter: counter, rngState: rngState);

  /// JSON-представление.
  Map<String, dynamic> toJson() => {
    'queue': [for (final t in queue) t.name],
    'counter': counter,
    'rngState': rngState,
  };

  /// Восстанавливает снимок из JSON.
  factory BagSnapshot.fromJson(Map<String, dynamic> json) => BagSnapshot(
    queue: [
      for (final t in (json['queue'] as List<dynamic>).cast<String>())
        PieceType.values.byName(t),
    ],
    counter: json['counter'] as int,
    rngState: json['rngState'] as int,
  );
}

/// Снимок игрока в сохранёнке (рука — пары id+тип, клетки выводятся из типа).
class SavedPlayer {
  /// Счёт.
  final int score;

  /// Комбо.
  final int combo;

  /// Имя.
  final String name;

  /// Рука: список (id, тип).
  final List<({String id, PieceType type})> hand;

  /// Создаёт снимок игрока.
  const SavedPlayer({
    required this.score,
    required this.combo,
    required this.name,
    required this.hand,
  });

  /// JSON-представление.
  Map<String, dynamic> toJson() => {
    'score': score,
    'combo': combo,
    'name': name,
    'hand': [
      for (final p in hand) {'id': p.id, 'type': p.type.name},
    ],
  };

  /// Восстанавливает из JSON.
  factory SavedPlayer.fromJson(Map<String, dynamic> json) => SavedPlayer(
    score: json['score'] as int,
    combo: json['combo'] as int,
    name: json['name'] as String,
    hand: [
      for (final h in (json['hand'] as List<dynamic>).cast<Map>())
        (
          id: h['id'] as String,
          type: PieceType.values.byName(h['type'] as String),
        ),
    ],
  );
}

/// Полный снимок партии для сохранения/продолжения.
class SavedGame {
  /// Режим партии.
  final MatchMode mode;

  /// Уровень бота.
  final BotLevel botLevel;

  /// Seed партии (ключ соответствия конфигу при resume).
  final int seed;

  /// Доска, закодированная строкой 81 символ.
  final String board;

  /// Снимки игроков.
  final List<SavedPlayer> players;

  /// Снимки мешков.
  final List<BagSnapshot> bags;

  /// Чей ход.
  final int current;

  /// Номер раунда.
  final int round;

  /// Создаёт снимок партии.
  const SavedGame({
    required this.mode,
    required this.botLevel,
    required this.seed,
    required this.board,
    required this.players,
    required this.bags,
    required this.current,
    required this.round,
  });

  /// JSON-представление.
  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'botLevel': botLevel.name,
    'seed': seed,
    'board': board,
    'players': [for (final p in players) p.toJson()],
    'bags': [for (final b in bags) b.toJson()],
    'current': current,
    'round': round,
  };

  /// Восстанавливает из JSON.
  factory SavedGame.fromJson(Map<String, dynamic> json) => SavedGame(
    mode: MatchMode.values.byName(json['mode'] as String),
    botLevel: BotLevel.values.byName(json['botLevel'] as String),
    seed: json['seed'] as int,
    board: json['board'] as String,
    players: [
      for (final p in (json['players'] as List<dynamic>).cast<Map>())
        SavedPlayer.fromJson(p.cast<String, dynamic>()),
    ],
    bags: [
      for (final b in (json['bags'] as List<dynamic>).cast<Map>())
        BagSnapshot.fromJson(b.cast<String, dynamic>()),
    ],
    current: json['current'] as int,
    round: json['round'] as int,
  );
}

/// Кодирует доску в строку 81 символ ('.'=пусто, '0'/'1'=владелец).
String encodeBoard(Board board) {
  final sb = StringBuffer();
  for (int r = 0; r < boardSize; r++) {
    for (int c = 0; c < boardSize; c++) {
      final cell = board[r][c];
      sb.write(cell.filled ? '${cell.owner ?? 0}' : '.');
    }
  }
  return sb.toString();
}

/// Восстанавливает доску из строковой кодировки.
Board decodeBoard(String encoded) {
  final board = emptyBoard();
  for (int i = 0; i < encoded.length && i < boardSize * boardSize; i++) {
    final ch = encoded[i];
    if (ch == '.') continue;
    board[i ~/ boardSize][i % boardSize] = Cell(
      filled: true,
      owner: int.parse(ch),
    );
  }
  return board;
}
