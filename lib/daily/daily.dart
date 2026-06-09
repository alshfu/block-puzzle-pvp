/// daily.dart — модель ежедневных квестов (Model-слой).
///
/// За что отвечает файл:
///   Описывает ежедневный квест (метрика, цель, награда) и состояние дня
///   ([DailyState]: какие квесты выбраны, прогресс, что получено). Выбор квестов
///   детерминирован по дате (одинаков весь день). Чистые функции выбора/счёта —
///   тестируемы без часов.
///
/// Соответствие TS: `src/ui/daily/{definitions.ts,engine.ts}`.
library;

/// Метрика, по которой засчитывается прогресс квеста.
enum DailyMetric {
  /// Сыграно партий за день.
  gamesPlayed,

  /// Побед за день.
  wins,

  /// Монет заработано за день.
  coinsEarned,
}

/// Определение ежедневного квеста.
class DailyQuest {
  /// Уникальный id.
  final String id;

  /// Заголовок.
  final String title;

  /// Эмодзи-иконка.
  final String icon;

  /// Метрика прогресса.
  final DailyMetric metric;

  /// Цель (сколько нужно).
  final int target;

  /// Награда в монетах за выполнение.
  final int reward;

  /// Создаёт квест.
  const DailyQuest({
    required this.id,
    required this.title,
    required this.icon,
    required this.metric,
    required this.target,
    required this.reward,
  });
}

/// Пул возможных ежедневных квестов (из него выбираются 3 на день).
const List<DailyQuest> dailyPool = [
  DailyQuest(
    id: 'play_3',
    title: 'Сыграй 3 партии',
    icon: '🎮',
    metric: DailyMetric.gamesPlayed,
    target: 3,
    reward: 20,
  ),
  DailyQuest(
    id: 'play_5',
    title: 'Сыграй 5 партий',
    icon: '🕹️',
    metric: DailyMetric.gamesPlayed,
    target: 5,
    reward: 35,
  ),
  DailyQuest(
    id: 'win_1',
    title: 'Выиграй партию',
    icon: '🏅',
    metric: DailyMetric.wins,
    target: 1,
    reward: 25,
  ),
  DailyQuest(
    id: 'win_3',
    title: 'Выиграй 3 партии',
    icon: '🥇',
    metric: DailyMetric.wins,
    target: 3,
    reward: 50,
  ),
  DailyQuest(
    id: 'coins_50',
    title: 'Заработай 50 монет',
    icon: '🪙',
    metric: DailyMetric.coinsEarned,
    target: 50,
    reward: 15,
  ),
];

/// Сколько квестов на день.
const int dailyQuestCount = 3;

/// Ищет квест в пуле по id.
DailyQuest? questById(String id) {
  for (final q in dailyPool) {
    if (q.id == id) return q;
  }
  return null;
}

/// Детерминированно выбирает [dailyQuestCount] квестов по ключу дня [dayKey]
/// (одинаков весь день). Перемешивает пул простым date-seeded порядком.
List<DailyQuest> pickQuestsForDay(String dayKey) {
  var seed = 0;
  for (final code in dayKey.codeUnits) {
    seed = (seed * 31 + code) & 0x7fffffff;
  }
  final pool = [...dailyPool];
  // Перетасовка Фишера–Йетса с детерминированным LCG от seed.
  var s = seed == 0 ? 1 : seed;
  for (int i = pool.length - 1; i > 0; i--) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    final j = s % (i + 1);
    final tmp = pool[i];
    pool[i] = pool[j];
    pool[j] = tmp;
  }
  return pool.take(dailyQuestCount).toList();
}

/// Прирост метрики за одну сыгранную партию.
class DailyGameEvent {
  /// Победа ли.
  final bool won;

  /// Сколько монет заработано в партии.
  final int coinsEarned;

  /// Создаёт событие партии.
  const DailyGameEvent({required this.won, required this.coinsEarned});

  /// Возвращает прирост для метрики [metric].
  int deltaFor(DailyMetric metric) => switch (metric) {
    DailyMetric.gamesPlayed => 1,
    DailyMetric.wins => won ? 1 : 0,
    DailyMetric.coinsEarned => coinsEarned,
  };
}

/// Состояние ежедневных квестов на конкретный день.
class DailyState {
  /// Ключ дня (`yyyy-mm-dd`).
  final String dayKey;

  /// Id выбранных на сегодня квестов.
  final List<String> questIds;

  /// Прогресс по id квеста.
  final Map<String, int> progress;

  /// Id квестов, награда за которые получена.
  final Set<String> claimed;

  /// Создаёт состояние дня.
  const DailyState({
    required this.dayKey,
    required this.questIds,
    required this.progress,
    required this.claimed,
  });

  /// Свежее состояние для дня [dayKey] (квесты выбраны, прогресс нулевой).
  factory DailyState.fresh(String dayKey) {
    final quests = pickQuestsForDay(dayKey);
    return DailyState(
      dayKey: dayKey,
      questIds: [for (final q in quests) q.id],
      progress: {for (final q in quests) q.id: 0},
      claimed: {},
    );
  }

  /// Копия с изменениями.
  DailyState copyWith({Map<String, int>? progress, Set<String>? claimed}) =>
      DailyState(
        dayKey: dayKey,
        questIds: questIds,
        progress: progress ?? this.progress,
        claimed: claimed ?? this.claimed,
      );

  /// JSON-представление.
  Map<String, dynamic> toJson() => {
    'dayKey': dayKey,
    'questIds': questIds,
    'progress': progress,
    'claimed': claimed.toList(),
  };

  /// Восстанавливает из JSON.
  factory DailyState.fromJson(Map<String, dynamic> json) => DailyState(
    dayKey: json['dayKey'] as String,
    questIds: (json['questIds'] as List<dynamic>).cast<String>(),
    progress: (json['progress'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as int),
    ),
    claimed: (json['claimed'] as List<dynamic>).cast<String>().toSet(),
  );
}
