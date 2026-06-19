/// rating_controller.dart — запрос оценки приложения (ViewModel, § 11.5).
///
/// За что отвечает файл:
///   Ведёт счётчик сыгранных матчей и решает, когда показать ненавязчивый
///   запрос «оцените приложение» (ROADMAP § 11.5: после 5+ матчей). Хранит
///   статус (не показывали / оценил / больше не предлагать) и «отложку»
///   (later → +5 матчей до повтора), персистит в SharedPreferences. Сам поход в
///   стор за оценкой — через [ReviewService] (стаб, пока стор не подключён, 🔒).
///   Чистый Riverpod-`Notifier` без `BuildContext`.
///
/// Соответствие ROADMAP: § 11.5 (in-app rating prompt; submission в сторы — 🔒).
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs.dart';

/// Сколько матчей нужно сыграть до первого запроса оценки.
const int ratingMatchThreshold = 5;

/// На сколько матчей откладывается запрос при «Позже».
const int ratingSnoozeMatches = 5;

/// Статус запроса оценки.
enum RatingStatus {
  /// Ещё не отвечали.
  none,

  /// Оценил — больше не спрашиваем.
  rated,

  /// «Не предлагать» — больше не спрашиваем.
  dismissed,
}

/// Состояние запроса оценки.
class RatingState {
  /// Сыграно матчей (с установки).
  final int matches;

  /// Статус.
  final RatingStatus status;

  /// Не показывать раньше этого числа матчей («Позже»).
  final int snoozeUntil;

  /// Создаёт состояние.
  const RatingState({
    required this.matches,
    required this.status,
    required this.snoozeUntil,
  });

  /// Пора ли показать запрос: ещё не отвечали, набрано матчей и не на «отложке».
  bool get shouldPrompt =>
      status == RatingStatus.none &&
      matches >= ratingMatchThreshold &&
      matches >= snoozeUntil;

  /// Копия с изменениями.
  RatingState copyWith({int? matches, RatingStatus? status, int? snoozeUntil}) =>
      RatingState(
        matches: matches ?? this.matches,
        status: status ?? this.status,
        snoozeUntil: snoozeUntil ?? this.snoozeUntil,
      );
}

/// ViewModel запроса оценки.
class RatingController extends Notifier<RatingState> {
  @override
  RatingState build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(PrefKeys.rating);
    if (raw == null) {
      return const RatingState(
        matches: 0,
        status: RatingStatus.none,
        snoozeUntil: ratingMatchThreshold,
      );
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return RatingState(
        matches: j['matches'] as int? ?? 0,
        status: RatingStatus.values.byName(j['status'] as String? ?? 'none'),
        snoozeUntil: j['snooze'] as int? ?? ratingMatchThreshold,
      );
    } catch (_) {
      return const RatingState(
        matches: 0,
        status: RatingStatus.none,
        snoozeUntil: ratingMatchThreshold,
      );
    }
  }

  void _persist() {
    ref.read(sharedPreferencesProvider).setString(
          PrefKeys.rating,
          jsonEncode({
            'matches': state.matches,
            'status': state.status.name,
            'snooze': state.snoozeUntil,
          }),
        );
  }

  /// Засчитывает сыгранный матч.
  void recordMatch() {
    state = state.copyWith(matches: state.matches + 1);
    _persist();
  }

  /// Пользователь оценил — больше не спрашиваем.
  void markRated() {
    state = state.copyWith(status: RatingStatus.rated);
    _persist();
  }

  /// «Не предлагать» — больше не спрашиваем.
  void markDismissed() {
    state = state.copyWith(status: RatingStatus.dismissed);
    _persist();
  }

  /// «Позже» — отложить до +[ratingSnoozeMatches] матчей.
  void snooze() {
    state = state.copyWith(snoozeUntil: state.matches + ratingSnoozeMatches);
    _persist();
  }
}

/// Провайдер ViewModel запроса оценки.
final ratingControllerProvider =
    NotifierProvider<RatingController, RatingState>(RatingController.new);
