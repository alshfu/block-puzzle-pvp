/// online_wire_test.dart — тесты (де)сериализации wire-формата онлайна.
///
/// Проверяем бит-в-бит совместимость с Node-сервером: PieceType заглавными,
/// Coord как `[r,c]`, RuleConfig round-trip (placementBonus заглавными,
/// onTimeout "forcePlace", int→double), парсинг полного OnlineGameState из
/// JSON-сэмпла, форму moveToJson.
library;

import 'dart:convert';

import 'package:block_duel/core/core.dart';
import 'package:block_duel/online/online_models.dart';
import 'package:block_duel/online/online_wire.dart';
import 'package:flutter_test/flutter_test.dart';

import 'online_samples.dart';

/// Прогоняет [json] через jsonEncode/decode (как реальный провод).
Map<String, dynamic> _roundTrip(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group('PieceType wire-код', () {
    test('round-trip для всех 7 букв (lower↔upper)', () {
      for (final t in PieceType.values) {
        final code = pieceTypeCode(t); // 'I'..'L'
        expect(code, code.toUpperCase());
        expect(pieceTypeFromCode(code), t);
        expect(pieceTypeFromCode(code.toLowerCase()), t);
      }
    });
  });

  group('Coord', () {
    test('из/в массив [r,c]', () {
      expect(coordFromJson([3, 7]), const Coord(3, 7));
      expect(coordToJson(const Coord(3, 7)), [3, 7]);
    });
  });

  group('RuleConfig', () {
    test('round-trip toJson(fromJson) + int→double coercion', () {
      final wire = _roundTrip(sampleCfgJson());
      final cfg = ruleConfigFromJson(wire);
      // turnTimeStart пришёл int 60 → стал double.
      expect(cfg.turnTimeStart, 60.0);
      expect(cfg.onTimeout, TimeoutPolicy.forcePlace);
      expect(cfg.placementBonus[PieceType.i], 5);
      expect(cfg.placementBonus[PieceType.o], 0);

      // Обратно в JSON и снова в cfg — стабильно.
      final back = ruleConfigFromJson(_roundTrip(ruleConfigToJson(cfg)));
      expect(back.handSize, cfg.handSize);
      expect(back.comboStep, cfg.comboStep);
      expect(back.placementBonus, cfg.placementBonus);
      expect(back.onTimeout, cfg.onTimeout);
    });

    test('placementBonus сериализуется ЗАГЛАВНЫМИ ключами', () {
      final json = ruleConfigToJson(defaultConfig);
      final pb = json['placementBonus'] as Map<String, dynamic>;
      expect(pb.keys, containsAll(['I', 'O', 'T', 'S', 'Z', 'J', 'L']));
    });
  });

  group('OnlineGameState.fromJson', () {
    test('парсит полный сэмпл сервера', () {
      final s = OnlineGameState.fromJson(_roundTrip(sampleStateJson()));
      expect(s.matchId, 'm_abc_def');
      expect(s.board.length, 9);
      expect(s.board[0].length, 9);
      expect(s.players.length, 2);
      expect(s.players[0].nick, 'Алиса');
      expect(s.players[0].hand.length, 2);
      expect(s.players[0].hand[0].type, PieceType.t);
      expect(s.players[0].hand[0].cells.first, const Coord(0, 1));
      expect(s.current, 0);
      expect(s.status, 'playing');
      expect(s.isOver, isFalse);
      expect(s.turnTimeBaseMs, 60000);
      expect(s.cfg.handSize, 3);
      expect(s.result, isNull);
      expect(s.lastClearedCells, isNull);
    });

    test('парсит завершённый матч с result', () {
      final json = sampleStateJson(
        status: 'over',
        result: {
          'winner': 1,
          'scores': [30, 42],
          'reason': 'deadlock',
        },
      );
      final s = OnlineGameState.fromJson(_roundTrip(json));
      expect(s.isOver, isTrue);
      expect(s.result!.winner, 1);
      expect(s.result!.scores, [30, 42]);
      expect(s.result!.reason, 'deadlock');
    });
  });

  group('moveToJson', () {
    test('cells как [[r,c],...] и поля type/pieceId/r/c', () {
      final msg = moveToJson(
        pieceId: 'p0',
        cells: const [Coord(0, 1), Coord(1, 0)],
        r: 3,
        c: 4,
      );
      expect(msg['type'], 'move');
      expect(msg['pieceId'], 'p0');
      expect(msg['cells'], [
        [0, 1],
        [1, 0],
      ]);
      expect(msg['r'], 3);
      expect(msg['c'], 4);
    });
  });
}
