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
import 'level_rewards.dart';
import 'profile.dart';
import 'xp_formula.dart';

/// Монеты за матч (XP считается структурной формулой [xpForMatch], Фаза 8.1).
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

  /// Полностью заменяет профиль (например, результатом облачного слияния) и
  /// сохраняет.
  void replace(Profile profile) {
    state = profile;
    _persist();
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

  /// Начисляет XP (например, награда за разблокированную ачивку) и выдаёт
  /// награды за повышение уровня (ROADMAP § 8.2).
  void addXp(int amount) {
    if (amount == 0) return;
    final before = state.level;
    state = state.copyWith(xp: state.xp + amount);
    _grantLevelUp(before);
    _persist();
  }

  /// Выдаёт награды за уровни, пройденные с [beforeLevel] до текущего (монеты/
  /// кристаллы). Разблокировки (зеркальный набор на 100-м) — informational,
  /// потребляются Фазой 8.5. Не персистит (вызывающий сам сохраняет).
  void _grantLevelUp(int beforeLevel) {
    final after = state.level;
    if (after <= beforeLevel) return;
    final r = rewardsForLevelUp(beforeLevel, after);
    if (r.coins > 0 || r.crystals > 0) {
      state = state.copyWith(
        coins: state.coins + r.coins,
        crystals: state.crystals + r.crystals,
      );
    }
  }

  /// Начисляет монеты (например, награда за ежедневный квест).
  void addCoins(int amount) {
    if (amount == 0) return;
    state = state.copyWith(coins: state.coins + amount);
    _persist();
  }

  /// Накапливает очки к кристаллу и конвертирует: 1 кристалл за 150 очков.
  void earnCrystalsFromScore(int score) {
    if (score <= 0) return;
    final acc = state.scoreForCrystals + score;
    state = state.copyWith(
      crystals: state.crystals + acc ~/ 150,
      scoreForCrystals: acc % 150,
    );
    _persist();
  }

  /// Списывает [amount] монет, если хватает. Возвращает успех.
  bool spendCoins(int amount) {
    if (state.coins < amount) return false;
    state = state.copyWith(coins: state.coins - amount);
    _persist();
    return true;
  }

  /// Списывает [amount] кристаллов, если хватает. Возвращает успех.
  bool spendCrystals(int amount) {
    if (state.crystals < amount) return false;
    state = state.copyWith(crystals: state.crystals - amount);
    _persist();
    return true;
  }

  /// Начисляет результат партии: XP по структурной формуле (ROADMAP § 8.1),
  /// монеты и счётчики. [won] — победа ли; [draw] — ничья (без инкремента wins);
  /// [diffMult] — множитель сложности соперника; [winStreak] — серия побед с
  /// учётом этого матча. Возвращает число начисленных монет (для дейли-квестов).
  int recordResult({
    required bool won,
    bool draw = false,
    double diffMult = 1.0,
    int winStreak = 0,
  }) {
    final outcome = draw
        ? MatchOutcome.draw
        : (won ? MatchOutcome.win : MatchOutcome.loss);
    final xpGain = xpForMatch(
      outcome: outcome,
      diffMult: diffMult,
      winStreak: winStreak,
    );
    final coinGain = won ? _coinsForWin : _coinsForLoss;
    final before = state.level;
    state = state.copyWith(
      xp: state.xp + xpGain,
      coins: state.coins + coinGain,
      gamesPlayed: state.gamesPlayed + 1,
      wins: state.wins + (won && !draw ? 1 : 0),
    );
    _grantLevelUp(before);
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
