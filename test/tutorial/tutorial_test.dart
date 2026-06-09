/// tutorial_test.dart — тесты ViewModel обучения (Фаза параритета).
///
/// За что отвечает файл:
///   Проверяет загрузку шагов, достижение цели «закрой строку», прогресс,
///   переход между шагами и одноразовую выдачу награды по завершении.
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/profile/profile_controller.dart';
import 'package:block_duel/storage/prefs.dart';
import 'package:block_duel/tutorial/tutorial_controller.dart';
import 'package:block_duel/tutorial/tutorial_steps.dart';
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
  test('старт на шаге 0 с подсказкой и нулевым прогрессом', () async {
    final c = await _container();
    final st = c.read(tutorialControllerProvider);
    expect(st.stepIdx, 0);
    expect(st.doneStep, isFalse);
    expect(st.statusMsg, tutorialSteps[0].hint);
    expect(st.progress, 0.0);
  });

  test('шаг 1 «поставь фигуру» завершается любым ходом', () async {
    final c = await _container();
    final vm = c.read(tutorialControllerProvider.notifier);
    final st = c.read(tutorialControllerProvider);
    final piece = st.game.currentPlayer.hand.first;
    vm.selectPiece(piece.id);
    // Любой допустимый якорь.
    final cells = c.read(tutorialControllerProvider).game.activeCells!;
    int? ar, ac;
    outer:
    for (int r = 0; r < boardSize; r++) {
      for (int col = 0; col < boardSize; col++) {
        if (canPlace(c.read(tutorialControllerProvider).game.board, cells, r,
            col)) {
          ar = r;
          ac = col;
          break outer;
        }
      }
    }
    vm.placeAt(ar!, ac!);
    expect(c.read(tutorialControllerProvider).doneStep, isTrue);
  });

  test('next переключает шаг; завершение выдаёт награду один раз', () async {
    final c = await _container();
    final vm = c.read(tutorialControllerProvider.notifier);
    final coins0 = c.read(profileControllerProvider).coins;

    // Прокрутим до последнего шага (без прохождения целей — проверяем механику
    // навигации, doneStep не требуется для next в этом тесте, поэтому форсим).
    for (int i = 0; i < tutorialSteps.length - 1; i++) {
      final finished = vm.next();
      expect(finished, isFalse);
      expect(c.read(tutorialControllerProvider).stepIdx, i + 1);
    }
    // На последнем шаге next завершает и даёт награду.
    expect(vm.next(), isTrue);
    expect(
      c.read(profileControllerProvider).coins,
      coins0 + tutorialRewardCoins,
    );

    // Повторное завершение награду не дублирует (флаг в prefs).
    final coinsAfter = c.read(profileControllerProvider).coins;
    final c2 = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
    addTearDown(c2.dispose);
    // Доберёмся до конца снова в новом контейнере (тот же prefs).
    final vm2 = c2.read(tutorialControllerProvider.notifier);
    for (int i = 0; i < tutorialSteps.length - 1; i++) {
      vm2.next();
    }
    vm2.next();
    expect(c2.read(profileControllerProvider).coins, coinsAfter);
  });
}
