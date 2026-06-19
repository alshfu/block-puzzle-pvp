/// rating_test.dart — тесты запроса оценки приложения (§ 11.5).
///
/// Проверяют: счётчик матчей и порог `shouldPrompt`, что «оценил»/«не
/// предлагать» закрывают запрос навсегда, а «позже» откладывает на N матчей.
library;

import 'package:block_duel/feedback/rating_controller.dart';
import 'package:block_duel/storage/prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('запрос появляется после порога матчей', () async {
    final c = await _container();
    final vm = c.read(ratingControllerProvider.notifier);
    expect(c.read(ratingControllerProvider).shouldPrompt, isFalse);
    for (int i = 0; i < ratingMatchThreshold; i++) {
      vm.recordMatch();
    }
    expect(c.read(ratingControllerProvider).matches, ratingMatchThreshold);
    expect(c.read(ratingControllerProvider).shouldPrompt, isTrue);
  });

  test('«оценил» закрывает запрос навсегда', () async {
    final c = await _container();
    final vm = c.read(ratingControllerProvider.notifier);
    for (int i = 0; i < ratingMatchThreshold; i++) {
      vm.recordMatch();
    }
    vm.markRated();
    expect(c.read(ratingControllerProvider).status, RatingStatus.rated);
    expect(c.read(ratingControllerProvider).shouldPrompt, isFalse);
  });

  test('«позже» откладывает на N матчей', () async {
    final c = await _container();
    final vm = c.read(ratingControllerProvider.notifier);
    for (int i = 0; i < ratingMatchThreshold; i++) {
      vm.recordMatch();
    }
    vm.snooze();
    expect(c.read(ratingControllerProvider).shouldPrompt, isFalse);
    for (int i = 0; i < ratingSnoozeMatches; i++) {
      vm.recordMatch();
    }
    expect(c.read(ratingControllerProvider).shouldPrompt, isTrue);
  });

  test('«не предлагать» закрывает запрос', () async {
    final c = await _container();
    final vm = c.read(ratingControllerProvider.notifier);
    for (int i = 0; i < ratingMatchThreshold; i++) {
      vm.recordMatch();
    }
    vm.markDismissed();
    expect(c.read(ratingControllerProvider).shouldPrompt, isFalse);
  });
}
