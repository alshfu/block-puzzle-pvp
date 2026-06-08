/// skins_controller.dart — ViewModel скинов (MVVM, ViewModel).
///
/// За что отвечает файл:
///   Хранит состояние скинов игрока: множество купленных и надетый. Покупка
///   списывает монеты через профиль; смена надетого — мгновенная. Персист в
///   [SharedPreferences].
///
/// Соответствие TS: `src/ui/storage` (playerSkins) + `shop/skins.ts`.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_controller.dart';
import '../storage/prefs.dart';
import 'skins.dart';

/// Состояние скинов: купленные + надетый.
class PlayerSkins {
  /// Купленные/разблокированные id (включая бесплатный `default`).
  final Set<String> unlocked;

  /// Надетый скин.
  final String equipped;

  const PlayerSkins({required this.unlocked, required this.equipped});

  /// По умолчанию: разблокирован и надет `default`.
  static const PlayerSkins initial = PlayerSkins(
    unlocked: {'default'},
    equipped: 'default',
  );

  PlayerSkins copyWith({Set<String>? unlocked, String? equipped}) =>
      PlayerSkins(
        unlocked: unlocked ?? this.unlocked,
        equipped: equipped ?? this.equipped,
      );

  Map<String, dynamic> toJson() => {
    'unlocked': unlocked.toList(),
    'equipped': equipped,
  };

  factory PlayerSkins.fromJson(Map<String, dynamic> json) => PlayerSkins(
    unlocked: {
      'default',
      ...?(json['unlocked'] as List<dynamic>?)?.cast<String>(),
    },
    equipped: json['equipped'] as String? ?? 'default',
  );
}

/// ViewModel скинов.
class SkinsController extends Notifier<PlayerSkins> {
  @override
  PlayerSkins build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(PrefKeys.skins);
    if (raw == null) return PlayerSkins.initial;
    try {
      return PlayerSkins.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PlayerSkins.initial;
    }
  }

  void _persist() {
    ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.skins, jsonEncode(state.toJson()));
  }

  /// Покупает скин [id] за монеты (если хватает и ещё не куплен). Успех — bool.
  bool buy(String id) {
    final def = skinsById[id];
    if (def == null || state.unlocked.contains(id)) return false;
    if (!ref.read(profileControllerProvider.notifier).spendCoins(def.price)) {
      return false;
    }
    state = state.copyWith(unlocked: {...state.unlocked, id});
    _persist();
    return true;
  }

  /// Надевает купленный скин [id].
  void equip(String id) {
    if (!state.unlocked.contains(id)) return;
    state = state.copyWith(equipped: id);
    _persist();
  }

  /// Сбрасывает к дефолту (сброс прогресса).
  void reset() {
    state = PlayerSkins.initial;
    ref.read(sharedPreferencesProvider).remove(PrefKeys.skins);
  }
}

/// Провайдер ViewModel скинов.
final skinsControllerProvider = NotifierProvider<SkinsController, PlayerSkins>(
  SkinsController.new,
);
