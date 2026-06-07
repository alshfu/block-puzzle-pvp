/// profile_controller.dart — ViewModel профиля (MVVM, слой ViewModel).
///
/// За что отвечает файл:
///   Хранит профиль игрока, загружает его из локального хранилища и сохраняет
///   при изменениях; начисляет награды по итогу партии. Чистый Riverpod
///   `Notifier` без UI; персист — через [SharedPreferences] из репозитория.
///
/// Соответствие TS: логика профиля/статистики из `storage/profile.ts` +
/// начисление XP/монет из `useGame`/`App`.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../online/uuid.dart';
import '../storage/prefs.dart';
import 'profile.dart';

/// Награды за один матч (минимальная версия; перебалансировка — Фаза 8).
const int _xpForWin = 60;
const int _xpForLoss = 20;
const int _coinsForWin = 25;
const int _coinsForLoss = 5;

/// ViewModel профиля игрока.
class ProfileController extends Notifier<Profile> {
  @override
  Profile build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(PrefKeys.profile);
    var profile = Profile.initial;
    if (raw != null) {
      try {
        profile = Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        profile = Profile.initial;
      }
    }
    // Лениво выдаём стабильный онлайн-id при первом запуске и сохраняем.
    if (profile.id.isEmpty) {
      profile = profile.copyWith(id: newUuidV4());
      ref
          .read(sharedPreferencesProvider)
          .setString(PrefKeys.profile, jsonEncode(profile.toJson()));
    }
    return profile;
  }

  /// Сохраняет текущий профиль в хранилище.
  void _persist() {
    ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.profile, jsonEncode(state.toJson()));
  }

  /// Меняет ник (пустой игнорируется).
  void setNick(String nick) {
    final trimmed = nick.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(nick: trimmed);
    _persist();
  }

  /// Меняет аватар-эмодзи.
  void setAvatar(String avatar) {
    state = state.copyWith(avatar: avatar);
    _persist();
  }

  /// Начисляет монеты (например, награда за ежедневный квест).
  void addCoins(int amount) {
    if (amount == 0) return;
    state = state.copyWith(coins: state.coins + amount);
    _persist();
  }

  /// Начисляет результат партии: XP, монеты и счётчики. [won] — победа ли;
  /// [draw] — ничья (как поражение по наградам, но без инкремента wins).
  /// Возвращает число начисленных монет (для ежедневных квестов).
  int recordResult({required bool won, bool draw = false}) {
    final xpGain = won ? _xpForWin : _xpForLoss;
    final coinGain = won ? _coinsForWin : _coinsForLoss;
    state = state.copyWith(
      xp: state.xp + xpGain,
      coins: state.coins + coinGain,
      gamesPlayed: state.gamesPlayed + 1,
      wins: state.wins + (won && !draw ? 1 : 0),
    );
    _persist();
    return coinGain;
  }

  /// Начисляет результат онлайн-матча: только счётчики W/L/D ([outcome]:
  /// 1 победа / 0 ничья / -1 поражение). XP/монеты онлайн пока не трогаем
  /// (минимальная статистика Фазы 6A; экономику онлайна вынесем отдельно).
  void recordOnlineResult({required int outcome}) {
    state = state.copyWith(
      onlineWins: state.onlineWins + (outcome > 0 ? 1 : 0),
      onlineLosses: state.onlineLosses + (outcome < 0 ? 1 : 0),
      onlineDraws: state.onlineDraws + (outcome == 0 ? 1 : 0),
    );
    _persist();
  }
}

/// Провайдер ViewModel профиля.
final profileControllerProvider = NotifierProvider<ProfileController, Profile>(
  ProfileController.new,
);
