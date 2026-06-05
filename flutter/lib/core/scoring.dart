/// scoring.dart — система очков v1.5+ (порт scoring из `src/core/index.ts`).
///
/// За что отвечает файл:
///   Подсчёт очков за ход. Две функции: [scoreForMove] — упрощённый API без
///   разбивки (его зовёт бот, у которого нет данных про фигуру/таймер), и
///   [scoreMoveDetailed] — полная детализированная формула с breakdown для UI.
///   Формулы 1:1 с TS, включая округление `Math.round` (для положительных
///   значений эквивалентно `double.round()`).
///
/// Соответствие TS:
///   scoreForMove / ScoreInput / ScoreBreakdown / scoreMoveDetailed → этот файл.
library;

import 'types.dart';

/// Возводит неотрицательную базу комбо в квадрат: `max(0, combo-3)^2`.
/// Целочисленный квадрат — точный, без `pow`.
int _comboExcessSquared(int combo) {
  final excess = combo - 3 > 0 ? combo - 3 : 0;
  return excess * excess;
}

/// Базовый scoring (legacy, без breakdown), но по расширенной формуле v1.5+.
///
/// [n] — суммарное число очисток (строки+столбцы+боксы); [comboCounter] —
/// текущее комбо; [perfect] — был ли perfect clear. Бот сравнивает порядки
/// величин, поэтому box-бонус и распределение по типам линий здесь не нужны.
/// TS: `scoreForMove`.
int scoreForMove(int n, int comboCounter, bool perfect, RuleConfig cfg) {
  if (n == 0 && !perfect) return 0;
  final base = n * cfg.scoreRowPts;
  final multiClearMult = 1 + (n - 1 > 0 ? n - 1 : 0) * cfg.multiClearStep;
  final comboMult = cfg.comboEnabled
      ? 1 +
            cfg.comboStep *
                (comboCounter < cfg.comboCap ? comboCounter : cfg.comboCap) +
            cfg.comboExpStep * _comboExcessSquared(comboCounter)
      : 1;
  final perfectBonus = perfect ? cfg.perfectClearBonus : 0;
  return (base * multiClearMult * comboMult).round() + perfectBonus;
}

/// Входные данные для [scoreMoveDetailed]. TS: `ScoreInput`.
class ScoreInput {
  /// Число очищенных строк.
  final int rows;

  /// Число очищенных столбцов.
  final int cols;

  /// Число очищенных боксов 3×3.
  final int boxes;

  /// Тип поставленной фигуры (для placement-бонуса).
  final PieceType pieceType;

  /// Текущее комбо.
  final int combo;

  /// Был ли perfect clear.
  final bool perfect;

  /// Доля оставшегося времени хода (0..1) или `null`, если таймер выключен.
  final double? timeRatio;

  /// Правила партии.
  final RuleConfig cfg;

  /// Создаёт входные данные для подсчёта очков.
  const ScoreInput({
    required this.rows,
    required this.cols,
    required this.boxes,
    required this.pieceType,
    required this.combo,
    required this.perfect,
    required this.cfg,
    this.timeRatio,
  });
}

/// Детализация очков за ход. TS: `ScoreBreakdown`.
class ScoreBreakdown {
  /// Итоговые очки.
  final int total;

  /// Базовые очки за линии до мультипликаторов.
  final int base;

  /// Placement-бонус за тип фигуры.
  final int placement;

  /// Мультипликатор за multi-clear.
  final double multiClearMult;

  /// Комбо-мультипликатор (линейный + экспоненциальный после 3).
  final double comboMult;

  /// Speed-мультипликатор (≤ 1 + speedBonusMax).
  final double speedMult;

  /// Бонус за perfect clear.
  final int perfectBonus;

  /// Создаёт разбивку очков.
  const ScoreBreakdown({
    required this.total,
    required this.base,
    required this.placement,
    required this.multiClearMult,
    required this.comboMult,
    required this.speedMult,
    required this.perfectBonus,
  });
}

/// Полная детализированная формула v1.5+:
///   base       = rows*scoreRowPts + cols*scoreColPts + boxes*scoreBoxPts
///   multiClear = 1 + max(0, N-1) * multiClearStep
///   combo      = 1 + comboStep*min(combo,cap) + comboExpStep*max(0, combo-3)^2
///   speed      = 1 + speedBonusMax * max(0, timeRatio-0.5)*2   (timeRatio>0.5)
///   total      = round(base*multiClear*combo*speed) + placement + perfectBonus
///
/// Placement-бонус начисляется всегда (за активность), даже без очисток.
/// TS: `scoreMoveDetailed`.
ScoreBreakdown scoreMoveDetailed(ScoreInput input) {
  final cfg = input.cfg;
  final n = input.rows + input.cols + input.boxes;
  final base =
      input.rows * cfg.scoreRowPts +
      input.cols * cfg.scoreColPts +
      input.boxes * cfg.scoreBoxPts;
  final multiClearMult = 1 + (n - 1 > 0 ? n - 1 : 0) * cfg.multiClearStep;
  final comboMult = cfg.comboEnabled
      ? 1 +
            cfg.comboStep *
                (input.combo < cfg.comboCap ? input.combo : cfg.comboCap) +
            cfg.comboExpStep * _comboExcessSquared(input.combo)
      : 1;

  var speedMult = 1.0;
  final ratio = input.timeRatio;
  if (cfg.turnTimerEnabled && ratio != null && ratio.isFinite) {
    final r = ratio < 0 ? 0.0 : (ratio > 1 ? 1.0 : ratio);
    if (r > 0.5) speedMult = 1 + cfg.speedBonusMax * (r - 0.5) * 2;
  }

  final placement = cfg.placementBonus[input.pieceType] ?? 0;
  final perfectBonus = input.perfect ? cfg.perfectClearBonus : 0;
  final total =
      (base * multiClearMult * comboMult * speedMult).round() +
      placement +
      perfectBonus;

  return ScoreBreakdown(
    total: total,
    base: base,
    placement: placement,
    multiClearMult: multiClearMult.toDouble(),
    comboMult: comboMult.toDouble(),
    speedMult: speedMult,
    perfectBonus: perfectBonus,
  );
}
