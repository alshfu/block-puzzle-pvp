/// online_samples.dart — образцы wire-JSON сервера для тестов.
///
/// Формы соответствуют `party/protocol.ts` (OnlineGameState и сообщения).
/// Прогоняются через jsonEncode/decode в тестах, чтобы поймать несовпадение
/// типов (int vs double) как на реальном проводе.
library;

/// Пустая доска 9×9 в wire-формате (`Cell[][]`).
List<List<Map<String, dynamic>>> emptyBoardJson() => [
  for (int r = 0; r < 9; r++)
    [
      for (int c = 0; c < 9; c++) {'filled': false, 'owner': null},
    ],
];

/// cfg в wire-формате (1:1 с DEFAULT_CONFIG; double-поля как числа).
Map<String, dynamic> sampleCfgJson() => {
  'handSize': 3,
  'rotationEnabled': true,
  'flipEnabled': true,
  'sharedBag': false,
  'comboEnabled': true,
  'comboCap': 10,
  'comboStep': 0.1,
  'perfectClearBonus': 25,
  'scoreRowPts': 10,
  'scoreColPts': 10,
  'scoreBoxPts': 15,
  'multiClearStep': 0.15,
  'comboExpStep': 0.02,
  'speedBonusMax': 0.4,
  'placementBonus': {'I': 5, 'L': 3, 'J': 3, 'T': 1, 'S': 1, 'Z': 1, 'O': 0},
  'turnTimerEnabled': true,
  // turnTimeStart как целое число (int) — проверяем int→double coercion.
  'turnTimeStart': 60,
  'turnTimeDecay': 0.4,
  'turnTimeMin': 3.0,
  'onTimeout': 'forcePlace',
};

/// Рука из двух фигур в wire-формате (type — ЗАГЛАВНАЯ буква, cells — `[[r,c]]`).
List<Map<String, dynamic>> sampleHandJson() => [
  {
    'id': 'p0',
    'type': 'T',
    'cells': [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, 2],
    ],
  },
  {
    'id': 'p1',
    'type': 'I',
    'cells': [
      [0, 0],
      [0, 1],
      [0, 2],
      [0, 3],
    ],
  },
];

/// Образец OnlineGameState (как в `joined`/`state`).
Map<String, dynamic> sampleStateJson({
  String status = 'playing',
  int current = 0,
  Map<String, dynamic>? result,
  String matchId = 'm_abc_def',
  List<List<int>>? lastClearedCells,
}) => {
  'matchId': matchId,
  'board': emptyBoardJson(),
  'lastClearedCells': ?lastClearedCells,
  'players': [
    {
      'id': 'u-a',
      'nick': 'Алиса',
      'avatar': '🦊',
      'score': 30,
      'combo': 1,
      'hand': sampleHandJson(),
    },
    {
      'id': 'u-b',
      'nick': 'Боб',
      'avatar': '🐼',
      'score': 15,
      'combo': 0,
      'hand': sampleHandJson(),
    },
  ],
  'current': current,
  'turnCount': 4,
  'status': status,
  'result': ?result,
  'turnTimeRemainingMs': 45000,
  'turnTimeBaseMs': 60000,
  'cfg': sampleCfgJson(),
};
