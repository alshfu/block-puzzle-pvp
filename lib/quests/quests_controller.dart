/// quests_controller.dart — ViewModel недельных/сезонных квестов (MVVM).
///
/// За что отвечает файл:
///   Хранит состояния недельного и сезонного периодов, сбрасывает их при смене
///   периода (ключ из часов — допустимо во ViewModel), накапливает прогресс по
///   событиям партий ([QuestEvent]) и выдаёт награды (монеты+кристаллы в
///   профиль). Персист в [SharedPreferences]. Ежедневные квесты — отдельно
///   (`DailyController`).
///
/// Соответствие ROADMAP: § 8.4 (расширенная квестовая система, weekly/seasonal).
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_controller.dart';
import '../storage/prefs.dart';
import 'quest.dart';

/// Дней с эпохи (UTC) для вычисления ключей периодов.
int _epochDay(DateTime now) =>
    now.toUtc().difference(DateTime.utc(1970, 1, 1)).inDays;

/// Ключ недели (`W<n>`, неделя = 7 дней с эпохи).
String _weekKey(DateTime now) => 'W${_epochDay(now) ~/ 7}';

/// Ключ сезона (`S<n>`, сезон = 90 дней с эпохи).
String _seasonKey(DateTime now) => 'S${_epochDay(now) ~/ 90}';

/// Состояние обоих периодов.
class QuestsState {
  /// Недельные квесты.
  final QuestPeriodState weekly;

  /// Сезонные квесты.
  final QuestPeriodState seasonal;

  /// Создаёт состояние.
  const QuestsState({required this.weekly, required this.seasonal});

  /// Состояние периода [period].
  QuestPeriodState forPeriod(QuestPeriod period) =>
      period == QuestPeriod.weekly ? weekly : seasonal;

  /// Копия с заменой одного периода.
  QuestsState withPeriod(QuestPeriod period, QuestPeriodState s) =>
      period == QuestPeriod.weekly
      ? QuestsState(weekly: s, seasonal: seasonal)
      : QuestsState(weekly: weekly, seasonal: s);
}

/// ViewModel недельных/сезонных квестов.
class QuestsController extends Notifier<QuestsState> {
  @override
  QuestsState build() {
    final now = DateTime.now();
    final weekly = _loadOrFresh(
      QuestPeriod.weekly,
      _prefsKey(QuestPeriod.weekly),
      _weekKey(now),
    );
    final seasonal = _loadOrFresh(
      QuestPeriod.seasonal,
      _prefsKey(QuestPeriod.seasonal),
      _seasonKey(now),
    );
    return QuestsState(weekly: weekly, seasonal: seasonal);
  }

  /// Ключ хранилища периода.
  String _prefsKey(QuestPeriod period) =>
      period == QuestPeriod.weekly ? 'bd_quests_weekly' : 'bd_quests_seasonal';

  /// Грузит состояние периода из хранилища или создаёт свежее, если период сменился.
  QuestPeriodState _loadOrFresh(
    QuestPeriod period,
    String storageKey,
    String currentKey,
  ) {
    final raw = ref.watch(sharedPreferencesProvider).getString(storageKey);
    if (raw != null) {
      try {
        final loaded = QuestPeriodState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (loaded.periodKey == currentKey) return loaded;
      } catch (_) {
        // повреждено — пересоздадим
      }
    }
    final fresh = QuestPeriodState.fresh(period, currentKey);
    ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, jsonEncode(fresh.toJson()));
    return fresh;
  }

  /// Сохраняет состояние периода.
  void _persist(QuestPeriod period, QuestPeriodState s) {
    ref
        .read(sharedPreferencesProvider)
        .setString(_prefsKey(period), jsonEncode(s.toJson()));
  }

  /// Засчитывает событие партии в обоих периодах.
  void recordEvent(QuestEvent event) {
    final weekly = state.weekly.applyEvent(event);
    final seasonal = state.seasonal.applyEvent(event);
    state = QuestsState(weekly: weekly, seasonal: seasonal);
    _persist(QuestPeriod.weekly, weekly);
    _persist(QuestPeriod.seasonal, seasonal);
  }

  /// Забирает награду за выполненный квест [id] периода [period].
  void claim(QuestPeriod period, String id) {
    final q = questById(id);
    if (q == null) return;
    final ps = state.forPeriod(period);
    if (ps.claimed.contains(id)) return;
    if ((ps.progress[id] ?? 0) < q.target) return;
    final profile = ref.read(profileControllerProvider.notifier);
    profile.addCoins(q.rewardCoins);
    if (q.rewardCrystals > 0) profile.addCrystals(q.rewardCrystals);
    final next = ps.copyWith(claimed: {...ps.claimed, id});
    state = state.withPeriod(period, next);
    _persist(period, next);
  }
}

/// Провайдер ViewModel недельных/сезонных квестов.
final questsControllerProvider =
    NotifierProvider<QuestsController, QuestsState>(QuestsController.new);
