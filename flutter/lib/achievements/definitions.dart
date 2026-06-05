/// definitions.dart — каталог достижений (Model-данные).
///
/// За что отвечает файл:
///   Список базовых достижений, завязанных на накопительную статистику профиля
///   (партии, победы, уровень, монеты). Структура расширяемая — достижения по
///   игровым событиям (комбо, perfect clear) и PvP добавятся в Фазах 4.3+/6
///   (в TS их ~120: 15 базовых + 105 PvP).
///
/// Соответствие TS: `src/ui/achievements/definitions.ts`.
library;

import 'achievement.dart';

/// Каталог базовых достижений (порядок — порядок показа на экране).
const List<Achievement> achievementDefinitions = [
  Achievement(
    id: 'first_game',
    title: 'Первый шаг',
    description: 'Сыграй первую партию',
    icon: '🎮',
    isUnlocked: _firstGame,
  ),
  Achievement(
    id: 'games_10',
    title: 'Втянулся',
    description: 'Сыграй 10 партий',
    icon: '🕹️',
    isUnlocked: _games10,
  ),
  Achievement(
    id: 'games_50',
    title: 'Завсегдатай',
    description: 'Сыграй 50 партий',
    icon: '🎲',
    isUnlocked: _games50,
  ),
  Achievement(
    id: 'first_win',
    title: 'Победа!',
    description: 'Выиграй первую партию',
    icon: '🏅',
    isUnlocked: _firstWin,
  ),
  Achievement(
    id: 'wins_10',
    title: 'Боец',
    description: 'Выиграй 10 партий',
    icon: '🥈',
    isUnlocked: _wins10,
  ),
  Achievement(
    id: 'wins_25',
    title: 'Чемпион',
    description: 'Выиграй 25 партий',
    icon: '🥇',
    isUnlocked: _wins25,
  ),
  Achievement(
    id: 'level_5',
    title: 'Новобранец',
    description: 'Достигни 5 уровня',
    icon: '⭐',
    isUnlocked: _level5,
  ),
  Achievement(
    id: 'level_10',
    title: 'Опытный',
    description: 'Достигни 10 уровня',
    icon: '🌟',
    isUnlocked: _level10,
  ),
  Achievement(
    id: 'level_25',
    title: 'Мастер',
    description: 'Достигни 25 уровня',
    icon: '💫',
    isUnlocked: _level25,
  ),
  Achievement(
    id: 'coins_100',
    title: 'Копилка',
    description: 'Накопи 100 монет',
    icon: '🪙',
    isUnlocked: _coins100,
  ),
  Achievement(
    id: 'coins_500',
    title: 'Богач',
    description: 'Накопи 500 монет',
    icon: '💰',
    isUnlocked: _coins500,
  ),
];

bool _firstGame(AchievementStats s) => s.gamesPlayed >= 1;
bool _games10(AchievementStats s) => s.gamesPlayed >= 10;
bool _games50(AchievementStats s) => s.gamesPlayed >= 50;
bool _firstWin(AchievementStats s) => s.wins >= 1;
bool _wins10(AchievementStats s) => s.wins >= 10;
bool _wins25(AchievementStats s) => s.wins >= 25;
bool _level5(AchievementStats s) => s.level >= 5;
bool _level10(AchievementStats s) => s.level >= 10;
bool _level25(AchievementStats s) => s.level >= 25;
bool _coins100(AchievementStats s) => s.coins >= 100;
bool _coins500(AchievementStats s) => s.coins >= 500;
