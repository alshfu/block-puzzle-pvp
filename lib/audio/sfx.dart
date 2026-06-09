/// sfx.dart — каталог звуковых эффектов (Model-слой аудио).
///
/// За что отвечает файл:
///   Описывает каждый игровой звук набором [ToneSpec] — те же частоты,
///   длительности, формы и тайминги, что в TS `src/ui/audio.ts`. Чистые данные:
///   ни плагинов, ни состояния. [AudioService] рендерит их в WAV и проигрывает.
///
/// Соответствие TS: `playPlace/playInvalid/playClear/playPerfect/playWin/
/// playLose/playDraw/playTick/playClick`.
library;

import 'synth.dart';

/// Идентификатор звукового эффекта без параметров (для кэша WAV-байтов).
enum Sfx { place, invalid, perfect, win, lose, draw, tick, click }

/// Постановка фигуры: короткий мягкий «щелчок».
List<ToneSpec> sfxPlace() => const [
  ToneSpec(freq: 280, duration: 0.08, type: Wave.triangle, gain: 0.08),
];

/// Недопустимый ход: два низких «пилёных» тона внахлёст.
List<ToneSpec> sfxInvalid() => const [
  ToneSpec(freq: 140, duration: 0.18, type: Wave.sawtooth, gain: 0.09),
  ToneSpec(
    freq: 110,
    duration: 0.18,
    type: Wave.sawtooth,
    gain: 0.06,
    start: 0.04,
  ),
];

/// Восходящие ноты аккорда G-мажор: `n` единиц → `n` нот (1..8).
const List<double> _clearScale = [
  392, // G4
  494, // B4
  587, // D5
  698, // F5
  784, // G5
  880, // A5
  988, // B5
  1047, // C6
];

/// Очистка: число очищенных линий [n] → восходящий аккорд из `clamp(n, 1, 8)`.
List<ToneSpec> sfxClear(int n) {
  final count = n.clamp(1, _clearScale.length);
  return [
    for (int i = 0; i < count; i++)
      ToneSpec(
        freq: _clearScale[i],
        duration: 0.25,
        type: Wave.triangle,
        gain: 0.07,
        start: i * 0.06,
      ),
  ];
}

/// Perfect clear: мажорное арпеджио вверх C5 E5 G5 C6 E6.
List<ToneSpec> sfxPerfect() => const [
  ToneSpec(freq: 523, duration: 0.32, type: Wave.triangle, gain: 0.09),
  ToneSpec(
    freq: 659,
    duration: 0.32,
    type: Wave.triangle,
    gain: 0.09,
    start: 0.08,
  ),
  ToneSpec(
    freq: 784,
    duration: 0.32,
    type: Wave.triangle,
    gain: 0.09,
    start: 0.16,
  ),
  ToneSpec(
    freq: 1047,
    duration: 0.32,
    type: Wave.triangle,
    gain: 0.09,
    start: 0.24,
  ),
  ToneSpec(
    freq: 1319,
    duration: 0.32,
    type: Wave.triangle,
    gain: 0.09,
    start: 0.32,
  ),
];

/// Победа: аккорд C-мажор вверх.
List<ToneSpec> sfxWin() => const [
  ToneSpec(freq: 523, duration: 0.32, type: Wave.triangle, gain: 0.09),
  ToneSpec(
    freq: 659,
    duration: 0.32,
    type: Wave.triangle,
    gain: 0.09,
    start: 0.12,
  ),
  ToneSpec(
    freq: 784,
    duration: 0.32,
    type: Wave.triangle,
    gain: 0.09,
    start: 0.24,
  ),
  ToneSpec(
    freq: 1047,
    duration: 0.32,
    type: Wave.triangle,
    gain: 0.09,
    start: 0.36,
  ),
];

/// Поражение: нисходящая последовательность.
List<ToneSpec> sfxLose() => const [
  ToneSpec(freq: 392, duration: 0.4, type: Wave.sine, gain: 0.09),
  ToneSpec(freq: 330, duration: 0.4, type: Wave.sine, gain: 0.09, start: 0.15),
  ToneSpec(freq: 262, duration: 0.4, type: Wave.sine, gain: 0.09, start: 0.30),
  ToneSpec(freq: 196, duration: 0.4, type: Wave.sine, gain: 0.09, start: 0.45),
];

/// Ничья: два ровных тона внахлёст.
List<ToneSpec> sfxDraw() => const [
  ToneSpec(freq: 392, duration: 0.4, type: Wave.sine, gain: 0.08),
  ToneSpec(freq: 494, duration: 0.4, type: Wave.sine, gain: 0.08, start: 0.1),
];

/// Тик таймера в danger-зоне.
List<ToneSpec> sfxTick() => const [
  ToneSpec(freq: 880, duration: 0.05, type: Wave.square, gain: 0.04),
];

/// Клик по элементу UI.
List<ToneSpec> sfxClick() => const [
  ToneSpec(freq: 660, duration: 0.04, type: Wave.square, gain: 0.04),
];

/// Возвращает тоны для параметр-независимого эффекта [sfx].
List<ToneSpec> tonesFor(Sfx sfx) => switch (sfx) {
  Sfx.place => sfxPlace(),
  Sfx.invalid => sfxInvalid(),
  Sfx.perfect => sfxPerfect(),
  Sfx.win => sfxWin(),
  Sfx.lose => sfxLose(),
  Sfx.draw => sfxDraw(),
  Sfx.tick => sfxTick(),
  Sfx.click => sfxClick(),
};
