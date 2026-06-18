/// custom_theme_test.dart — тесты модели кастомной темы (§ 10.2).
///
/// Проверяют: создание от базового пресета (палитра = пресет), применение
/// переопределений в [CustomTheme.toTokens], и JSON round-trip.
library;

import 'package:block_duel/ui/design_tokens.dart';
import 'package:block_duel/ui/theme/custom_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromBase берёт палитру пресета', () {
    final ct = CustomTheme.fromBase('c1', 'Тест', ThemeId.night);
    expect(ct.p0, nightTheme.p0.toARGB32());
    expect(ct.bg, nightTheme.bg.toARGB32());
    expect(ct.base, ThemeId.night);
  });

  test('toTokens применяет переопределённые цвета и имя', () {
    final ct = CustomTheme.fromBase('c1', 'Моя', ThemeId.neutral)
        .copyWith(p0: const Color(0xFF112233).toARGB32(), label: 'Моя');
    final tk = ct.toTokens();
    expect(tk.label, 'Моя');
    expect(tk.p0.toARGB32(), const Color(0xFF112233).toARGB32());
    // Наследует шрифт/радиусы базы.
    expect(tk.fontDisplay, neutralTheme.fontDisplay);
    expect(tk.boardRadius, neutralTheme.boardRadius);
  });

  test('JSON round-trip', () {
    final ct = CustomTheme.fromBase('c9', 'RT', ThemeId.candy)
        .copyWith(p1: 0xFF00FF00, ink: 0xFF010203);
    final back = CustomTheme.fromJson(ct.toJson());
    expect(back.id, 'c9');
    expect(back.label, 'RT');
    expect(back.base, ThemeId.candy);
    expect(back.p1, 0xFF00FF00);
    expect(back.ink, 0xFF010203);
  });
}
