/// mascot_test.dart — тесты декоративных маскотов и пони.
///
/// Проверяем: все три варианта [Mascot] и [CartoonPony] рендерятся без
/// исключений (SVG-строки парсятся flutter_svg), и хелпер [darken] корректен.
library;

import 'package:block_duel/ui/decor/cartoon_pony.dart';
import 'package:block_duel/ui/decor/mascot.dart';
import 'package:block_duel/ui/design_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mascot рендерится во всех темах', () {
    for (final id in ThemeId.values) {
      testWidgets('тема ${id.name}', (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: Mascot(themeId: id, size: 120)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Mascot), findsOneWidget);
      });
    }
  });

  testWidgets('CartoonPony рендерится', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: CartoonPony(
            body: '#ff9ecb',
            mane: ['#ff6b8a', '#ffd166', '#7fe7df'],
            accent: '#b89cff',
            size: 140,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('darken', () {
    test('затемняет на долю к чёрному', () {
      expect(darken('#ffffff', 0.1), '#e6e6e6'); // 255*0.9 = 229.5 → 230
      expect(darken('#000000', 0.5), '#000000');
      expect(darken('#102030', 0.0), '#102030');
    });

    test('некорректный hex возвращается как есть', () {
      expect(darken('nope', 0.1), 'nope');
    });
  });
}
