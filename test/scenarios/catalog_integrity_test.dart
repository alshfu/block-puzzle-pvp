/// catalog_integrity_test.dart — страж целостности сценарных каталогов.
///
/// За что отвечает файл:
///   Гарантирует правило «1000 и 1»: каждый сгенерированный каталог в qa/
///   (`SCENARIOS_APP.md`, `SCENARIOS_MODE_<id>.md` ×13, `SCENARIOS_CODE_<p>.md`
///   ×4) содержит РОВНО 1001 сценарий с уникальными ID. Ловит дрейф
///   генератора tools/gen_scenarios.py (например если правка области собьёт
///   счётчик) до попадания в прод. См. project_scenarios_1001.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _target = 1001;

/// Ожидаемые каталоги: (файл, префикс ID).
final _catalogs = <(String, String)>[
  ('qa/SCENARIOS_APP.md', 'APP'),
  for (final id in [
    'bot', 'hotseat', 'arcade', 'botvbot', 'online', 'memorySolo',
    'memoryDuel', 'coop', 'match3', 'tetris', 'puzzle', 'showcase', 'tutorial',
  ])
    ('qa/SCENARIOS_MODE_$id.md', 'MODE-${_upper(id)}'),
  for (final p in ['web', 'macos', 'android', 'ios'])
    ('qa/SCENARIOS_CODE_$p.md', 'CODE-${p.toUpperCase()}'),
];

String _upper(String id) => id.toUpperCase();

void main() {
  group('целостность каталогов «1000 и 1»', () {
    for (final (path, prefix) in _catalogs) {
      test('$path — ровно $_target сценариев с уникальными ID', () {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path не найден (запусти gen_scenarios.py)');
        final text = file.readAsStringSync();
        // Только жирная нумерованная форма **PREFIX-NNNN** (упоминания префикса
        // в шапке-интро без ** не считаем).
        final re = RegExp(r'\*\*' + RegExp.escape(prefix) + r'-(\d{4})\*\*');
        final ids = re.allMatches(text).map((m) => m.group(1)!).toList();
        expect(ids.length, _target,
            reason: '$path: найдено ${ids.length} ID, ожидалось $_target');
        expect(ids.toSet().length, _target, reason: '$path: есть дубли ID');
        // Нумерация сплошная 0001..1001.
        expect(ids.first, '0001');
        expect(ids.last, _target.toString().padLeft(4, '0'));
      });
    }

    test('всего 18 каталогов (1 app + 13 mode + 4 platform)', () {
      expect(_catalogs.length, 18);
    });

    test('каждый режим реестра game_mode_descriptor имеет каталог', () {
      final descriptor = File('lib/modes/game_mode_descriptor.dart');
      expect(descriptor.existsSync(), isTrue);
      final ids = RegExp(r"id:\s*'([^']+)'")
          .allMatches(descriptor.readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();
      expect(ids, isNotEmpty);
      for (final id in ids) {
        expect(File('qa/SCENARIOS_MODE_$id.md').existsSync(), isTrue,
            reason: 'режим «$id» из реестра без каталога — запусти gen_scenarios.py '
                'и добавь профиль в MODE_PROFILES');
      }
    });
  });
}
