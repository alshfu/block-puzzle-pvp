/// widget_test.dart — smoke-тест корневого приложения и меню.
///
/// За что отвечает файл:
///   Проверяет, что [BlockDuelApp] под `ProviderScope` (с mock-хранилищем)
///   собирается и рисует главное меню без исключений (находит слоган и версию).
///   Полные golden-тесты MenuScreen в трёх темах — отдельной задачей (§6.8).
library;

import 'package:block_duel/app.dart';
import 'package:block_duel/storage/prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Меню рисуется: слоган и версия на месте', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const BlockDuelApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('дуэль на поле 9×9 · ставь, очищай, побеждай'),
      findsOneWidget,
    );
    expect(find.text('v2.0 · flutter migration'), findsOneWidget);
  });
}
