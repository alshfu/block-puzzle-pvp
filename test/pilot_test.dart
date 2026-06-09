/// pilot_test.dart — headless-зеркало pilot/E2E (запускается в обычном
/// `flutter test`, без устройства).
///
/// За что отвечает файл:
///   Тот же сквозной сценарий, что `integration_test/app_test.dart`, но на
///   `flutter_test` — чтобы pilot гонялся в обычном наборе тестов без реального
///   устройства (в этой среде device-прогон недоступен). Проверяет контур
///   View↔ViewModel↔Model: меню → навигация → hot-seat → выбор → постановка.
///
/// Соответствие TS: `tests/pilot.test.ts`. Реальный device/web-прогон — через
/// `integration_test/app_test.dart`.
library;

import 'package:block_duel/app.dart';
import 'package:block_duel/storage/prefs.dart';
import 'package:block_duel/ui/widgets/board_view.dart';
import 'package:block_duel/ui/widgets/hand_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  // reduceMotion → декоративный ThemeBackdrop не крутит Ticker (pumpAndSettle
  // на меню/профиле сходится); blitz-таймер игры гасится отдельными pump().
  SharedPreferences.setMockInitialValues({
    'bd_settings': '{"soundOn":true,"musicOn":false,"reduceMotion":true}',
  });
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
  testWidgets('pilot: меню → профиль → достижения → возврат', (tester) async {
    await _pumpApp(tester);
    expect(find.text('v2.0 · flutter migration'), findsOneWidget);

    await tester.tap(find.text('Игрок'));
    await tester.pumpAndSettle();
    expect(find.text('Профиль'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('🏆'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Достижения'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('v2.0 · flutter migration'), findsOneWidget);
  });

  testWidgets('pilot: hot-seat — выбор фигуры и постановка', (tester) async {
    // Портретный вьюпорт, чтобы игровой экран помещался без overflow.
    tester.view.physicalSize = const Size(450, 950);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);

    await tester.tap(find.text('▶ Играть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вдвоём'));
    await tester.pumpAndSettle();
    // Экран настройки матча → стартуем с дефолтами.
    expect(find.text('Настройка матча'), findsOneWidget);
    await tester.tap(find.text('Начать →'));
    // На игровом экране крутится blitz-таймер → pumpAndSettle зависнет;
    // используем pump с фиксированными интервалами.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(BoardView), findsOneWidget);
    expect(find.byType(HandView), findsOneWidget);

    final firstSlot = find
        .descendant(of: find.byType(HandView), matching: find.byType(InkWell))
        .first;
    await tester.tap(firstSlot);
    await tester.pump();
    expect(find.textContaining('повернуть'), findsOneWidget);

    final boardRect = tester.getRect(find.byType(BoardView));
    await tester.tapAt(boardRect.topLeft + const Offset(12, 12));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('← меню'), findsOneWidget);
    await tester.tap(find.text('← меню'));
    await tester.pumpAndSettle();
    expect(find.text('v2.0 · flutter migration'), findsOneWidget);
  });
}
