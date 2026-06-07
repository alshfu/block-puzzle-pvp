/// online_models.dart — DTO онлайна без аналога в ядре (Model-слой).
///
/// За что отвечает файл:
///   Описывает структуры, которыми обмениваются клиент и сервер и которых нет в
///   игровом ядре: профиль игрока в онлайне, представление игрока/состояния
///   матча, результат, запись лидерборда, запрашиваемый cfg. Парсинг из JSON
///   опирается на [online_wire.dart]; ядро остаётся чистым.
///
/// Соответствие TS: `party/protocol.ts` (OnlineProfile/OnlinePlayerView/
/// OnlineGameState/LeaderboardEntry/RequestedCfg).
library;

import 'package:block_duel/core/core.dart';

import '../profile/profile.dart';
import 'online_wire.dart';

/// Профиль игрока в онлайне (стабильный id + ник + аватар).
class OnlineProfile {
  /// Стабильный UUID игрока (генерится клиентом один раз).
  final String id;

  /// Никнейм.
  final String nick;

  /// Эмодзи-аватар.
  final String avatar;

  /// Создаёт профиль.
  const OnlineProfile({
    required this.id,
    required this.nick,
    required this.avatar,
  });

  /// Профиль из локального [Profile] (для очереди/комнаты/лидерборда).
  factory OnlineProfile.fromProfile(Profile p) =>
      OnlineProfile(id: p.id, nick: p.nick, avatar: p.avatar);

  /// JSON-представление (поле `profile` в сообщениях).
  Map<String, dynamic> toJson() => {'id': id, 'nick': nick, 'avatar': avatar};

  /// Восстанавливает из JSON.
  factory OnlineProfile.fromJson(Map<String, dynamic> json) => OnlineProfile(
    id: json['id'] as String,
    nick: json['nick'] as String,
    avatar: json['avatar'] as String,
  );
}

/// Представление игрока в состоянии матча (с сервера).
class OnlinePlayerView {
  final String id;
  final String nick;
  final String avatar;
  final int score;
  final int combo;
  final List<PieceInstance> hand;

  const OnlinePlayerView({
    required this.id,
    required this.nick,
    required this.avatar,
    required this.score,
    required this.combo,
    required this.hand,
  });

  factory OnlinePlayerView.fromJson(Map<String, dynamic> json) =>
      OnlinePlayerView(
        id: json['id'] as String,
        nick: json['nick'] as String,
        avatar: json['avatar'] as String,
        score: (json['score'] as num).toInt(),
        combo: (json['combo'] as num).toInt(),
        hand: [
          for (final p in json['hand'] as List<dynamic>)
            pieceInstanceFromJson(p as Map<String, dynamic>),
        ],
      );
}

/// Результат завершённого матча.
class OnlineResult {
  /// Победитель: 0 / 1 — индекс в players; -1 — ничья.
  final int winner;

  /// Итоговые очки [score0, score1].
  final List<int> scores;

  /// Причина окончания: deadlock / timeout / resign (может отсутствовать).
  final String? reason;

  const OnlineResult({required this.winner, required this.scores, this.reason});

  factory OnlineResult.fromJson(Map<String, dynamic> json) => OnlineResult(
    winner: (json['winner'] as num).toInt(),
    scores: [
      for (final s in json['scores'] as List<dynamic>) (s as num).toInt(),
    ],
    reason: json['reason'] as String?,
  );
}

/// Полное состояние онлайн-матча, присылаемое сервером.
class OnlineGameState {
  final String matchId;
  final Board board;
  final List<OnlinePlayerView> players;
  final int current;
  final int turnCount;

  /// `"playing"` или `"over"`.
  final String status;
  final OnlineResult? result;
  final List<Coord>? lastClearedCells;
  final int turnTimeRemainingMs;
  final int turnTimeBaseMs;
  final RuleConfig cfg;

  const OnlineGameState({
    required this.matchId,
    required this.board,
    required this.players,
    required this.current,
    required this.turnCount,
    required this.status,
    required this.turnTimeRemainingMs,
    required this.turnTimeBaseMs,
    required this.cfg,
    this.result,
    this.lastClearedCells,
  });

  /// Завершён ли матч.
  bool get isOver => status == 'over';

  factory OnlineGameState.fromJson(Map<String, dynamic> json) =>
      OnlineGameState(
        matchId: json['matchId'] as String,
        board: boardFromJson(json['board'] as List<dynamic>),
        players: [
          for (final p in json['players'] as List<dynamic>)
            OnlinePlayerView.fromJson(p as Map<String, dynamic>),
        ],
        current: (json['current'] as num).toInt(),
        turnCount: (json['turnCount'] as num).toInt(),
        status: json['status'] as String,
        result: json['result'] == null
            ? null
            : OnlineResult.fromJson(json['result'] as Map<String, dynamic>),
        lastClearedCells: json['lastClearedCells'] == null
            ? null
            : [
                for (final c in json['lastClearedCells'] as List<dynamic>)
                  coordFromJson(c as List<dynamic>),
              ],
        turnTimeRemainingMs: (json['turnTimeRemainingMs'] as num).toInt(),
        turnTimeBaseMs: (json['turnTimeBaseMs'] as num).toInt(),
        cfg: ruleConfigFromJson(json['cfg'] as Map<String, dynamic>),
      );
}

/// Подмножество правил, запрашиваемых клиентом при подключении (только первый
/// игрок влияет на cfg; null-поля опускаются).
class RequestedCfg {
  final int? handSize;
  final bool? rotationEnabled;
  final bool? flipEnabled;

  const RequestedCfg({this.handSize, this.rotationEnabled, this.flipEnabled});

  /// JSON без null-полей.
  Map<String, dynamic> toJson() => {
    if (handSize != null) 'handSize': handSize,
    if (rotationEnabled != null) 'rotationEnabled': rotationEnabled,
    if (flipEnabled != null) 'flipEnabled': flipEnabled,
  };
}

/// Запись таблицы лидеров (ELO).
class LeaderboardEntry {
  final String id;
  final String nick;
  final String avatar;
  final int elo;
  final int wins;
  final int losses;
  final int draws;
  final int updatedAt;

  const LeaderboardEntry({
    required this.id,
    required this.nick,
    required this.avatar,
    required this.elo,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.updatedAt,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        id: json['id'] as String,
        nick: json['nick'] as String,
        avatar: json['avatar'] as String,
        elo: (json['elo'] as num).toInt(),
        wins: (json['wins'] as num).toInt(),
        losses: (json['losses'] as num).toInt(),
        draws: (json['draws'] as num).toInt(),
        updatedAt: (json['updatedAt'] as num).toInt(),
      );
}
