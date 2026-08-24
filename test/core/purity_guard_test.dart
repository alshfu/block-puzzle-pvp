/// purity_guard_test.dart — статический страж чистоты pure-слоя (детерминизм).
///
/// За что отвечает файл:
///   Гарантирует, что игровое ядро (`lib/core/`) и pure-ядра режимов
///   (`*_core.dart`, генераторы, composite-score) НЕ содержат источников
///   недетерминизма — `Random()` (dart:math) и `DateTime.now()`/`DateTime()` —
///   и не импортируют Flutter/UI/IO. Это машинная страховка требования из
///   CLAUDE.md/ТЗ §6.1 и behavior_core_determinism: одинаковый (seed, cfg, log)
///   → одинаковое состояние (реплеи, server-authoritative онлайн, golden-тесты,
///   анти-чит). Ловит будущие регрессии, которые не поймает обычный тест.
///
///   Сканирует ИСХОДНИКИ файлов (dart:io), а не поведение. ViewModel-нотифайеры
///   и виджеты НЕ проверяются — им можно таймеры/DateTime (презентационный слой).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pure-файлы, обязанные оставаться детерминированными.
const _pureFiles = <String>[
  'lib/core/bag.dart',
  'lib/core/board.dart',
  'lib/core/bot.dart',
  'lib/core/core.dart',
  'lib/core/moves.dart',
  'lib/core/pieces.dart',
  'lib/core/rng.dart',
  'lib/core/scoring.dart',
  'lib/core/timer.dart',
  'lib/core/types.dart',
  'lib/modes/ladder/composite_score.dart',
  'lib/modes/coop/coop_core.dart',
  'lib/modes/match3/match3_core.dart',
  'lib/modes/memory_solo/memory_solo_puzzle.dart',
  'lib/modes/puzzle/puzzle_core.dart',
  'lib/modes/puzzle/puzzle_generator.dart',
  'lib/modes/tetris/tetris_core.dart',
];

/// Удаляет строковые литералы и комментарии, чтобы не ловить слова в тексте
/// (например «Random» в доккоменте или строке-описании).
String _stripNoise(String src) {
  final noLineComments = src.replaceAll(RegExp(r'//[^\n]*'), '');
  final noBlockComments =
      noLineComments.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final noStrings = noBlockComments
      .replaceAll(RegExp(r"'(?:\\.|[^'\\])*'"), "''")
      .replaceAll(RegExp(r'"(?:\\.|[^"\\])*"'), '""');
  return noStrings;
}

void main() {
  group('чистота pure-слоя (детерминизм)', () {
    for (final rel in _pureFiles) {
      test('$rel — без Random()/DateTime.now()/Flutter/dart:io', () {
        final file = File(rel);
        expect(file.existsSync(), isTrue, reason: '$rel не найден');
        final code = _stripNoise(file.readAsStringSync());

        expect(code.contains(RegExp(r'\bRandom\s*\(')), isFalse,
            reason: '$rel: dart:math Random() запрещён — используй makeRng(seed)');
        expect(code.contains(RegExp(r'\bDateTime\s*\.\s*now\s*\(')), isFalse,
            reason: '$rel: DateTime.now() запрещён в pure-слое');
        expect(code.contains(RegExp(r'\bnew\s+DateTime\s*\(|\bDateTime\s*\(')),
            isFalse,
            reason: '$rel: конструирование DateTime запрещён в pure-слое');
        expect(code.contains("package:flutter/"), isFalse,
            reason: '$rel: импорт Flutter в pure-слое запрещён');
        expect(code.contains("dart:io"), isFalse,
            reason: '$rel: dart:io в pure-слое запрещён');
        expect(code.contains("dart:html"), isFalse,
            reason: '$rel: dart:html в pure-слое запрещён');
      });
    }
  });
}
