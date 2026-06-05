/// app_test.dart — pilot / E2E прогон приложения (эквивалент TS `?pilot=1`).
///
/// За что отвечает файл:
///   Гоняет РЕАЛЬНОЕ приложение как пользователь: запуск → меню → навигация в
///   профиль/достижения → старт hot-seat партии → выбор фигуры → постановка на
///   доску → возврат в меню. Проверяет, что весь контур View↔ViewModel↔Model
///   работает end-to-end без исключений.
///
/// Запуск:
///   flutter test integration_test/app_test.dart            (как widget-тест)
///   flutter test -d chrome integration_test/app_test.dart  (в браузере)
///
/// Соответствие TS: `src/ui/pilot/*` + `tests/pilot.test.ts` (драйв через
/// реальные PointerEvent). В Flutter драйвить in-app API не нужно —
/// integration_test работает с настоящими виджетами.
library;

import 'package:block_duel/app.dart';
import 'package:block_duel/storage/prefs.dart';
import 'package:block_duel/ui/widgets/board_view.dart';
import 'package:block_duel/ui/widgets/hand_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BlockDuelApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pilot: меню → профиль → достижения → возврат', (tester) async {
    await _pumpApp(tester);
    expect(find.text('v2.0 · flutter migration'), findsOneWidget);

    // Профиль открывается и возвращается.
    await tester.tap(find.text('Игрок'));
    await tester.pumpAndSettle();
    expect(find.text('Профиль'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Достижения открываются и возвращаются.
    await tester.tap(find.text('🏆'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Достижения'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('v2.0 · flutter migration'), findsOneWidget);
  });

  testWidgets('pilot: hot-seat — выбор фигуры и постановка на доску', (
    tester,
  ) async {
    await _pumpApp(tester);

    // Меню → Играть → Вдвоём (детерминированный режим без бота).
    await tester.tap(find.text('▶ Играть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вдвоём'));
    // На игровом экране крутится blitz-таймер → pumpAndSettle зависнет;
    // используем pump с фиксированными интервалами.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(BoardView), findsOneWidget);
    expect(find.byType(HandView), findsOneWidget);

    // Выбираем первую фигуру в руке (первый кликабельный слот).
    final firstSlot = find
        .descendant(of: find.byType(HandView), matching: find.byType(InkWell))
        .first;
    await tester.tap(firstSlot);
    await tester.pump();
    // Появилась подсказка про поворот/снятие — значит фигура выбрана.
    expect(find.textContaining('повернуть'), findsOneWidget);

    // Ставим её в верхний-левый угол доски (тап у начала доски).
    final boardRect = tester.getRect(find.byType(BoardView));
    await tester.tapAt(boardRect.topLeft + const Offset(12, 12));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // После хода всё ещё на игровом экране (есть кнопка возврата в меню).
    expect(find.text('← меню'), findsOneWidget);

    // Возврат в меню.
    await tester.tap(find.text('← меню'));
    await tester.pumpAndSettle();
    expect(find.text('v2.0 · flutter migration'), findsOneWidget);
  });
}
