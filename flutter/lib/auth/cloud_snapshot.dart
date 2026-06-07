/// cloud_snapshot.dart — облачный снимок прогресса + слияние (Model, чистый).
///
/// За что отвечает файл:
///   Описывает документ `users/{uid}` в Firestore (минимальная схема:
///   профиль + разблокированные ачивки + настройки + метка времени) и чистую
///   логику слияния облака с локальным состоянием. Без Firebase-зависимостей —
///   тестируется без сети.
///
/// Стратегия слияния (нет легаси-данных TS, поэтому без поля-в-поле LWW):
///   • числовые счётчики профиля — максимум (не теряем прогресс ни одной из
///     сторон); • ник/аватар — предпочитаем не-дефолтные (облако при равенстве);
///   • id — облачный, если задан (единая идентичность игрока в онлайне);
///   • ачивки — объединение; • настройки — облачные (следуют за аккаунтом).
///
/// Соответствие TS: `src/ui/auth/sync.ts` (CloudSnapshot), но схема минимальная.
library;

import '../profile/profile.dart';
import '../settings/settings.dart';

/// Снимок прогресса для синхронизации.
class CloudSnapshot {
  /// Профиль (или null, если в облаке его нет).
  final Profile? profile;

  /// Разблокированные ачивки.
  final Set<String> achievements;

  /// Настройки (или null).
  final Settings? settings;

  /// Метка последнего обновления (мс epoch).
  final int updatedAt;

  const CloudSnapshot({
    this.profile,
    this.achievements = const {},
    this.settings,
    this.updatedAt = 0,
  });

  /// JSON документа Firestore.
  Map<String, dynamic> toJson() => {
    if (profile != null) 'profile': profile!.toJson(),
    'achievements': achievements.toList(),
    if (settings != null) 'settings': settings!.toJson(),
    'updatedAt': updatedAt,
  };

  /// Восстанавливает из документа Firestore.
  factory CloudSnapshot.fromJson(Map<String, dynamic> json) => CloudSnapshot(
    profile: json['profile'] == null
        ? null
        : Profile.fromJson((json['profile'] as Map).cast<String, dynamic>()),
    achievements:
        (json['achievements'] as List<dynamic>?)?.cast<String>().toSet() ??
        const {},
    settings: json['settings'] == null
        ? null
        : Settings.fromJson((json['settings'] as Map).cast<String, dynamic>()),
    updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
  );
}

/// Сливает локальный профиль с облачным (см. стратегию в шапке файла).
Profile mergeProfiles(Profile local, Profile cloud) {
  String pickName(String localV, String cloudV, String fallback) {
    if (cloudV != fallback) return cloudV;
    if (localV != fallback) return localV;
    return cloudV;
  }

  return local.copyWith(
    id: cloud.id.isNotEmpty ? cloud.id : local.id,
    nick: pickName(local.nick, cloud.nick, Profile.initial.nick),
    avatar: pickName(local.avatar, cloud.avatar, Profile.initial.avatar),
    xp: local.xp > cloud.xp ? local.xp : cloud.xp,
    coins: local.coins > cloud.coins ? local.coins : cloud.coins,
    gamesPlayed: local.gamesPlayed > cloud.gamesPlayed
        ? local.gamesPlayed
        : cloud.gamesPlayed,
    wins: local.wins > cloud.wins ? local.wins : cloud.wins,
    onlineWins: local.onlineWins > cloud.onlineWins
        ? local.onlineWins
        : cloud.onlineWins,
    onlineLosses: local.onlineLosses > cloud.onlineLosses
        ? local.onlineLosses
        : cloud.onlineLosses,
    onlineDraws: local.onlineDraws > cloud.onlineDraws
        ? local.onlineDraws
        : cloud.onlineDraws,
  );
}
