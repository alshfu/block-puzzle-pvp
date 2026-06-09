/// inventory_controller.dart — ViewModel инвентаря power-ups (MVVM, ViewModel).
///
/// За что отвечает файл:
///   Хранит количество каждого power-up (`id → count`). Покупка списывает
///   кристаллы через профиль; применение — расход одной штуки. Персист в
///   [SharedPreferences].
///
/// Соответствие TS: `src/ui/storage` (inventory) + `shop/powerups.ts`.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_controller.dart';
import '../storage/prefs.dart';
import 'powerups.dart';

/// ViewModel инвентаря power-ups (id → количество).
class InventoryController extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    final raw = ref
        .watch(sharedPreferencesProvider)
        .getString(PrefKeys.inventory);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      );
    } catch (_) {
      return {};
    }
  }

  void _persist() {
    ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.inventory, jsonEncode(state));
  }

  /// Количество power-up [id].
  int count(String id) => state[id] ?? 0;

  /// Покупает 1 power-up [id] за кристаллы (если хватает). Успех — bool.
  bool buy(String id) {
    final def = powerupsById[id];
    if (def == null) return false;
    if (!ref
        .read(profileControllerProvider.notifier)
        .spendCrystals(def.price)) {
      return false;
    }
    state = {...state, id: count(id) + 1};
    _persist();
    return true;
  }

  /// Расходует 1 power-up [id] (если есть). Успех — bool.
  bool consume(String id) {
    final n = count(id);
    if (n <= 0) return false;
    state = {...state, id: n - 1};
    _persist();
    return true;
  }

  /// Сбрасывает инвентарь (сброс прогресса).
  void reset() {
    state = {};
    ref.read(sharedPreferencesProvider).remove(PrefKeys.inventory);
  }
}

/// Провайдер ViewModel инвентаря.
final inventoryControllerProvider =
    NotifierProvider<InventoryController, Map<String, int>>(
      InventoryController.new,
    );
