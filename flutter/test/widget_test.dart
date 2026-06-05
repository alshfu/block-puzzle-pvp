/// widget_test.dart — smoke-тест корневого приложения и меню.
///
/// За что отвечает файл:
///   Проверяет, что [BlockDuelApp] под `ProviderScope` собирается и рисует
///   главное меню без исключений (находит слоган и версию). Полные
///   golden-тесты MenuScreen в трёх темах — отдельной задачей (§6.8).
library;

import 'package:block_duel/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Меню рисуется: слоган и версия на месте', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BlockDuelApp()));
    await tester.pumpAndSettle();

    expect(
      find.text('дуэль на поле 9×9 · ставь, очищай, побеждай'),
      findsOneWidget,
    );
    expect(find.text('v2.0 · flutter migration'), findsOneWidget);
  });
}
