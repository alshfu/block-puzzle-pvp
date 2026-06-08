/// settings_test.dart — тесты модели настроек (сериализация + дефолты).
///
/// Проверяем round-trip всех полей паритета и обратную совместимость со старым
/// JSON (только базовые тумблеры → расширенные поля берут дефолты).
library;

import 'package:block_duel/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trip всех полей', () {
    const s = Settings(
      soundOn: false,
      musicOn: true,
      reduceMotion: true,
      soundVolume: 0.3,
      musicVolume: 0.9,
      confettiEnabled: false,
      mascotsEnabled: false,
      ghostEnabled: false,
      vibration: VibrationMode.strong,
      botDelayMs: 600,
      defaultBotLevel: 'hard',
      defaultRotation: false,
      defaultFlip: false,
      defaultHandSize: 2,
      defaultBlitz: false,
      defaultBlitzPreset: 'casual',
    );
    final back = Settings.fromJson(s.toJson());
    expect(back.soundVolume, 0.3);
    expect(back.musicVolume, 0.9);
    expect(back.confettiEnabled, isFalse);
    expect(back.mascotsEnabled, isFalse);
    expect(back.ghostEnabled, isFalse);
    expect(back.vibration, VibrationMode.strong);
    expect(back.botDelayMs, 600);
    expect(back.defaultBotLevel, 'hard');
    expect(back.defaultHandSize, 2);
    expect(back.defaultBlitz, isFalse);
    expect(back.defaultBlitzPreset, 'casual');
  });

  test('старый JSON (только базовые) → дефолты для новых полей', () {
    final s = Settings.fromJson({
      'soundOn': true,
      'musicOn': false,
      'reduceMotion': true,
    });
    expect(s.soundOn, isTrue);
    expect(s.musicOn, isFalse);
    expect(s.reduceMotion, isTrue);
    // Новые поля — дефолты.
    expect(s.soundVolume, 0.7);
    expect(s.confettiEnabled, isTrue);
    expect(s.vibration, VibrationMode.light);
    expect(s.defaultBotLevel, 'medium');
    expect(s.botDelayMs, 350);
  });

  test('некорректная vibration → дефолт light', () {
    final s = Settings.fromJson({
      'soundOn': true,
      'musicOn': true,
      'reduceMotion': false,
      'vibration': 'nope',
    });
    expect(s.vibration, VibrationMode.light);
  });
}
