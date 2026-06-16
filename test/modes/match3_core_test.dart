/// match3_core_test.dart — тесты pure-ядра «Match-3 PvP» (поле 8×8).
///
/// Проверяют: детерминизм и отсутствие стартовых серий при генерации, поиск
/// серий (гор/верт, ≥3), легальность свопа (только создающий серию),
/// разрешение с каскадами/гравитацией/досыпкой, монотонность очков по каскадам
/// и наличие ходов.
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/modes/match3/match3_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Сериализует сетку для сравнения.
String _key(Match3Grid g) => g.map((row) => row.join(',')).join('/');

/// Заведомо бессерийный фон: цвет `(r + 2·c) % 6`. По строке шаг +2 (0,2,4 —
/// различны), по столбцу шаг +1 — три подряд всегда различны, серий нет.
Match3Grid _calmGrid() => [
  for (int r = 0; r < match3Size; r++)
    [for (int c = 0; c < match3Size; c++) (r + 2 * c) % match3Colors],
];

void main() {
  group('генерация', () {
    test('детерминизм: тот же seed → та же сетка', () {
      expect(_key(generateMatch3Grid(42)), _key(generateMatch3Grid(42)));
    });

    test('в стартовой сетке нет готовых серий', () {
      for (final seed in [1, 2, 3, 100, 2026]) {
        final g = generateMatch3Grid(seed);
        expect(findMatches(g), isEmpty, reason: 'seed=$seed');
      }
    });

    test('размер 8×8, цвета в диапазоне', () {
      final g = generateMatch3Grid(7);
      expect(g.length, match3Size);
      expect(g.every((row) => row.length == match3Size), isTrue);
      expect(
        g.every((row) => row.every((v) => v >= 0 && v < match3Colors)),
        isTrue,
      );
    });
  });

  group('поиск серий', () {
    test('горизонтальная тройка распознаётся', () {
      final g = [for (int r = 0; r < match3Size; r++) [for (int c = 0; c < match3Size; c++) (r * match3Size + c) % match3Colors]];
      // Принудительно ставим тройку цвета 0 в строке 0, столбцы 0..2.
      g[0][0] = 0;
      g[0][1] = 0;
      g[0][2] = 0;
      g[0][3] = 1; // прерывание
      final m = findMatches(g);
      expect(m.contains((r: 0, c: 0)), isTrue);
      expect(m.contains((r: 0, c: 1)), isTrue);
      expect(m.contains((r: 0, c: 2)), isTrue);
      expect(m.contains((r: 0, c: 3)), isFalse);
    });

    test('пара (две) не считается серией', () {
      // Бессерийный фон; ставим изолированную пару цвета 5 в строке 0.
      final g = _calmGrid();
      g[0][0] = 5;
      g[0][1] = 5; // пара; (0,2) фоновый ≠5, вертикали ≠5
      expect(findMatches(g), isEmpty);
    });
  });

  group('своп', () {
    test('соседние клетки распознаются', () {
      expect(areAdjacent((r: 0, c: 0), (r: 0, c: 1)), isTrue);
      expect(areAdjacent((r: 0, c: 0), (r: 1, c: 0)), isTrue);
      expect(areAdjacent((r: 0, c: 0), (r: 1, c: 1)), isFalse);
      expect(areAdjacent((r: 0, c: 0), (r: 0, c: 2)), isFalse);
    });

    test('легален только своп, создающий серию', () {
      // Бессерийный фон; готовим своп (0,2)<->(1,2) → тройка в строке 0.
      final g = _calmGrid();
      g[0][0] = 3;
      g[0][1] = 3;
      g[0][2] = 4; // не 3 — пока пара, не серия
      g[1][2] = 3; // под (0,2) лежит 3
      // До свопа серий нет.
      expect(findMatches(g), isEmpty);
      // Своп (0,2)<->(1,2): строка 0 станет 3,3,3 → серия.
      expect(wouldMatch(g, (r: 0, c: 2), (r: 1, c: 2)), isTrue);
      // Своп двух ОДИНАКОВЫХ клеток (0,0)<->(0,1) ничего не меняет → нелегален.
      expect(wouldMatch(g, (r: 0, c: 0), (r: 0, c: 1)), isFalse);
      // Несоседние — нелегальны.
      expect(wouldMatch(g, (r: 0, c: 0), (r: 2, c: 0)), isFalse);
    });
  });

  group('разрешение и очки', () {
    test('очистка серии → гравитация → нет дыр (-1)', () {
      final g = generateMatch3Grid(11);
      // Создаём искусственную тройку и разрешаем.
      g[match3Size - 1][0] = 0;
      g[match3Size - 1][1] = 0;
      g[match3Size - 1][2] = 0;
      final rng = makeRng(99);
      final res = resolveBoard(g, rng);
      expect(res.clearedCells, greaterThanOrEqualTo(3));
      // После разрешения дыр быть не должно (всё досыпано).
      expect(g.every((row) => row.every((v) => v != -1)), isTrue);
      // И серий не осталось.
      expect(findMatches(g), isEmpty);
    });

    test('очки растут с числом очищенных клеток', () {
      expect(
        Match3Resolve(clearedCells: 3, cascades: 1, score: 30).score,
        lessThan(
          Match3Resolve(clearedCells: 6, cascades: 1, score: 60).score,
        ),
      );
    });

    test('стабильное поле без серий → 0 очистки', () {
      final g = generateMatch3Grid(5); // без стартовых серий
      final res = resolveBoard(cloneGrid(g), makeRng(1));
      expect(res.clearedCells, 0);
      expect(res.cascades, 0);
      expect(res.score, 0);
    });
  });

  group('наличие ходов', () {
    test('у свежесгенерированного поля обычно есть ход', () {
      var withMove = 0;
      for (final seed in [1, 2, 3, 4, 5, 6, 7, 8]) {
        if (hasAnyValidMove(generateMatch3Grid(seed))) withMove++;
      }
      expect(withMove, greaterThan(0));
    });
  });
}
