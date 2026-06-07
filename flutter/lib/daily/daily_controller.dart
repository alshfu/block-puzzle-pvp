/// daily_controller.dart — ViewModel ежедневных квестов (MVVM, ViewModel).
///
/// За что отвечает файл:
///   Хранит состояние дня, сбрасывает квесты при наступлении нового дня,
///   накапливает прогресс по итогам партий и выдаёт награды (монеты в профиль).
///   Чистый Riverpod `Notifier`; ключ дня берётся из часов (это допустимо во
///   ViewModel — ядро остаётся детерминированным).
///
/// Соответствие TS: `src/ui/daily/engine.ts`.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_controller.dart';
import '../storage/prefs.dart';
import 'daily.dart';

/// Ключ хранилища состояния ежедневных квестов.
const String _dailyKey = 'bd_daily';

/// Возвращает ключ текущего дня (`yyyy-mm-dd`) из системных часов.
String _todayKey() {
  final now = DateTime.now();
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '${now.year}-$m-$d';
}

/// ViewModel ежедневных квестов.
class DailyController extends Notifier<DailyState> {
  @override
  DailyState build() {
    final today = _todayKey();
    final raw = ref.watch(sharedPreferencesProvider).getString(_dailyKey);
    if (raw != null) {
      try {
        final loaded = DailyState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (loaded.dayKey == today) return loaded;
      } catch (_) {
        // повреждено — пересоздадим
      }
    }
    final fresh = DailyState.fresh(today);
    _persist(fresh);
    return fresh;
  }

  /// Сохраняет состояние [s] в хранилище.
  void _persist(DailyState s) {
    ref
        .read(sharedPreferencesProvider)
        .setString(_dailyKey, jsonEncode(s.toJson()));
  }

  /// Засчитывает прогресс по итогу партии для всех активных квестов.
  void recordGame(DailyGameEvent event) {
    final progress = {...state.progress};
    for (final id in state.questIds) {
      final q = questById(id);
      if (q == null) continue;
      final next = (progress[id] ?? 0) + event.deltaFor(q.metric);
      progress[id] = next > q.target ? q.target : next;
    }
    state = state.copyWith(progress: progress);
    _persist(state);
  }

  /// Забирает награду за выполненный квест [id] (если выполнен и не получен).
  void claim(String id) {
    final q = questById(id);
    if (q == null) return;
    if (state.claimed.contains(id)) return;
    if ((state.progress[id] ?? 0) < q.target) return;
    ref.read(profileControllerProvider.notifier).addCoins(q.reward);
    state = state.copyWith(claimed: {...state.claimed, id});
    _persist(state);
  }
}

/// Провайдер ViewModel ежедневных квестов.
final dailyControllerProvider = NotifierProvider<DailyController, DailyState>(
  DailyController.new,
);
