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
    if (raw == null) return Profile.initial;
    try {
      return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Profile.initial;
    }
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

  /// Начисляет результат партии: XP, монеты и счётчики. [won] — победа ли;
  /// [draw] — ничья (как поражение по наградам, но без инкремента wins).
  void recordResult({required bool won, bool draw = false}) {
    final xpGain = won ? _xpForWin : _xpForLoss;
    final coinGain = won ? _coinsForWin : _coinsForLoss;
    state = state.copyWith(
      xp: state.xp + xpGain,
      coins: state.coins + coinGain,
      gamesPlayed: state.gamesPlayed + 1,
      wins: state.wins + (won && !draw ? 1 : 0),
    );
    _persist();
  }
}

/// Провайдер ViewModel профиля.
final profileControllerProvider = NotifierProvider<ProfileController, Profile>(
  ProfileController.new,
);
