/// engine_test.dart — тесты движка достижений и каталога.
///
/// Проверяем: полнота каталога (120, уникальные id), офлайн-разблокировки и
/// прогресс, идемпотентность, базовые онлайн-разблокировки, сериализацию
/// Stats/AchProgress.
library;

import 'package:block_duel/achievements/achievement.dart';
import 'package:block_duel/achievements/definitions.dart';
import 'package:block_duel/achievements/engine.dart';
import 'package:flutter_test/flutter_test.dart';

MatchContext _ctx({
  int winner = 0,
  bool perfect = false,
  int maxMulti = 0,
  int bestCombo = 0,
  String mode = 'bot',
  String? botLevel = 'medium',
  Stats? stats,
  int winStreak = 0,
}) => MatchContext(
  winner: winner,
  hadPerfectClear: perfect,
  maxMultiClear: maxMulti,
  bestCombo: bestCombo,
  mode: mode,
  botLevel: botLevel,
  statsAfter: stats ?? const Stats(games: 1, wins: 1),
  winStreak: winStreak,
);

void main() {
  group('каталог', () {
    test('120 достижений, уникальные id', () {
      expect(achievementDefinitions.length, 120);
      expect(achievementsById.length, achievementDefinitions.length);
    });

    test('5 категорий присутствуют', () {
      for (final c in AchievementCategory.values) {
        expect(
          achievementDefinitions.any((a) => a.category == c),
          isTrue,
          reason: 'категория ${c.name}',
        );
      }
    });
  });

  group('processMatch (офлайн)', () {
    test('первая победа → first_blood разблокирован', () {
      final r = processMatch({}, _ctx(winner: 0), 1000);
      expect(r.progress['first_blood']!.unlocked, isTrue);
      expect(r.unlocked.any((d) => d.id == 'first_blood'), isTrue);
    });

    test('perfect / combinator / ai_tamer / king_five', () {
      final r = processMatch(
        {},
        _ctx(winner: 0, perfect: true, maxMulti: 5, botLevel: 'hard'),
        1000,
      );
      expect(r.progress['flawless']!.unlocked, isTrue);
      expect(r.progress['combinator']!.unlocked, isTrue); // ≥4
      expect(r.progress['ai_tamer']!.unlocked, isTrue);
      expect(r.progress['king_five']!.unlocked, isTrue); // ≥5
    });

    test('прогресс без разблокировки (cleaner_100)', () {
      final r = processMatch(
        {},
        _ctx(stats: const Stats(games: 1, wins: 1, totalClears: 50)),
        1000,
      );
      final p = r.progress['cleaner_100']!;
      expect(p.current, 50);
      expect(p.unlocked, isFalse);
    });

    test('streak_3 при серии 3', () {
      final r = processMatch({}, _ctx(winStreak: 3), 1000);
      expect(r.progress['streak_3']!.unlocked, isTrue);
      expect(r.progress['streak_5']!.unlocked, isFalse);
    });

    test('идемпотентность: разблокированное не сбрасывается', () {
      final r1 = processMatch({}, _ctx(winner: 0), 1000);
      // Следующий матч — поражение; first_blood остаётся разблокированным.
      final r2 = processMatch(
        r1.progress,
        _ctx(winner: 1, stats: const Stats(games: 2, wins: 1)),
        2000,
      );
      expect(r2.progress['first_blood']!.unlocked, isTrue);
      expect(r2.unlocked.any((d) => d.id == 'first_blood'), isFalse);
    });
  });

  group('processOnlineMatch', () {
    test('первая онлайн-победа → on_w_1', () {
      final r = processOnlineMatch(
        {},
        const Stats(onlineGames: 1, onlineWins: 1, onlineCurrentWinStreak: 1),
        const OnlineMatchInfo(
          won: true,
          drew: false,
          scoreGap: 12,
          opponentScore: 8,
          turnCount: 10,
          maxMultiClear: 0,
          bestCombo: 0,
          themeId: 'neutral',
          opponentId: 'op',
        ),
        1000,
      );
      expect(r.progress['on_w_1']!.unlocked, isTrue);
      expect(r.progress['on_gap_10']!.unlocked, isTrue); // отрыв ≥10
      expect(r.progress['on_fast_15']!.unlocked, isTrue); // ≤15 ходов
    });

    test('myElo → on_e_1100/on_e_1200 разблокируются', () {
      final r = processOnlineMatch(
        {},
        const Stats(onlineGames: 1, onlineWins: 1),
        const OnlineMatchInfo(
          won: true,
          drew: false,
          scoreGap: 5,
          opponentScore: 3,
          turnCount: 20,
          maxMultiClear: 0,
          bestCombo: 0,
          themeId: 'neutral',
          opponentId: 'op',
          myElo: 1200,
        ),
        1000,
      );
      expect(r.progress['on_e_1100']!.unlocked, isTrue);
      expect(r.progress['on_e_1200']!.unlocked, isTrue);
      expect(r.progress['on_e_1300']!.unlocked, isFalse);
    });

    test('ничья → on_draw (hidden)', () {
      final r = processOnlineMatch(
        {},
        const Stats(onlineGames: 1, onlineDraws: 1),
        const OnlineMatchInfo(
          won: false,
          drew: true,
          scoreGap: 0,
          opponentScore: 20,
          turnCount: 40,
          maxMultiClear: 0,
          bestCombo: 0,
          themeId: 'night',
          opponentId: 'op',
        ),
        1000,
      );
      expect(r.progress['on_draw']!.unlocked, isTrue);
    });
  });

  group('сериализация', () {
    test('Stats round-trip', () {
      const s = Stats(
        games: 5,
        wins: 3,
        totalClears: 120,
        onlineWins: 7,
        onlineThemesPlayed: ['neutral', 'candy'],
      );
      final back = Stats.fromJson(s.toJson());
      expect(back.games, 5);
      expect(back.totalClears, 120);
      expect(back.onlineWins, 7);
      expect(back.onlineThemesPlayed, ['neutral', 'candy']);
    });

    test('AchProgress round-trip', () {
      const p = AchProgress(current: 3, unlockedAt: 42);
      final back = AchProgress.fromJson(p.toJson());
      expect(back.current, 3);
      expect(back.unlockedAt, 42);
      expect(back.unlocked, isTrue);
    });
  });
}
