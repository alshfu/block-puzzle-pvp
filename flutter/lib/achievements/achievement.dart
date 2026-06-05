/// achievement.dart — модель достижения и контекст оценки (Model-слой).
///
/// За что отвечает файл:
///   Описывает одно достижение (id, заголовок, описание, иконка, условие
///   разблокировки) и снимок статистики [AchievementStats], по которому условие
///   проверяется. Условие — чистая функция от статистики, без побочных
///   эффектов: это позволяет движку оценивать ачивки детерминированно.
///
/// Соответствие TS: `src/ui/achievements/definitions.ts` (структура ачивки).
library;

/// Снимок статистики игрока для проверки условий достижений.
class AchievementStats {
  /// Сыграно партий.
  final int gamesPlayed;

  /// Побед.
  final int wins;

  /// Текущий уровень.
  final int level;

  /// Монеты.
  final int coins;

  /// Накопленный XP.
  final int xp;

  /// Создаёт снимок статистики.
  const AchievementStats({
    required this.gamesPlayed,
    required this.wins,
    required this.level,
    required this.coins,
    required this.xp,
  });
}

/// Достижение: метаданные + чистое условие разблокировки.
class Achievement {
  /// Уникальный идентификатор (стабильный ключ хранилища).
  final String id;

  /// Заголовок.
  final String title;

  /// Описание (как получить).
  final String description;

  /// Эмодзи-иконка.
  final String icon;

  /// Условие разблокировки по статистике.
  final bool Function(AchievementStats stats) isUnlocked;

  /// Создаёт достижение.
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
  });
}
