/// synth.dart — чистый синтез звука в PCM/WAV (Model-слой аудио).
///
/// За что отвечает файл:
///   Повторяет «вживую» синтез из TS `src/ui/audio.ts`: осциллятор (sine/
///   triangle/sawtooth/square) + amplitude-envelope (линейная атака 0→peak за
///   10 мс, экспоненциальный спад peak→0.0001 за `duration`). Несколько тонов с
///   разным `start` смешиваются в один буфер. Результат — WAV-байты (моно,
///   16-bit PCM), которые проигрывает [AudioService] из памяти.
///
/// Чистая (без `dart:ui`, плагинов, часов): один и тот же набор [ToneSpec] →
/// одинаковые байты. Тестируется без платформы.
///
/// Соответствие TS: функция `tone()` (Web Audio: `linearRampToValueAtTime`
/// до peak за 0.01с, затем `exponentialRampToValueAtTime(0.0001, duration)`).
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Форма волны осциллятора (имена совпадают с Web Audio `OscillatorType`).
enum Wave { sine, triangle, sawtooth, square }

/// Один синтезируемый тон: частота, длительность, форма, пиковая громкость и
/// сдвиг старта внутри буфера (для аккордов/арпеджио).
class ToneSpec {
  /// Частота, Гц.
  final double freq;

  /// Длительность затухания (с) — до уровня 0.0001 по экспоненте.
  final double duration;

  /// Форма волны.
  final Wave type;

  /// Пиковая громкость до домножения на общий volume (как `gain` в TS).
  final double gain;

  /// Сдвиг старта тона от начала буфера, с.
  final double start;

  /// Создаёт описание тона.
  const ToneSpec({
    required this.freq,
    required this.duration,
    this.type = Wave.sine,
    this.gain = 0.1,
    this.start = 0,
  });
}

/// Частота дискретизации по умолчанию.
const int defaultSampleRate = 44100;

/// Длительность атаки по умолчанию (с) — линейный подъём 0→peak. SFX-значение
/// из TS (`tone()`: 0.01). Музыка задаёт своё (`playNote`: 0.03).
const double defaultAttack = 0.01;

/// «Хвост» по умолчанию после затухания, как `osc.stop(t0 + dur + 0.02)`. Музыка
/// использует 0.08 (`playNote`).
const double defaultTail = 0.02;

/// Минимальный уровень экспоненциального спада (Web Audio не допускает 0).
const double _floor = 0.0001;

/// Возвращает мгновенное значение осциллятора [type] для фазы-в-периодах [x]
/// (x = freq * t; целая часть = число пройденных периодов).
double _osc(Wave type, double x) {
  switch (type) {
    case Wave.sine:
      return math.sin(2 * math.pi * x);
    case Wave.square:
      return math.sin(2 * math.pi * x) >= 0 ? 1.0 : -1.0;
    case Wave.sawtooth:
      // Пила -1..1: дробная часть, центрированная вокруг нуля.
      return 2 * (x - (x + 0.5).floorToDouble());
    case Wave.triangle:
      final saw = 2 * (x - (x + 0.5).floorToDouble());
      return 2 * saw.abs() - 1;
  }
}

/// Огибающая громкости тона на локальном времени [local] (с от старта тона):
/// линейная атака за [attack], затем экспоненциальный спад к [_floor] за
/// `duration`, потом короткий хвост [tail]. Множитель в [0, peak]; вне — 0.
double _envelope(
  double local,
  double duration,
  double peak,
  double attack,
  double tail,
) {
  if (local < 0) return 0;
  if (local < attack) return peak * (local / attack);
  if (local <= duration) {
    final span = duration - attack;
    if (span <= 0) return _floor;
    final frac = (local - attack) / span;
    return peak * math.pow(_floor / peak, frac).toDouble();
  }
  if (local <= duration + tail) return _floor; // короткий хвост
  return 0;
}

/// Синтезирует тоны [tones] (с общим множителем громкости [volume]) в один
/// моно-буфер float-сэмплов в [-1, 1].
///
/// Длина — до конца самого позднего тона, либо ровно [totalDuration] секунд,
/// если задано (нужно для бесшовного зацикливания музыки: буфер = длине цикла,
/// хвосты крайних нот обрезаются). [attack]/[tail] переопределяют огибающую
/// (музыка: 0.03/0.08; SFX: дефолты).
Float64List renderSamples(
  List<ToneSpec> tones, {
  double volume = 0.7,
  int sampleRate = defaultSampleRate,
  double attack = defaultAttack,
  double tail = defaultTail,
  double? totalDuration,
}) {
  if (tones.isEmpty && totalDuration == null) return Float64List(0);
  final int n;
  if (totalDuration != null) {
    n = (totalDuration * sampleRate).ceil();
  } else {
    var maxEnd = 0.0;
    for (final t in tones) {
      final end = t.start + t.duration + tail;
      if (end > maxEnd) maxEnd = end;
    }
    n = (maxEnd * sampleRate).ceil();
  }
  final out = Float64List(n);
  for (final t in tones) {
    final peak = t.gain * volume;
    if (peak <= 0) continue;
    final startSample = (t.start * sampleRate).floor();
    final endSample = math.min(
      n,
      ((t.start + t.duration + tail) * sampleRate).ceil(),
    );
    for (int i = math.max(0, startSample); i < endSample; i++) {
      final local = (i - startSample) / sampleRate;
      final env = _envelope(local, t.duration, peak, attack, tail);
      if (env == 0) continue;
      out[i] += env * _osc(t.type, t.freq * local);
    }
  }
  // Мягкое ограничение, чтобы сумма тонов не клиппила за [-1, 1].
  for (int i = 0; i < n; i++) {
    final v = out[i];
    if (v > 1) {
      out[i] = 1;
    } else if (v < -1) {
      out[i] = -1;
    }
  }
  return out;
}

/// Кодирует float-сэмплы [samples] в WAV-байты (моно, 16-bit PCM, [sampleRate]).
Uint8List encodeWav(Float64List samples, {int sampleRate = defaultSampleRate}) {
  const channels = 1;
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataBytes = samples.length * blockAlign;
  final buffer = ByteData(44 + dataBytes);

  void writeAscii(int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      buffer.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  buffer.setUint32(4, 36 + dataBytes, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  buffer.setUint32(16, 16, Endian.little); // PCM chunk size
  buffer.setUint16(20, 1, Endian.little); // audio format = PCM
  buffer.setUint16(22, channels, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, byteRate, Endian.little);
  buffer.setUint16(32, blockAlign, Endian.little);
  buffer.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  buffer.setUint32(40, dataBytes, Endian.little);

  var offset = 44;
  for (int i = 0; i < samples.length; i++) {
    final clamped = samples[i] < -1
        ? -1.0
        : (samples[i] > 1 ? 1.0 : samples[i]);
    final intVal = (clamped * 32767).round();
    buffer.setInt16(offset, intVal, Endian.little);
    offset += 2;
  }
  return buffer.buffer.asUint8List();
}

/// Удобный шорткат: тоны → WAV-байты.
Uint8List renderWav(
  List<ToneSpec> tones, {
  double volume = 0.7,
  int sampleRate = defaultSampleRate,
}) => encodeWav(
  renderSamples(tones, volume: volume, sampleRate: sampleRate),
  sampleRate: sampleRate,
);
