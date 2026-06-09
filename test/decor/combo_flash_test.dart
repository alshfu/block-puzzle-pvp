/// combo_flash_test.dart — тесты вспышки комбо и каталога сообщений.
///
/// Проверяем: [comboMessages] покрывает все темы/уровни; [pickComboMessage]
/// детерминированно выбирает из нужного пула при сидированном Random; виджет
/// [ComboFlash] рендерится, показывает сообщение и зовёт onComplete по таймауту.
library;

import 'dart:math';

import 'package:block_duel/ui/decor/combo_flash.dart';
import 'package:block_duel/ui/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('comboMessages / pickComboMessage', () {
    test('каждая тема имеет уровни 1..3 по 3 сообщения', () {
      for (final id in ThemeId.values) {
        for (final level in [1, 2, 3]) {
          expect(comboMessages[id]![level]!.length, 3);
        }
      }
    });

    test('pickComboMessage берёт из нужного пула', () {
      for (final id in ThemeId.values) {
        for (final level in [1, 2, 3]) {
          final msg = pickComboMessage(id, level, Random(1));
          expect(comboMessages[id]![level], contains(msg));
        }
      }
    });

    test('сидированный Random даёт детерминированный выбор', () {
      final a = pickComboMessage(ThemeId.candy, 2, Random(42));
      final b = pickComboMessage(ThemeId.candy, 2, Random(42));
      expect(a, b);
    });
  });

  testWidgets('ComboFlash показывает сообщение и завершается', (tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [blockDuelThemes[ThemeId.neutral]!]),
        home: Scaffold(
          body: ComboFlash(
            themeId: ThemeId.neutral,
            level: 2,
            combo: 5,
            message: 'EXCELLENT',
            onComplete: () => done = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('EXCELLENT'), findsOneWidget);
    expect(find.text('комбо ×5'), findsOneWidget);
    expect(done, isFalse);

    // По истечении 1.7с вспышка зовёт onComplete.
    await tester.pump(const Duration(milliseconds: 1700));
    expect(done, isTrue);
  });
}
