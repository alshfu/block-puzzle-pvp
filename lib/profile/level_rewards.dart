/// level_rewards.dart — награды за достижение уровней 1–100 (Model, pure).
///
/// За что отвечает файл:
///   Таблица наград прогрессии (ROADMAP § 8.2): за каждый новый уровень —
///   монеты (линейный рост), на «вехах» — кристаллы, на 100-м — разблокировка
///   бонусного зеркального набора фигур (§ 8.5). [rewardForLevel] описывает
///   один уровень, [rewardsForLevelUp] агрегирует награды за переход через
///   несколько уровней (на случай, если за матч игрок поднялся сразу на 2+).
///
/// Без UI/IO — детерминированная функция входов.
library;

/// Идентификатор разблокировки бонусного набора зеркальных фигур (100-й ур.).
const String mirrorPiecesUnlock = 'mirror-pieces';

/// Награда за достижение конкретного уровня.
class LevelReward {
  /// Уровень, за который выдаётся.
  final int level;

  /// Монеты.
  final int coins;

  /// Кристаллы (премиум-валюта).
  final int crystals;

  /// Идентификатор разблокированного контента (или `null`).
  final String? unlock;

  /// Создаёт награду.
  const LevelReward({
    required this.level,
    required this.coins,
    this.crystals = 0,
    this.unlock,
  });
}

/// Монеты за достижение [level] (линейный рост; уровень ≤ 1 — без награды).
int _coinsForLevel(int level) => level <= 1 ? 0 : 20 + 5 * (level - 2);

/// Кристаллы за достижение [level] на «вехах» (100 → 100, кратные 25 → 25,
/// кратные 10 → 10, кратные 5 → 5, иначе 0).
int _crystalsForLevel(int level) {
  if (level <= 1) return 0;
  if (level == 100) return 100;
  if (level % 25 == 0) return 25;
  if (level % 10 == 0) return 10;
  if (level % 5 == 0) return 5;
  return 0;
}

/// Награда за достижение [level].
LevelReward rewardForLevel(int level) => LevelReward(
  level: level,
  coins: _coinsForLevel(level),
  crystals: _crystalsForLevel(level),
  unlock: level == 100 ? mirrorPiecesUnlock : null,
);

/// Суммарная награда за переход с уровня [from] на [to] (`to > from`):
/// суммирует монеты/кристаллы за каждый пройденный уровень и собирает
/// разблокировки. При `to <= from` — нулевая награда.
({int coins, int crystals, List<String> unlocks}) rewardsForLevelUp(
  int from,
  int to,
) {
  var coins = 0;
  var crystals = 0;
  final unlocks = <String>[];
  for (var lvl = from + 1; lvl <= to; lvl++) {
    final r = rewardForLevel(lvl);
    coins += r.coins;
    crystals += r.crystals;
    if (r.unlock != null) unlocks.add(r.unlock!);
  }
  return (coins: coins, crystals: crystals, unlocks: unlocks);
}
