/// season_pass.dart — модель сезонного пропуска (Model, pure).
///
/// За что отвечает файл:
///   Чистая логика 90-дневного пропуска (ROADMAP § 10.4): 50 уровней, прогресс
///   по сезонному XP, два трека наград — бесплатный и премиальный. Здесь:
///   маппинг XP→уровень, награды трека по уровню, ключ сезона по дню (для
///   сброса) и параметры (цена премиума). Без UI/IO/`DateTime` — день сезона
///   вычисляет ViewModel и передаёт сюда.
///
/// Соответствие ROADMAP: § 10.4 (сезонный pass; серверная валидация — 🔒).
library;

/// Число уровней пропуска.
const int seasonTiers = 50;

/// XP за один уровень пропуска.
const int seasonXpPerTier = 500;

/// Длительность сезона в днях.
const int seasonDays = 90;

/// Цена премиум-трека в кристаллах.
const int seasonPremiumPrice = 990;

/// Награда уровня: монеты + кристаллы.
class SeasonReward {
  /// Монеты.
  final int coins;

  /// Кристаллы.
  final int crystals;

  /// Создаёт награду.
  const SeasonReward(this.coins, this.crystals);
}

/// Текущий уровень по сезонному [xp] (0..[seasonTiers]).
int seasonTierForXp(int xp) {
  final t = xp ~/ seasonXpPerTier;
  return t < 0 ? 0 : (t > seasonTiers ? seasonTiers : t);
}

/// XP, набранный внутри текущего уровня (для прогресс-бара).
int seasonXpInTier(int xp) => xp % seasonXpPerTier;

/// Ключ сезона по «дню от эпохи» [daysSinceEpoch] — для сброса каждые
/// [seasonDays] дней.
int seasonKeyForDay(int daysSinceEpoch) => daysSinceEpoch ~/ seasonDays;

/// Награда БЕСПЛАТНОГО трека за уровень [tier] (1..50): монеты растут линейно,
/// кристаллы — на каждом 5-м уровне.
SeasonReward seasonFreeReward(int tier) {
  if (tier < 1 || tier > seasonTiers) return const SeasonReward(0, 0);
  final coins = 20 + tier * 2;
  final crystals = tier % 5 == 0 ? 10 : 0;
  return SeasonReward(coins, crystals);
}

/// Награда ПРЕМИУМ-трека за уровень [tier] (1..50): крупнее бесплатного, на 50-м
/// — джекпот кристаллов.
SeasonReward seasonPremiumReward(int tier) {
  if (tier < 1 || tier > seasonTiers) return const SeasonReward(0, 0);
  final coins = 40 + tier * 4;
  var crystals = tier % 5 == 0 ? 25 : 0;
  if (tier == seasonTiers) crystals += 200;
  return SeasonReward(coins, crystals);
}
