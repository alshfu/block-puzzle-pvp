/// memory_solo_store.dart — хранилище рекордов «Память: соло» (repository-слой).
///
/// За что отвечает файл:
///   Персистентные лучшие результаты по каждому уровню сложности в
///   [SharedPreferences] (ключ [PrefKeys.memorySoloBest], JSON `{уровень: счёт}`).
///   Предоставляет чтение карты рекордов, лучший счёт по уровню и запись нового
///   рекорда (с возвратом флага «побит ли рекорд»). Без UI/BuildContext.
///
/// Соответствие ROADMAP: § 5.2 («Сохранение high-score в storage/memory-solo»).
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../storage/prefs.dart';
import 'memory_solo_puzzle.dart';

/// Репозиторий рекордов Memory Solo поверх [SharedPreferences].
class MemorySoloStore {
  /// Экземпляр хранилища (общий, из провайдера).
  final SharedPreferences _prefs;

  /// Создаёт репозиторий поверх [prefs].
  const MemorySoloStore(this._prefs);

  /// Возвращает карту «уровень → лучший счёт». Битый/пустой JSON → пустая карта.
  Map<MemoryDifficulty, int> all() {
    final raw = _prefs.getString(PrefKeys.memorySoloBest);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final result = <MemoryDifficulty, int>{};
      for (final diff in MemoryDifficulty.values) {
        final v = decoded[diff.name];
        if (v is num) result[diff] = v.toInt();
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  /// Лучший счёт по [difficulty] (0, если рекорда ещё нет).
  int best(MemoryDifficulty difficulty) => all()[difficulty] ?? 0;

  /// Сохраняет [score] как рекорд [difficulty], если он строго больше прежнего.
  /// Возвращает `true`, если рекорд обновлён.
  Future<bool> submit(MemoryDifficulty difficulty, int score) async {
    final current = all();
    final prev = current[difficulty] ?? 0;
    if (score <= prev) return false;
    final next = {
      for (final entry in current.entries) entry.key.name: entry.value,
      difficulty.name: score,
    };
    await _prefs.setString(PrefKeys.memorySoloBest, jsonEncode(next));
    return true;
  }
}

/// Провайдер репозитория рекордов Memory Solo.
final memorySoloStoreProvider = Provider<MemorySoloStore>(
  (ref) => MemorySoloStore(ref.watch(sharedPreferencesProvider)),
);
