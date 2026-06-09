/// music.dart — фоновые темы-мелодии (Model-слой аудио, чистый).
///
/// За что отвечает файл:
///   Порт `src/ui/music.ts`: по теме описывает трек (bpm + голоса из нот) и
///   рендерит ОДИН цикл трека в WAV-байты переиспользуя [synth.dart]. В TS
///   планировщик подкладывает ноты вперёд в Web Audio; здесь эквивалент —
///   готовый зацикливаемый буфер (один проход всех голосов = один блок
///   `scheduleLoop`), который [MusicService] проигрывает в петле.
///
/// Чистый (без плагинов/часов): трек → одинаковые байты. Огибающая нот —
/// атака 0.03 / хвост 0.08 (как `playNote`), длина буфера = длине цикла
/// (бесшовная петля, см. `totalDuration` в [renderSamples]).
///
/// Соответствие TS: `music.ts` (TRACKS, n(), scheduleLoop, playNote).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../ui/design_tokens.dart' show ThemeId;
import 'synth.dart';

/// Базовая частота A4.
const double _a4 = 440;

/// Метка паузы в нотной записи.
const String rest = 'R';

/// Частота ноты по имени (`C5`, `F#4`, `Bb3`); `0`, если пауза/не распознано.
double noteFreq(String name) {
  final m = RegExp(r'^([A-G])([#b]?)(-?\d+)$').firstMatch(name);
  if (m == null) return 0;
  final letter = m.group(1)!;
  final acc = m.group(2)!;
  final oct = int.parse(m.group(3)!);
  const base = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2};
  final semitones =
      base[letter]! +
      (acc == '#'
          ? 1
          : acc == 'b'
          ? -1
          : 0) +
      (oct - 4) * 12;
  return _a4 * math.pow(2, semitones / 12);
}

/// Нота: имя (или [rest]) + длительность в долях такта (beat).
class MusicNote {
  final String name;
  final double d;
  const MusicNote(this.name, this.d);
}

/// Голос трека: форма волны, базовая громкость, сдвиг октав, последовательность.
class MusicVoice {
  final Wave type;
  final double gain;
  final int oct;
  final List<MusicNote> notes;
  const MusicVoice({
    required this.type,
    required this.gain,
    required this.notes,
    this.oct = 0,
  });
}

/// Трек темы: темп + голоса.
class MusicTrack {
  final int bpm;
  final List<MusicVoice> voices;
  const MusicTrack({required this.bpm, required this.voices});
}

/// Треки по темам (1:1 с TS `TRACKS`).
const Map<ThemeId, MusicTrack> tracks = {
  // Neutral — synthwave-ambient, минорное настроение, спокойная пульсация.
  ThemeId.neutral: MusicTrack(
    bpm: 92,
    voices: [
      MusicVoice(
        type: Wave.triangle,
        gain: 0.05,
        notes: [
          MusicNote('A2', 4),
          MusicNote('F2', 4),
          MusicNote('G2', 4),
          MusicNote('E2', 4),
        ],
      ),
      MusicVoice(
        type: Wave.triangle,
        gain: 0.045,
        notes: [
          MusicNote('A4', 1),
          MusicNote('C5', 1),
          MusicNote('E5', 1),
          MusicNote('A5', 1),
          MusicNote('F4', 1),
          MusicNote('A4', 1),
          MusicNote('C5', 1),
          MusicNote('F5', 1),
          MusicNote('G4', 1),
          MusicNote('B4', 1),
          MusicNote('D5', 1),
          MusicNote('G5', 1),
          MusicNote('E4', 1),
          MusicNote('G4', 1),
          MusicNote('B4', 1),
          MusicNote('E5', 1),
        ],
      ),
      MusicVoice(
        type: Wave.sine,
        gain: 0.055,
        notes: [
          MusicNote(rest, 8),
          MusicNote('E6', 2),
          MusicNote(rest, 2),
          MusicNote('D6', 2),
          MusicNote('E6', 2),
        ],
      ),
    ],
  ),

  // Candy — светлая мажорная карусель, чуть быстрее.
  ThemeId.candy: MusicTrack(
    bpm: 116,
    voices: [
      MusicVoice(
        type: Wave.triangle,
        gain: 0.04,
        notes: [
          MusicNote('C3', 2),
          MusicNote('G3', 2),
          MusicNote('F3', 2),
          MusicNote('C4', 2),
          MusicNote('A2', 2),
          MusicNote('E3', 2),
          MusicNote('G3', 2),
          MusicNote('D4', 2),
        ],
      ),
      MusicVoice(
        type: Wave.sine,
        gain: 0.06,
        notes: [
          MusicNote('C5', 0.5),
          MusicNote('E5', 0.5),
          MusicNote('G5', 0.5),
          MusicNote('C6', 0.5),
          MusicNote('G5', 0.5),
          MusicNote('E5', 0.5),
          MusicNote('C5', 0.5),
          MusicNote('E5', 0.5),
          MusicNote('F5', 0.5),
          MusicNote('A5', 0.5),
          MusicNote('C6', 0.5),
          MusicNote('F6', 0.5),
          MusicNote('C6', 0.5),
          MusicNote('A5', 0.5),
          MusicNote('F5', 0.5),
          MusicNote('A5', 0.5),
          MusicNote('A5', 0.5),
          MusicNote('C6', 0.5),
          MusicNote('E6', 0.5),
          MusicNote('A6', 0.5),
          MusicNote('E6', 0.5),
          MusicNote('C6', 0.5),
          MusicNote('A5', 0.5),
          MusicNote('C6', 0.5),
          MusicNote('G5', 0.5),
          MusicNote('B5', 0.5),
          MusicNote('D6', 0.5),
          MusicNote('G6', 0.5),
          MusicNote('D6', 0.5),
          MusicNote('B5', 0.5),
          MusicNote('G5', 0.5),
          MusicNote('B5', 0.5),
        ],
      ),
      MusicVoice(
        type: Wave.triangle,
        gain: 0.04,
        notes: [
          MusicNote(rest, 4),
          MusicNote('E6', 0.5),
          MusicNote(rest, 3.5),
          MusicNote(rest, 4),
          MusicNote('G6', 0.5),
          MusicNote(rest, 3.5),
        ],
      ),
    ],
  ),

  // Night — неон-нуар, тёмно, пульсирующий бас, готически-восточный лад.
  ThemeId.night: MusicTrack(
    bpm: 80,
    voices: [
      MusicVoice(
        type: Wave.sawtooth,
        gain: 0.04,
        notes: [
          MusicNote('D2', 0.5),
          MusicNote(rest, 0.5),
          MusicNote('D2', 0.5),
          MusicNote(rest, 0.5),
          MusicNote('D2', 0.5),
          MusicNote(rest, 0.5),
          MusicNote('D2', 0.5),
          MusicNote(rest, 0.5),
          MusicNote('C2', 0.5),
          MusicNote(rest, 0.5),
          MusicNote('C2', 0.5),
          MusicNote(rest, 0.5),
          MusicNote('Bb2', 0.5),
          MusicNote(rest, 0.5),
          MusicNote('A2', 0.5),
          MusicNote(rest, 0.5),
        ],
      ),
      MusicVoice(
        type: Wave.square,
        gain: 0.055,
        notes: [
          MusicNote('D4', 2),
          MusicNote('F4', 1),
          MusicNote('A4', 1),
          MusicNote('Bb4', 2),
          MusicNote('A4', 2),
          MusicNote('G4', 1),
          MusicNote('F4', 1),
          MusicNote('E4', 1),
          MusicNote('F4', 1),
          MusicNote('D4', 4),
        ],
      ),
      MusicVoice(
        type: Wave.triangle,
        gain: 0.03,
        notes: [
          MusicNote(rest, 12),
          MusicNote('F5', 1),
          MusicNote('A5', 1),
          MusicNote('D6', 2),
        ],
      ),
    ],
  ),
};

/// Длина цикла трека в долях такта (максимум по голосам).
double _loopBeats(MusicTrack track) {
  var maxBeats = 0.0;
  for (final v in track.voices) {
    var beats = 0.0;
    for (final note in v.notes) {
      beats += note.d;
    }
    if (beats > maxBeats) maxBeats = beats;
  }
  return maxBeats;
}

/// Рендерит один цикл [track] в WAV-байты (моно, 16-bit). Громкость нот — их
/// `gain` (общий мастер-уровень задаёт плеер); огибающая как у `playNote`.
Uint8List renderTrack(MusicTrack track, {int sampleRate = defaultSampleRate}) {
  final beat = 60 / track.bpm;
  final loopSeconds = _loopBeats(track) * beat;
  final tones = <ToneSpec>[];
  for (final v in track.voices) {
    final octMult = math.pow(2, v.oct).toDouble();
    var t = 0.0;
    for (final note in v.notes) {
      final dur = note.d * beat;
      final f = noteFreq(note.name);
      if (f > 0) {
        tones.add(
          ToneSpec(
            freq: f * octMult,
            duration: dur,
            type: v.type,
            gain: v.gain,
            start: t,
          ),
        );
      }
      t += dur;
    }
  }
  final samples = renderSamples(
    tones,
    volume: 1.0,
    sampleRate: sampleRate,
    attack: 0.03,
    tail: 0.08,
    totalDuration: loopSeconds,
  );
  return encodeWav(samples, sampleRate: sampleRate);
}
