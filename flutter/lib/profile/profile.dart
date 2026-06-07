/// profile.dart — модель профиля игрока (Model-слой).
///
/// За что отвечает файл:
///   Неизменяемые данные профиля (ник, аватар, XP, монеты, статистика) и
///   производный уровень. (Де)сериализация в JSON для хранилища. Прогрессия
///   уровня — треугольная (ROADMAP §8.2), подробную перебалансировку оставляем
///   на Фазу 8.
///
/// Соответствие TS: `src/ui/storage/profile.ts` + `stats.ts`.
library;

/// XP, требуемый для достижения уровня [level] (треугольная кривая
/// `floor(50·n·(n+1)/2)`). Уровень 1 достигается при 0 XP.
int xpToReachLevel(int level) {
  final n = level - 1;
  return (50 * n * (n + 1) / 2).floor();
}

/// Вычисляет текущий уровень по накопленному [xp] (≥ 1).
int levelForXp(int xp) {
  var level = 1;
  while (xp >= xpToReachLevel(level + 1)) {
    level++;
  }
  return level;
}

/// Неизменяемый профиль игрока.
class Profile {
  /// Никнейм.
  final String nick;

  /// Эмодзи-аватар.
  final String avatar;

  /// Накопленный опыт.
  final int xp;

  /// Монеты (мягкая валюта).
  final int coins;

  /// Сыграно партий.
  final int gamesPlayed;

  /// Побед.
  final int wins;

  /// Стабильный id игрока для онлайна (UUID v4). Пустая строка — ещё не выдан
  /// (генерится лениво в `ProfileController.build`).
  final String id;

  /// Побед в онлайне.
  final int onlineWins;

  /// Поражений в онлайне.
  final int onlineLosses;

  /// Ничьих в онлайне.
  final int onlineDraws;

  /// Создаёт профиль.
  const Profile({
    required this.nick,
    required this.avatar,
    required this.xp,
    required this.coins,
    required this.gamesPlayed,
    required this.wins,
    this.id = '',
    this.onlineWins = 0,
    this.onlineLosses = 0,
    this.onlineDraws = 0,
  });

  /// Профиль по умолчанию для нового игрока.
  static const Profile initial = Profile(
    nick: 'Игрок',
    avatar: '🙂',
    xp: 0,
    coins: 0,
    gamesPlayed: 0,
    wins: 0,
  );

  /// Текущий уровень (производное от [xp]).
  int get level => levelForXp(xp);

  /// XP, накопленный внутри текущего уровня.
  int get xpInLevel => xp - xpToReachLevel(level);

  /// XP, нужный для перехода на следующий уровень (ширина текущего уровня).
  int get xpForNextLevel => xpToReachLevel(level + 1) - xpToReachLevel(level);

  /// Копия с изменёнными полями.
  Profile copyWith({
    String? nick,
    String? avatar,
    int? xp,
    int? coins,
    int? gamesPlayed,
    int? wins,
    String? id,
    int? onlineWins,
    int? onlineLosses,
    int? onlineDraws,
  }) => Profile(
    nick: nick ?? this.nick,
    avatar: avatar ?? this.avatar,
    xp: xp ?? this.xp,
    coins: coins ?? this.coins,
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    wins: wins ?? this.wins,
    id: id ?? this.id,
    onlineWins: onlineWins ?? this.onlineWins,
    onlineLosses: onlineLosses ?? this.onlineLosses,
    onlineDraws: onlineDraws ?? this.onlineDraws,
  );

  /// JSON-представление для хранилища.
  Map<String, dynamic> toJson() => {
    'nick': nick,
    'avatar': avatar,
    'xp': xp,
    'coins': coins,
    'gamesPlayed': gamesPlayed,
    'wins': wins,
    'id': id,
    'onlineWins': onlineWins,
    'onlineLosses': onlineLosses,
    'onlineDraws': onlineDraws,
  };

  /// Восстанавливает профиль из JSON; отсутствующие поля берутся из [initial].
  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    nick: json['nick'] as String? ?? initial.nick,
    avatar: json['avatar'] as String? ?? initial.avatar,
    xp: json['xp'] as int? ?? 0,
    coins: json['coins'] as int? ?? 0,
    gamesPlayed: json['gamesPlayed'] as int? ?? 0,
    wins: json['wins'] as int? ?? 0,
    id: json['id'] as String? ?? '',
    onlineWins: json['onlineWins'] as int? ?? 0,
    onlineLosses: json['onlineLosses'] as int? ?? 0,
    onlineDraws: json['onlineDraws'] as int? ?? 0,
  );
}
