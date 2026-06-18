/// season_pass_controller.dart — ViewModel сезонного пропуска (§ 10.4).
///
/// За что отвечает файл:
///   Хранит прогресс пропуска (сезонный XP, факт покупки премиума, забранные
///   уровни обоих треков), персистит в SharedPreferences и сбрасывается при
///   смене 90-дневного сезона (ключ сезона по дню — как у квестов). Команды:
///   добавить XP (из матчей), купить премиум, забрать награду уровня (возвращает
///   [SeasonReward] для начисления во View). Без `BuildContext`/виджетов.
///
/// Соответствие ROADMAP: § 10.4 (серверная валидация прогресса — 🔒).
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs.dart';
import 'season_pass.dart';

/// Снимок прогресса пропуска.
class SeasonPassState {
  /// Ключ текущего сезона (для сброса).
  final int seasonKey;

  /// Накопленный сезонный XP.
  final int xp;

  /// Куплен ли премиум-трек в этом сезоне.
  final bool premium;

  /// Забранные уровни бесплатного трека.
  final Set<int> claimedFree;

  /// Забранные уровни премиум-трека.
  final Set<int> claimedPremium;

  /// Создаёт снимок.
  const SeasonPassState({
    required this.seasonKey,
    required this.xp,
    required this.premium,
    required this.claimedFree,
    required this.claimedPremium,
  });

  /// Текущий достигнутый уровень.
  int get tier => seasonTierForXp(xp);

  /// Копия с изменениями.
  SeasonPassState copyWith({
    int? seasonKey,
    int? xp,
    bool? premium,
    Set<int>? claimedFree,
    Set<int>? claimedPremium,
  }) => SeasonPassState(
    seasonKey: seasonKey ?? this.seasonKey,
    xp: xp ?? this.xp,
    premium: premium ?? this.premium,
    claimedFree: claimedFree ?? this.claimedFree,
    claimedPremium: claimedPremium ?? this.claimedPremium,
  );
}

/// ViewModel сезонного пропуска.
class SeasonPassController extends Notifier<SeasonPassState> {
  @override
  SeasonPassState build() {
    final key = _currentSeasonKey();
    final raw = ref.watch(sharedPreferencesProvider).getString(
          PrefKeys.seasonPass,
        );
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        if ((j['key'] as int?) == key) {
          return SeasonPassState(
            seasonKey: key,
            xp: j['xp'] as int? ?? 0,
            premium: j['premium'] as bool? ?? false,
            claimedFree: {for (final t in (j['cf'] as List? ?? [])) t as int},
            claimedPremium: {for (final t in (j['cp'] as List? ?? [])) t as int},
          );
        }
      } catch (_) {/* повреждено → новый сезон */}
    }
    // Новый сезон (или первый запуск): чистый прогресс.
    return SeasonPassState(
      seasonKey: key,
      xp: 0,
      premium: false,
      claimedFree: const {},
      claimedPremium: const {},
    );
  }

  /// Текущий ключ сезона по дню от эпохи (UTC).
  int _currentSeasonKey() {
    final days = DateTime.now().toUtc().millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    return seasonKeyForDay(days);
  }

  void _persist() {
    ref.read(sharedPreferencesProvider).setString(
          PrefKeys.seasonPass,
          jsonEncode({
            'key': state.seasonKey,
            'xp': state.xp,
            'premium': state.premium,
            'cf': state.claimedFree.toList(),
            'cp': state.claimedPremium.toList(),
          }),
        );
  }

  /// Добавляет сезонный XP (из завершённых матчей).
  void addXp(int amount) {
    if (amount <= 0) return;
    state = state.copyWith(xp: state.xp + amount);
    _persist();
  }

  /// Помечает премиум как купленный (кристаллы списывает вызывающий).
  void buyPremium() {
    if (state.premium) return;
    state = state.copyWith(premium: true);
    _persist();
  }

  /// Забирает награду бесплатного трека за [tier]; `null`, если недоступно
  /// (уровень не достигнут или уже забрано).
  SeasonReward? claimFree(int tier) {
    if (tier < 1 || tier > state.tier || state.claimedFree.contains(tier)) {
      return null;
    }
    state = state.copyWith(claimedFree: {...state.claimedFree, tier});
    _persist();
    return seasonFreeReward(tier);
  }

  /// Забирает награду премиум-трека за [tier]; `null`, если недоступно
  /// (нет премиума, уровень не достигнут или уже забрано).
  SeasonReward? claimPremium(int tier) {
    if (!state.premium ||
        tier < 1 ||
        tier > state.tier ||
        state.claimedPremium.contains(tier)) {
      return null;
    }
    state = state.copyWith(claimedPremium: {...state.claimedPremium, tier});
    _persist();
    return seasonPremiumReward(tier);
  }
}

/// Провайдер ViewModel сезонного пропуска.
final seasonPassControllerProvider =
    NotifierProvider<SeasonPassController, SeasonPassState>(
  SeasonPassController.new,
);
