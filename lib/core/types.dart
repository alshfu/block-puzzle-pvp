/// types.dart — базовые типы игрового ядра (порт типов из `src/core/index.ts`).
///
/// За что отвечает файл:
///   Определяет неизменяемые value-типы и конфигурацию правил, на которых
///   строится всё ядро: координата клетки [Coord], тип фигуры [PieceType],
///   экземпляр фигуры в руке [PieceInstance], правила партии [RuleConfig] и
///   дефолт [defaultConfig]. Эти типы — pure (без UI/IO), как требует ТЗ §6.1.
///
/// Соответствие TS:
///   PieceType / Coord / Cell / RuleConfig / DEFAULT_CONFIG / PieceInstance →
///   этот файл. Клетка доски [Cell] и [Board] объявлены в `board.dart`.
library;

/// Размер стороны доски (9×9). TS: `SIZE`.
const int boardSize = 9;

/// Семь тетромино. Имя enum (`PieceType.i.name == 'I'` после upper) совпадает
/// с буквенным кодом в TS (см. [pieceTypeCode]).
enum PieceType { i, o, t, s, z, j, l }

/// Все типы фигур в порядке TS `ALL_TYPES` (важно для детерминизма 7-bag).
const List<PieceType> allTypes = [
  PieceType.i,
  PieceType.o,
  PieceType.t,
  PieceType.s,
  PieceType.z,
  PieceType.j,
  PieceType.l,
];

/// Буквенный код фигуры ('I','O','T','S','Z','J','L'), как в TS-версии.
String pieceTypeCode(PieceType type) => type.name.toUpperCase();

/// Координата клетки `[row, col]`. Неизменяемая, со значимым равенством и
/// порядком (сначала по строке, затем по столбцу) — это нужно для нормализации
/// фигур и для совпадения с TS-сортировкой `a[0]-b[0] || a[1]-b[1]`.
class Coord implements Comparable<Coord> {
  /// Строка (row).
  final int r;

  /// Столбец (col).
  final int c;

  /// Создаёт координату.
  const Coord(this.r, this.c);

  @override
  int compareTo(Coord other) {
    if (r != other.r) return r - other.r;
    return c - other.c;
  }

  @override
  bool operator ==(Object other) =>
      other is Coord && other.r == r && other.c == c;

  @override
  int get hashCode => r * 31 + c;

  @override
  String toString() => '($r,$c)';
}

/// Экземпляр фигуры в руке игрока. TS: `PieceInstance`.
///
/// [id] — уникальный идентификатор экземпляра (`p0`, `p1`, …) для адресации в
/// руке; [type] — тип тетромино; [cells] — нормализованные клетки в текущей
/// ориентации.
class PieceInstance {
  /// Уникальный id экземпляра в руке.
  final String id;

  /// Тип тетромино.
  final PieceType type;

  /// Нормализованные клетки текущей ориентации.
  final List<Coord> cells;

  /// Создаёт экземпляр фигуры.
  const PieceInstance({
    required this.id,
    required this.type,
    required this.cells,
  });
}

/// Политика на таймауте хода (ТЗ §2.7.1). TS: `TimeoutPolicy`.
enum TimeoutPolicy { forcePlace, skip }

/// Уровень бота. TS: `BotLevel`.
enum BotLevel { easy, medium, hard }

/// Конфигурация правил партии. Неизменяемая; поля 1:1 с TS `RuleConfig`.
///
/// Поля сгруппированы как в TS:
///   handSize/rotationEnabled/flipEnabled/sharedBag — базовые правила руки и мешка;
///   comboEnabled/comboCap/comboStep/perfectClearBonus — комбо и perfect clear;
///   scoreRowPts/scoreColPts/scoreBoxPts/multiClearStep/comboExpStep/
///   speedBonusMax/placementBonus — расширенная система очков v1.5+;
///   turnTimer* / onTimeout — blitz-таймер (ядро лишь хранит параметры).
class RuleConfig {
  /// Размер руки K.
  final int handSize;

  /// Разрешены ли повороты фигур.
  final bool rotationEnabled;

  /// Разрешены ли отражения фигур.
  final bool flipEnabled;

  /// Общий мешок на двоих (`false` => у каждого свой).
  final bool sharedBag;

  /// Включено ли комбо.
  final bool comboEnabled;

  /// Потолок комбо-счётчика.
  final int comboCap;

  /// Линейный шаг комбо-мультипликатора.
  final double comboStep;

  /// Фиксированный бонус за perfect clear.
  final int perfectClearBonus;

  /// Базовые очки за очищенную строку.
  final int scoreRowPts;

  /// Базовые очки за очищенный столбец.
  final int scoreColPts;

  /// Базовые очки за очищенный бокс 3×3.
  final int scoreBoxPts;

  /// Прибавка мультипликатора за каждый clear сверх первого.
  final double multiClearStep;

  /// Экспоненциальная добавка к комбо: `comboExpStep * max(0, combo-3)^2`.
  final double comboExpStep;

  /// Максимальный speed-бонус при «моментальном» ходе.
  final double speedBonusMax;

  /// Placement-бонус по типу фигуры (даётся даже без очисток).
  final Map<PieceType, int> placementBonus;

  /// Включён ли blitz-таймер.
  final bool turnTimerEnabled;

  /// Секунд на первый ход.
  final double turnTimeStart;

  /// Сколько вычитать за каждый полный раунд.
  final double turnTimeDecay;

  /// Нижняя граница времени на ход.
  final double turnTimeMin;

  /// Что делать на таймауте.
  final TimeoutPolicy onTimeout;

  /// Создаёт конфигурацию правил (все поля обязательны для явности).
  const RuleConfig({
    required this.handSize,
    required this.rotationEnabled,
    required this.flipEnabled,
    required this.sharedBag,
    required this.comboEnabled,
    required this.comboCap,
    required this.comboStep,
    required this.perfectClearBonus,
    required this.scoreRowPts,
    required this.scoreColPts,
    required this.scoreBoxPts,
    required this.multiClearStep,
    required this.comboExpStep,
    required this.speedBonusMax,
    required this.placementBonus,
    required this.turnTimerEnabled,
    required this.turnTimeStart,
    required this.turnTimeDecay,
    required this.turnTimeMin,
    required this.onTimeout,
  });

  /// Возвращает копию с изменёнными полями (для настроек/онлайна; ядро не
  /// зависит от изменяемости — это удобный конструктор вариаций).
  RuleConfig copyWith({
    int? handSize,
    bool? rotationEnabled,
    bool? flipEnabled,
    bool? sharedBag,
    bool? comboEnabled,
    int? comboCap,
    double? comboStep,
    int? perfectClearBonus,
    int? scoreRowPts,
    int? scoreColPts,
    int? scoreBoxPts,
    double? multiClearStep,
    double? comboExpStep,
    double? speedBonusMax,
    Map<PieceType, int>? placementBonus,
    bool? turnTimerEnabled,
    double? turnTimeStart,
    double? turnTimeDecay,
    double? turnTimeMin,
    TimeoutPolicy? onTimeout,
  }) => RuleConfig(
    handSize: handSize ?? this.handSize,
    rotationEnabled: rotationEnabled ?? this.rotationEnabled,
    flipEnabled: flipEnabled ?? this.flipEnabled,
    sharedBag: sharedBag ?? this.sharedBag,
    comboEnabled: comboEnabled ?? this.comboEnabled,
    comboCap: comboCap ?? this.comboCap,
    comboStep: comboStep ?? this.comboStep,
    perfectClearBonus: perfectClearBonus ?? this.perfectClearBonus,
    scoreRowPts: scoreRowPts ?? this.scoreRowPts,
    scoreColPts: scoreColPts ?? this.scoreColPts,
    scoreBoxPts: scoreBoxPts ?? this.scoreBoxPts,
    multiClearStep: multiClearStep ?? this.multiClearStep,
    comboExpStep: comboExpStep ?? this.comboExpStep,
    speedBonusMax: speedBonusMax ?? this.speedBonusMax,
    placementBonus: placementBonus ?? this.placementBonus,
    turnTimerEnabled: turnTimerEnabled ?? this.turnTimerEnabled,
    turnTimeStart: turnTimeStart ?? this.turnTimeStart,
    turnTimeDecay: turnTimeDecay ?? this.turnTimeDecay,
    turnTimeMin: turnTimeMin ?? this.turnTimeMin,
    onTimeout: onTimeout ?? this.onTimeout,
  );
}

/// Дефолтная конфигурация правил. Значения 1:1 с TS `DEFAULT_CONFIG`
/// (и ТЗ §15) — обязаны совпадать.
const RuleConfig defaultConfig = RuleConfig(
  handSize: 3,
  rotationEnabled: true,
  flipEnabled: true,
  sharedBag: false,
  comboEnabled: true,
  comboCap: 10,
  comboStep: 0.1,
  perfectClearBonus: 25,
  scoreRowPts: 10,
  scoreColPts: 10,
  scoreBoxPts: 15,
  multiClearStep: 0.15,
  comboExpStep: 0.02,
  speedBonusMax: 0.4,
  placementBonus: {
    PieceType.i: 5,
    PieceType.l: 3,
    PieceType.j: 3,
    PieceType.t: 1,
    PieceType.s: 1,
    PieceType.z: 1,
    PieceType.o: 0,
  },
  turnTimerEnabled: true,
  turnTimeStart: 12.0,
  turnTimeDecay: 0.4,
  turnTimeMin: 3.0,
  onTimeout: TimeoutPolicy.forcePlace,
);
