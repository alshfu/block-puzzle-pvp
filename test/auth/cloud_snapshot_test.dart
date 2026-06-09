/// cloud_snapshot_test.dart — тесты облачного снимка и слияния (чистые).
///
/// Проверяем: round-trip CloudSnapshot (profile/achievements/settings) и
/// стратегию [mergeProfiles] (max-счётчики, не-дефолтные ник/аватар, id из
/// облака).
library;

import 'package:block_duel/auth/cloud_snapshot.dart';
import 'package:block_duel/profile/profile.dart';
import 'package:block_duel/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudSnapshot round-trip', () {
    test('сериализация и разбор', () {
      const snap = CloudSnapshot(
        profile: Profile(
          nick: 'Алиса',
          avatar: '🦊',
          xp: 120,
          coins: 50,
          gamesPlayed: 10,
          wins: 6,
          id: 'uid-1',
          onlineWins: 3,
          onlineLosses: 1,
          onlineDraws: 0,
        ),
        achievements: {'first_win', 'combo_3'},
        settings: Settings(soundOn: false, musicOn: true, reduceMotion: true),
        updatedAt: 123,
      );
      final back = CloudSnapshot.fromJson(snap.toJson());
      expect(back.profile!.nick, 'Алиса');
      expect(back.profile!.id, 'uid-1');
      expect(back.profile!.onlineWins, 3);
      expect(back.achievements, {'first_win', 'combo_3'});
      expect(back.settings!.soundOn, isFalse);
      expect(back.settings!.reduceMotion, isTrue);
      expect(back.updatedAt, 123);
    });

    test('пустой документ → дефолты', () {
      final s = CloudSnapshot.fromJson({});
      expect(s.profile, isNull);
      expect(s.achievements, isEmpty);
      expect(s.settings, isNull);
      expect(s.updatedAt, 0);
    });
  });

  group('mergeProfiles', () {
    test('числовые счётчики — максимум каждой стороны', () {
      const local = Profile(
        nick: 'Игрок',
        avatar: '🙂',
        xp: 100,
        coins: 10,
        gamesPlayed: 8,
        wins: 2,
        onlineWins: 5,
        onlineLosses: 1,
        onlineDraws: 0,
      );
      const cloud = Profile(
        nick: 'Игрок',
        avatar: '🙂',
        xp: 50,
        coins: 80,
        gamesPlayed: 3,
        wins: 4,
        onlineWins: 2,
        onlineLosses: 7,
        onlineDraws: 1,
      );
      final m = mergeProfiles(local, cloud);
      expect(m.xp, 100); // local больше
      expect(m.coins, 80); // cloud больше
      expect(m.gamesPlayed, 8);
      expect(m.wins, 4);
      expect(m.onlineWins, 5);
      expect(m.onlineLosses, 7);
      expect(m.onlineDraws, 1);
    });

    test('не-дефолтные ник/аватар выигрывают; id из облака', () {
      const local = Profile(
        nick: 'Боб',
        avatar: '🐼',
        xp: 0,
        coins: 0,
        gamesPlayed: 0,
        wins: 0,
        id: 'local-id',
      );
      const cloud = Profile(
        nick: 'Игрок', // дефолт
        avatar: '🙂', // дефолт
        xp: 0,
        coins: 0,
        gamesPlayed: 0,
        wins: 0,
        id: 'cloud-id',
      );
      final m = mergeProfiles(local, cloud);
      expect(m.nick, 'Боб'); // локальный не-дефолт сохраняется
      expect(m.avatar, '🐼');
      expect(m.id, 'cloud-id'); // id из облака (единая идентичность)
    });
  });
}
