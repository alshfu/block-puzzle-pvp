/// quest.dart — обобщённый движок квестов: недельные и сезонные (Model, pure).
///
/// За что отвечает файл:
///   Расширяет квестовую систему сверх ежедневных (ROADMAP § 8.4): описывает
///   квест с метрикой/целью/наградой и периодом ([QuestPeriod] weekly/seasonal),
///   пулы квестов на период, детерминированный выбор набора по ключу периода,
///   событие итога партии ([QuestEvent]) с дельтами по метрикам и состояние
///   периода ([QuestPeriodState]: набор, прогресс, полученные награды).
///   Ежедневные квесты живут отдельно (`lib/daily/`), здесь — weekly/seasonal.
///   Чистые функции (выбор/счёт) тестируемы без часов; ключи периодов даёт
///   ViewModel.
///
/// Server-side валидация квестов (ROADMAP § 8.4) — серверная надстройка, требует
/// живого бэкенда (🔒), здесь не реализуется.
library;

/// Период квеста.
enum QuestPeriod {
  /// Недельный (сброс раз в 7 дней).
  weekly,

  /// Сезонный (сброс раз в 90 дней).
  seasonal,
}

/// Метрика прогресса квеста.
enum QuestMetric {
  /// Сыграно партий.
  games,

  /// Побед.
  wins,

  /// Очищено линий (строки+столбцы+боксы) суммарно.
  clears,

  /// Матчей с perfect clear.
  perfectClears,

  /// Побед над ботом Hard.
  hardWins,

  /// Побед в онлайне.
  onlineWins,

  /// Лучшая серия побед (метрика-«достижение», берётся максимум, не сумма).
  bestStreak,
}

/// Определение квеста.
class Quest {
  /// Уникальный id.
  final String id;

  /// Заголовок.
  final String title;

  /// Эмодзи-иконка.
  final String icon;

  /// Период.
  final QuestPeriod period;

  /// Метрика прогресса.
  final QuestMetric metric;

  /// Цель.
  final int target;

  /// Награда монетами.
  final int rewardCoins;

  /// Награда кристаллами.
  final int rewardCrystals;

  /// Кумулятивная ли метрика (true — суммируем дельты; false — берём максимум,
  /// напр. лучшая серия побед).
  final bool cumulative;

  /// Создаёт квест.
  const Quest({
    required this.id,
    required this.title,
    required this.icon,
    required this.period,
    required this.metric,
    required this.target,
    required this.rewardCoins,
    this.rewardCrystals = 0,
    this.cumulative = true,
  });
}

/// Пул недельных квестов (из него детерминированно выбираются [questCountWeekly]).
const List<Quest> weeklyPool = [
  Quest(id: 'w_wins_10', title: 'Выиграй 10 партий', icon: '🥇', period: QuestPeriod.weekly, metric: QuestMetric.wins, target: 10, rewardCoins: 120, rewardCrystals: 2),
  Quest(id: 'w_perfect_5', title: '5 perfect clear', icon: '✨', period: QuestPeriod.weekly, metric: QuestMetric.perfectClears, target: 5, rewardCoins: 150, rewardCrystals: 3),
  Quest(id: 'w_streak_5', title: 'Серия из 5 побед', icon: '🔥', period: QuestPeriod.weekly, metric: QuestMetric.bestStreak, target: 5, rewardCoins: 130, rewardCrystals: 2, cumulative: false),
  Quest(id: 'w_clears_150', title: 'Очисти 150 линий', icon: '🧹', period: QuestPeriod.weekly, metric: QuestMetric.clears, target: 150, rewardCoins: 100),
  Quest(id: 'w_hard_3', title: 'Победи Hard-бота 3 раза', icon: '🤖', period: QuestPeriod.weekly, metric: QuestMetric.hardWins, target: 3, rewardCoins: 140, rewardCrystals: 2),
  Quest(id: 'w_games_20', title: 'Сыграй 20 партий', icon: '🎮', period: QuestPeriod.weekly, metric: QuestMetric.games, target: 20, rewardCoins: 90),
];

/// Пул сезонных квестов.
const List<Quest> seasonalPool = [
  Quest(id: 's_online_25', title: '25 побед в онлайне', icon: '🌐', period: QuestPeriod.seasonal, metric: QuestMetric.onlineWins, target: 25, rewardCoins: 500, rewardCrystals: 25),
  Quest(id: 's_wins_100', title: '100 побед за сезон', icon: '👑', period: QuestPeriod.seasonal, metric: QuestMetric.wins, target: 100, rewardCoins: 600, rewardCrystals: 30),
  Quest(id: 's_perfect_25', title: '25 perfect clear', icon: '💎', period: QuestPeriod.seasonal, metric: QuestMetric.perfectClears, target: 25, rewardCoins: 550, rewardCrystals: 25),
  Quest(id: 's_streak_10', title: 'Серия из 10 побед', icon: '🏆', period: QuestPeriod.seasonal, metric: QuestMetric.bestStreak, target: 10, rewardCoins: 700, rewardCrystals: 40, cumulative: false),
];

/// Сколько квестов активно на период.
const int questCountWeekly = 3;
const int questCountSeasonal = 2;

/// Пул для периода.
List<Quest> poolFor(QuestPeriod period) =>
    period == QuestPeriod.weekly ? weeklyPool : seasonalPool;

/// Сколько квестов на период.
int countFor(QuestPeriod period) =>
    period == QuestPeriod.weekly ? questCountWeekly : questCountSeasonal;

/// Ищет квест по id в пулах обоих периодов.
Quest? questById(String id) {
  for (final q in [...weeklyPool, ...seasonalPool]) {
    if (q.id == id) return q;
  }
  return null;
}

/// Детерминированно выбирает набор квестов периода [period] по ключу [periodKey]
/// (одинаков весь период). Перетасовка Фишера–Йетса с LCG от seed ключа.
List<Quest> pickQuests(QuestPeriod period, String periodKey) {
  var seed = 0;
  for (final code in periodKey.codeUnits) {
    seed = (seed * 31 + code) & 0x7fffffff;
  }
  final pool = [...poolFor(period)];
  var s = seed == 0 ? 1 : seed;
  for (int i = pool.length - 1; i > 0; i--) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    final j = s % (i + 1);
    final tmp = pool[i];
    pool[i] = pool[j];
    pool[j] = tmp;
  }
  return pool.take(countFor(period)).toList();
}

/// Событие итога партии: несёт дельты по метрикам.
class QuestEvent {
  /// Победа ли.
  final bool won;

  /// Был ли perfect clear в матче.
  final bool perfect;

  /// Сыграно против Hard-бота.
  final bool vsHardBot;

  /// Это онлайн-матч.
  final bool online;

  /// Победа в онлайне.
  final bool onlineWin;

  /// Очищено линий за матч.
  final int clears;

  /// Текущая серия побед (с учётом этого матча).
  final int winStreak;

  /// Создаёт событие.
  const QuestEvent({
    this.won = false,
    this.perfect = false,
    this.vsHardBot = false,
    this.online = false,
    this.onlineWin = false,
    this.clears = 0,
    this.winStreak = 0,
  });

  /// Дельта (или значение для не-кумулятивных метрик) для [metric].
  int deltaFor(QuestMetric metric) => switch (metric) {
    QuestMetric.games => 1,
    QuestMetric.wins => won ? 1 : 0,
    QuestMetric.clears => clears,
    QuestMetric.perfectClears => perfect ? 1 : 0,
    QuestMetric.hardWins => (won && vsHardBot) ? 1 : 0,
    QuestMetric.onlineWins => onlineWin ? 1 : 0,
    QuestMetric.bestStreak => winStreak,
  };
}

/// Состояние квестов одного периода.
class QuestPeriodState {
  /// Ключ периода (`W<n>` / `S<n>`).
  final String periodKey;

  /// Id активных квестов.
  final List<String> questIds;

  /// Прогресс по id.
  final Map<String, int> progress;

  /// Id квестов с полученной наградой.
  final Set<String> claimed;

  /// Создаёт состояние.
  const QuestPeriodState({
    required this.periodKey,
    required this.questIds,
    required this.progress,
    required this.claimed,
  });

  /// Свежее состояние периода [period] для ключа [periodKey].
  factory QuestPeriodState.fresh(QuestPeriod period, String periodKey) {
    final quests = pickQuests(period, periodKey);
    return QuestPeriodState(
      periodKey: periodKey,
      questIds: [for (final q in quests) q.id],
      progress: {for (final q in quests) q.id: 0},
      claimed: {},
    );
  }

  /// Применяет событие [event] к прогрессу (кумулятивно или по максимуму).
  QuestPeriodState applyEvent(QuestEvent event) {
    final next = {...progress};
    for (final id in questIds) {
      final q = questById(id);
      if (q == null) continue;
      final delta = event.deltaFor(q.metric);
      final cur = next[id] ?? 0;
      final raw = q.cumulative ? cur + delta : (delta > cur ? delta : cur);
      next[id] = raw > q.target ? q.target : raw;
    }
    return copyWith(progress: next);
  }

  /// Копия с изменениями.
  QuestPeriodState copyWith({Map<String, int>? progress, Set<String>? claimed}) =>
      QuestPeriodState(
        periodKey: periodKey,
        questIds: questIds,
        progress: progress ?? this.progress,
        claimed: claimed ?? this.claimed,
      );

  /// JSON-представление.
  Map<String, dynamic> toJson() => {
    'periodKey': periodKey,
    'questIds': questIds,
    'progress': progress,
    'claimed': claimed.toList(),
  };

  /// Восстанавливает из JSON.
  factory QuestPeriodState.fromJson(Map<String, dynamic> json) =>
      QuestPeriodState(
        periodKey: json['periodKey'] as String,
        questIds: (json['questIds'] as List<dynamic>).cast<String>(),
        progress: (json['progress'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v as int),
        ),
        claimed: (json['claimed'] as List<dynamic>).cast<String>().toSet(),
      );
}
