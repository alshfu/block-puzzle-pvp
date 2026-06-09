/// online_wire.dart — (де)сериализация wire-формата ↔ типы ядра (граница).
///
/// За что отвечает файл:
///   Переводит JSON-сообщения Node-сервера в чистые типы ядра и обратно. Ядро
///   остаётся без JSON-зависимостей — вся сериализация изолирована здесь. Имена
///   и формы соблюдены бит-в-бит с `party/protocol.ts` + `src/core`:
///     • PieceType на проводе — ЗАГЛАВНАЯ буква ('I'..'L'); enum-имена строчные;
///     • Coord на проводе — массив `[r, c]` (в ядре — `Coord{r,c}`);
///     • Cell = `{filled, owner|null}`; Board = `Cell[][]` 9×9;
///     • RuleConfig — те же ключи, `placementBonus` ЗАГЛАВНЫМИ, double-поля
///       могут прийти как int → приводим `(v as num).toDouble()`;
///     • onTimeout = `"forcePlace"`/`"skip"` совпадает с `TimeoutPolicy.name`.
///
/// Соответствие TS: `party/protocol.ts`, `src/core` (типы и DEFAULT_CONFIG).
library;

import 'package:block_duel/core/core.dart';

/// Тип фигуры по wire-коду ('I'..'L', регистр любой).
PieceType pieceTypeFromCode(String code) =>
    PieceType.values.byName(code.toLowerCase());

/// Координата из wire-массива `[r, c]`.
Coord coordFromJson(List<dynamic> json) =>
    Coord((json[0] as num).toInt(), (json[1] as num).toInt());

/// Координата в wire-массив `[r, c]`.
List<int> coordToJson(Coord coord) => [coord.r, coord.c];

/// Клетка доски из `{filled, owner}`.
Cell cellFromJson(Map<String, dynamic> json) => Cell(
  filled: json['filled'] as bool,
  owner: (json['owner'] as num?)?.toInt(),
);

/// Доска 9×9 из `Cell[][]`.
Board boardFromJson(List<dynamic> json) => [
  for (final row in json)
    [
      for (final cell in row as List<dynamic>)
        cellFromJson(cell as Map<String, dynamic>),
    ],
];

/// Экземпляр фигуры из `{id, type, cells}`.
PieceInstance pieceInstanceFromJson(Map<String, dynamic> json) => PieceInstance(
  id: json['id'] as String,
  type: pieceTypeFromCode(json['type'] as String),
  cells: [
    for (final c in json['cells'] as List<dynamic>)
      coordFromJson(c as List<dynamic>),
  ],
);

/// Правила партии из wire-объекта. double-поля приводятся из num, чтобы JSON
/// `int` (например `comboStep: 0`) не падал.
RuleConfig ruleConfigFromJson(Map<String, dynamic> json) {
  double d(String key) => (json[key] as num).toDouble();
  int i(String key) => (json[key] as num).toInt();
  return RuleConfig(
    handSize: i('handSize'),
    rotationEnabled: json['rotationEnabled'] as bool,
    flipEnabled: json['flipEnabled'] as bool,
    sharedBag: json['sharedBag'] as bool,
    comboEnabled: json['comboEnabled'] as bool,
    comboCap: i('comboCap'),
    comboStep: d('comboStep'),
    perfectClearBonus: i('perfectClearBonus'),
    scoreRowPts: i('scoreRowPts'),
    scoreColPts: i('scoreColPts'),
    scoreBoxPts: i('scoreBoxPts'),
    multiClearStep: d('multiClearStep'),
    comboExpStep: d('comboExpStep'),
    speedBonusMax: d('speedBonusMax'),
    placementBonus: {
      for (final entry
          in (json['placementBonus'] as Map<String, dynamic>).entries)
        pieceTypeFromCode(entry.key): (entry.value as num).toInt(),
    },
    turnTimerEnabled: json['turnTimerEnabled'] as bool,
    turnTimeStart: d('turnTimeStart'),
    turnTimeDecay: d('turnTimeDecay'),
    turnTimeMin: d('turnTimeMin'),
    onTimeout: TimeoutPolicy.values.byName(json['onTimeout'] as String),
  );
}

/// Правила партии в wire-объект (нужно для round-trip тестов; клиент обычно
/// шлёт лишь [RequestedCfg], а не полный cfg).
Map<String, dynamic> ruleConfigToJson(RuleConfig cfg) => {
  'handSize': cfg.handSize,
  'rotationEnabled': cfg.rotationEnabled,
  'flipEnabled': cfg.flipEnabled,
  'sharedBag': cfg.sharedBag,
  'comboEnabled': cfg.comboEnabled,
  'comboCap': cfg.comboCap,
  'comboStep': cfg.comboStep,
  'perfectClearBonus': cfg.perfectClearBonus,
  'scoreRowPts': cfg.scoreRowPts,
  'scoreColPts': cfg.scoreColPts,
  'scoreBoxPts': cfg.scoreBoxPts,
  'multiClearStep': cfg.multiClearStep,
  'comboExpStep': cfg.comboExpStep,
  'speedBonusMax': cfg.speedBonusMax,
  'placementBonus': {
    for (final entry in cfg.placementBonus.entries)
      pieceTypeCode(entry.key): entry.value,
  },
  'turnTimerEnabled': cfg.turnTimerEnabled,
  'turnTimeStart': cfg.turnTimeStart,
  'turnTimeDecay': cfg.turnTimeDecay,
  'turnTimeMin': cfg.turnTimeMin,
  'onTimeout': cfg.onTimeout.name,
};

/// Сообщение хода в wire-объект (`cells` — массив `[[r,c],...]`).
Map<String, dynamic> moveToJson({
  required String pieceId,
  required List<Coord> cells,
  required int r,
  required int c,
}) => {
  'type': 'move',
  'pieceId': pieceId,
  'cells': [for (final cell in cells) coordToJson(cell)],
  'r': r,
  'c': c,
};
