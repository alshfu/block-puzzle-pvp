/// puzzle_store.dart — персист прогресса режима «Силуэты» (Model/репозиторий).
///
/// За что отвечает файл:
///   Хранит в SharedPreferences прохождения уровней: множество id решённых
///   уровней (для отметки «✓» и выдачи монет лишь за ПЕРВОЕ прохождение),
///   лучший счёт и лучшее время (speedrun, § 9.4) по каждому уровню. Чистый
///   репозиторий: только чтение/запись ключей, без игровой логики.
///
/// Соответствие ROADMAP: § 9.4 (прогрессия/рекорды; онлайн-ladder — 🔒 VPS).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/prefs.dart';

/// Ключи хранилища прогресса пазлов.
const String _solvedKey = 'bd_puzzle_solved';
String _bestScoreKey(String id) => 'bd_puzzle_score_$id';
String _bestTimeKey(String id) => 'bd_puzzle_time_$id';

/// Репозиторий прогресса режима «Силуэты».
class PuzzleStore {
  /// Доступ к SharedPreferences.
  final Ref _ref;

  /// Создаёт репозиторий.
  PuzzleStore(this._ref);

  /// Множество id решённых уровней.
  Set<String> solvedIds() {
    final raw = _ref.read(sharedPreferencesProvider).getStringList(_solvedKey);
    return raw == null ? <String>{} : raw.toSet();
  }

  /// Решён ли уровень [id] (хоть раз).
  bool isSolved(String id) => solvedIds().contains(id);

  /// Лучший счёт по уровню [id] (0, если не проходился).
  int bestScore(String id) =>
      _ref.read(sharedPreferencesProvider).getInt(_bestScoreKey(id)) ?? 0;

  /// Лучшее время по уровню [id] в секундах (0 — нет рекорда).
  int bestTimeSeconds(String id) =>
      _ref.read(sharedPreferencesProvider).getInt(_bestTimeKey(id)) ?? 0;

  /// Фиксирует прохождение уровня [id]: обновляет «решён», лучший счёт/время.
  /// Возвращает `true`, если это ПЕРВОЕ прохождение (для выдачи монет).
  bool recordSolved(String id, int score, int timeSeconds) {
    final prefs = _ref.read(sharedPreferencesProvider);
    final solved = solvedIds();
    final first = !solved.contains(id);
    if (first) {
      solved.add(id);
      prefs.setStringList(_solvedKey, solved.toList());
    }
    if (score > bestScore(id)) prefs.setInt(_bestScoreKey(id), score);
    final prevTime = bestTimeSeconds(id);
    if (timeSeconds > 0 && (prevTime == 0 || timeSeconds < prevTime)) {
      prefs.setInt(_bestTimeKey(id), timeSeconds);
    }
    return first;
  }
}

/// Провайдер репозитория прогресса пазлов.
final puzzleStoreProvider = Provider<PuzzleStore>(PuzzleStore.new);
