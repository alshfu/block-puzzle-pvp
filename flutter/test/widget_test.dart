/// widget_test.dart — smoke-тест корневого виджета на стадии скелета.
///
/// За что отвечает файл:
///   Проверяет, что приложение собирается и рисует заглушку Фазы 0
///   ([MigrationPlaceholderApp]) без исключений. Реальные виджет-тесты
///   экранов появятся в Фазах 2+.
library;

import 'package:block_duel/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Заглушка миграции отображает название игры', (tester) async {
    // Рисуем корневой виджет и ждём первого кадра.
    await tester.pumpWidget(const MigrationPlaceholderApp());

    // На экране должно быть название игры и пометка фазы.
    expect(find.text('BlockDuel 9×9'), findsOneWidget);
    expect(find.textContaining('Phase 0'), findsOneWidget);
  });
}
