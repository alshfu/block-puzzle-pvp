/// achievement.dart — модель достижения, прогресса и статистики (Model-слой).
///
/// За что отвечает файл:
///   Описывает достижение как ЧИСТЫЕ ДАННЫЕ ([AchievementDef]: id/заголовок/
///   описание/иконка/цель/категория/скрытость/награда-XP), прогресс одного
///   достижения ([AchProgress]) и накопительную статистику игрока ([Stats]),
///   по которой движок ([engine.dart]) считает прогресс. Условия не хранятся в
///   достижении — они централизованы в движке (как в TS).
///
/// Соответствие TS: `src/ui/achievements/definitions.ts` (AchievementDef) +
/// `src/ui/storage/stats.ts` (Stats).
library;

/// Категория достижения (для группировки на экране).
enum AchievementCategory { single, progressive, series, hidden, online }

/// Достижение как данные: метаданные + цель прогресса.
class AchievementDef {
  /// Уникальный id (ключ хранилища).
  final String id;

  /// Заголовок.
  final String title;

  /// Описание (как получить).
  final String description;

  /// Эмодзи-иконка.
  final String icon;

  /// Цель прогресса (порог разблокировки).
  final int total;

  /// Скрыто ли до разблокировки.
  final bool hidden;

  /// Категория.
  final AchievementCategory category;

  /// Награда XP за разблокировку.
  final int rewardXp;

  /// Создаёт достижение.
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.total,
    required this.category,
    required this.rewardXp,
    this.hidden = false,
  });
}

/// Прогресс одного достижения.
class AchProgress {
  /// Текущее значение прогресса.
  final int current;

  /// Время разблокировки (мс epoch) или null, если не разблокировано.
  final int? unlockedAt;

  const AchProgress({this.current = 0, this.unlockedAt});

  /// Разблокировано ли.
  bool get unlocked => unlockedAt != null;

  Map<String, dynamic> toJson() => {
    'current': current,
    if (unlockedAt != null) 'unlockedAt': unlockedAt,
  };

  factory AchProgress.fromJson(Map<String, dynamic> json) => AchProgress(
    current: (json['current'] as num?)?.toInt() ?? 0,
    unlockedAt: (json['unlockedAt'] as num?)?.toInt(),
  );
}

/// Накопительная статистика игрока (офлайн + онлайн). Поля, которые ещё не
/// заполняются Flutter-портом, остаются нулевыми (достижения по ним просто
/// заблокированы — как и должно быть).
class Stats {
  // ── Офлайн ──
  final int games;
  final int wins;
  final int losses;
  final int draws;
  final int totalClears;
  final int maxMultiClear;
  final int bestScore;
  final int currentWinStreak;
  final int bestWinStreak;

  // ── Онлайн (часть заполняется в 6A/3b) ──
  final int onlineGames;
  final int onlineWins;
  final int onlineLosses;
  final int onlineDraws;
  final int onlineCurrentWinStreak;
  final int onlineBestWinStreak;
  final int onlineCurrentNoLossStreak;
  final int onlineTotalClears;
  final int onlineTotalPerfects;
  final int onlineMaxRematchWinStreak;
  final int onlineUniqueOpponents;
  final int onlineMostVsSingleOpponent;
  final int onlineConsecutiveDays;
  final List<String> onlineThemesPlayed;

  const Stats({
    this.games = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.totalClears = 0,
    this.maxMultiClear = 0,
    this.bestScore = 0,
    this.currentWinStreak = 0,
    this.bestWinStreak = 0,
    this.onlineGames = 0,
    this.onlineWins = 0,
    this.onlineLosses = 0,
    this.onlineDraws = 0,
    this.onlineCurrentWinStreak = 0,
    this.onlineBestWinStreak = 0,
    this.onlineCurrentNoLossStreak = 0,
    this.onlineTotalClears = 0,
    this.onlineTotalPerfects = 0,
    this.onlineMaxRematchWinStreak = 0,
    this.onlineUniqueOpponents = 0,
    this.onlineMostVsSingleOpponent = 0,
    this.onlineConsecutiveDays = 0,
    this.onlineThemesPlayed = const [],
  });

  /// Снимок по умолчанию.
  static const Stats initial = Stats();

  Stats copyWith({
    int? games,
    int? wins,
    int? losses,
    int? draws,
    int? totalClears,
    int? maxMultiClear,
    int? bestScore,
    int? currentWinStreak,
    int? bestWinStreak,
    int? onlineGames,
    int? onlineWins,
    int? onlineLosses,
    int? onlineDraws,
    int? onlineCurrentWinStreak,
    int? onlineBestWinStreak,
    int? onlineCurrentNoLossStreak,
    int? onlineTotalClears,
    int? onlineTotalPerfects,
    int? onlineMaxRematchWinStreak,
    int? onlineUniqueOpponents,
    int? onlineMostVsSingleOpponent,
    int? onlineConsecutiveDays,
    List<String>? onlineThemesPlayed,
  }) => Stats(
    games: games ?? this.games,
    wins: wins ?? this.wins,
    losses: losses ?? this.losses,
    draws: draws ?? this.draws,
    totalClears: totalClears ?? this.totalClears,
    maxMultiClear: maxMultiClear ?? this.maxMultiClear,
    bestScore: bestScore ?? this.bestScore,
    currentWinStreak: currentWinStreak ?? this.currentWinStreak,
    bestWinStreak: bestWinStreak ?? this.bestWinStreak,
    onlineGames: onlineGames ?? this.onlineGames,
    onlineWins: onlineWins ?? this.onlineWins,
    onlineLosses: onlineLosses ?? this.onlineLosses,
    onlineDraws: onlineDraws ?? this.onlineDraws,
    onlineCurrentWinStreak:
        onlineCurrentWinStreak ?? this.onlineCurrentWinStreak,
    onlineBestWinStreak: onlineBestWinStreak ?? this.onlineBestWinStreak,
    onlineCurrentNoLossStreak:
        onlineCurrentNoLossStreak ?? this.onlineCurrentNoLossStreak,
    onlineTotalClears: onlineTotalClears ?? this.onlineTotalClears,
    onlineTotalPerfects: onlineTotalPerfects ?? this.onlineTotalPerfects,
    onlineMaxRematchWinStreak:
        onlineMaxRematchWinStreak ?? this.onlineMaxRematchWinStreak,
    onlineUniqueOpponents: onlineUniqueOpponents ?? this.onlineUniqueOpponents,
    onlineMostVsSingleOpponent:
        onlineMostVsSingleOpponent ?? this.onlineMostVsSingleOpponent,
    onlineConsecutiveDays: onlineConsecutiveDays ?? this.onlineConsecutiveDays,
    onlineThemesPlayed: onlineThemesPlayed ?? this.onlineThemesPlayed,
  );

  Map<String, dynamic> toJson() => {
    'games': games,
    'wins': wins,
    'losses': losses,
    'draws': draws,
    'totalClears': totalClears,
    'maxMultiClear': maxMultiClear,
    'bestScore': bestScore,
    'currentWinStreak': currentWinStreak,
    'bestWinStreak': bestWinStreak,
    'onlineGames': onlineGames,
    'onlineWins': onlineWins,
    'onlineLosses': onlineLosses,
    'onlineDraws': onlineDraws,
    'onlineCurrentWinStreak': onlineCurrentWinStreak,
    'onlineBestWinStreak': onlineBestWinStreak,
    'onlineCurrentNoLossStreak': onlineCurrentNoLossStreak,
    'onlineTotalClears': onlineTotalClears,
    'onlineTotalPerfects': onlineTotalPerfects,
    'onlineMaxRematchWinStreak': onlineMaxRematchWinStreak,
    'onlineUniqueOpponents': onlineUniqueOpponents,
    'onlineMostVsSingleOpponent': onlineMostVsSingleOpponent,
    'onlineConsecutiveDays': onlineConsecutiveDays,
    'onlineThemesPlayed': onlineThemesPlayed,
  };

  factory Stats.fromJson(Map<String, dynamic> json) {
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    return Stats(
      games: i('games'),
      wins: i('wins'),
      losses: i('losses'),
      draws: i('draws'),
      totalClears: i('totalClears'),
      maxMultiClear: i('maxMultiClear'),
      bestScore: i('bestScore'),
      currentWinStreak: i('currentWinStreak'),
      bestWinStreak: i('bestWinStreak'),
      onlineGames: i('onlineGames'),
      onlineWins: i('onlineWins'),
      onlineLosses: i('onlineLosses'),
      onlineDraws: i('onlineDraws'),
      onlineCurrentWinStreak: i('onlineCurrentWinStreak'),
      onlineBestWinStreak: i('onlineBestWinStreak'),
      onlineCurrentNoLossStreak: i('onlineCurrentNoLossStreak'),
      onlineTotalClears: i('onlineTotalClears'),
      onlineTotalPerfects: i('onlineTotalPerfects'),
      onlineMaxRematchWinStreak: i('onlineMaxRematchWinStreak'),
      onlineUniqueOpponents: i('onlineUniqueOpponents'),
      onlineMostVsSingleOpponent: i('onlineMostVsSingleOpponent'),
      onlineConsecutiveDays: i('onlineConsecutiveDays'),
      onlineThemesPlayed:
          (json['onlineThemesPlayed'] as List<dynamic>?)?.cast<String>() ??
          const [],
    );
  }
}
