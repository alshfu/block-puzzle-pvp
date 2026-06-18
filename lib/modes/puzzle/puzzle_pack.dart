/// puzzle_pack.dart — стартовый контент-пак силуэтов (Model, данные).
///
/// За что отвечает файл:
///   Авторский набор уровней-силуэтов (ROADMAP § 9.3). Каждый силуэт задаётся
///   ASCII-арт-маской (`#` — клетка цели), а эталонное замощение (и тем самым
///   рука игрока) строится детерминированно из маски генератором
///   [tilePuzzle] — поэтому уровни гарантированно разрешимы, а добавить новый =
///   дописать ASCII + метаданные (или загрузить внешний JSON-пак через
///   `PuzzleDef.fromJson`). Категории/сложности — для списка выбора и скоринга.
///
/// Соответствие ROADMAP: § 9.3 (контент-пак, расширяемый; JSON — в `PuzzleDef`).
library;

import 'package:block_duel/core/core.dart';

import 'puzzle_core.dart';
import 'puzzle_generator.dart';

/// Маска из ASCII-арта: `#` — клетка цели, прочее — пусто. Ширина = самая
/// длинная строка, высота = число строк. Возвращает (маска, ширина, высота).
({Set<Coord> mask, int width, int height}) _maskFromAscii(List<String> rows) {
  final mask = <Coord>{};
  var width = 0;
  for (int r = 0; r < rows.length; r++) {
    final row = rows[r];
    if (row.length > width) width = row.length;
    for (int c = 0; c < row.length; c++) {
      if (row[c] == '#') mask.add(Coord(r, c));
    }
  }
  return (mask: mask, width: width, height: rows.length);
}

/// Собирает [PuzzleDef] из ASCII-силуэта: маска → детерминированное замощение
/// (seed фиксирован на уровень) → решение/рука. Чистая функция входов.
PuzzleDef _puzzle({
  required String id,
  required String name,
  required PuzzleCategory category,
  required PuzzleDifficulty difficulty,
  required int seed,
  required List<String> art,
}) {
  final m = _maskFromAscii(art);
  final solution = tilePuzzle(m.mask, difficulty, seed);
  return PuzzleDef(
    id: id,
    name: name,
    category: category,
    difficulty: difficulty,
    width: m.width,
    height: m.height,
    solution: solution,
  );
}

/// Стартовый пак силузтов (расширяемый — добавьте запись ниже либо JSON-пак).
final List<PuzzleDef> puzzlePack = [
  // ── Символы ───────────────────────────────────────────────────────────────
  _puzzle(
    id: 'sym-cross',
    name: 'Крест',
    category: PuzzleCategory.symbols,
    difficulty: PuzzleDifficulty.easy,
    seed: 1001,
    art: const [
      '..#..',
      '..#..',
      '#####',
      '..#..',
      '..#..',
    ],
  ),
  _puzzle(
    id: 'sym-diamond',
    name: 'Ромб',
    category: PuzzleCategory.symbols,
    difficulty: PuzzleDifficulty.easy,
    seed: 1002,
    art: const [
      '...#...',
      '..###..',
      '.#####.',
      '#######',
      '.#####.',
      '..###..',
      '...#...',
    ],
  ),
  _puzzle(
    id: 'sym-arrow',
    name: 'Стрелка',
    category: PuzzleCategory.symbols,
    difficulty: PuzzleDifficulty.medium,
    seed: 1003,
    art: const [
      '...#...',
      '..###..',
      '.#####.',
      '#######',
      '...#...',
      '...#...',
      '...#...',
    ],
  ),
  _puzzle(
    id: 'sym-heart',
    name: 'Сердце',
    category: PuzzleCategory.symbols,
    difficulty: PuzzleDifficulty.medium,
    seed: 1004,
    art: const [
      '.##..##.',
      '########',
      '########',
      '########',
      '.######.',
      '..####..',
      '...##...',
    ],
  ),
  _puzzle(
    id: 'sym-star',
    name: 'Звезда',
    category: PuzzleCategory.symbols,
    difficulty: PuzzleDifficulty.hard,
    seed: 1005,
    art: const [
      '...#...',
      '..###..',
      '#######',
      '.#####.',
      '..###..',
      '.##.##.',
      '##...##',
    ],
  ),
  _puzzle(
    id: 'sym-letter-a',
    name: 'Буква А',
    category: PuzzleCategory.symbols,
    difficulty: PuzzleDifficulty.expert,
    seed: 1006,
    art: const [
      '..###..',
      '.#...#.',
      '.#...#.',
      '.#####.',
      '.#...#.',
      '.#...#.',
    ],
  ),
  // ── Объекты ─────────────────────────────────────────────────────────────────
  _puzzle(
    id: 'obj-cup',
    name: 'Кружка',
    category: PuzzleCategory.objects,
    difficulty: PuzzleDifficulty.easy,
    seed: 2001,
    art: const [
      '######.',
      '#####.#',
      '#####.#',
      '######.',
      '.####..',
    ],
  ),
  _puzzle(
    id: 'obj-house',
    name: 'Домик',
    category: PuzzleCategory.objects,
    difficulty: PuzzleDifficulty.medium,
    seed: 2002,
    art: const [
      '...###...',
      '..#####..',
      '.#######.',
      '#########',
      '.#######.',
      '.##...##.',
      '.##...##.',
    ],
  ),
  _puzzle(
    id: 'obj-tree',
    name: 'Ёлка',
    category: PuzzleCategory.objects,
    difficulty: PuzzleDifficulty.medium,
    seed: 2003,
    art: const [
      '...##...',
      '..####..',
      '.######.',
      '########',
      '.######.',
      '...##...',
      '...##...',
    ],
  ),
  _puzzle(
    id: 'obj-boat',
    name: 'Кораблик',
    category: PuzzleCategory.objects,
    difficulty: PuzzleDifficulty.hard,
    seed: 2004,
    art: const [
      '...#....',
      '...##...',
      '...###..',
      '...#....',
      '########',
      '.######.',
    ],
  ),
  _puzzle(
    id: 'obj-rocket',
    name: 'Ракета',
    category: PuzzleCategory.objects,
    difficulty: PuzzleDifficulty.hard,
    seed: 2005,
    art: const [
      '..#..',
      '.###.',
      '.###.',
      '.###.',
      '#####',
      '#.#.#',
    ],
  ),
  _puzzle(
    id: 'obj-key',
    name: 'Ключ',
    category: PuzzleCategory.objects,
    difficulty: PuzzleDifficulty.expert,
    seed: 2006,
    art: const [
      '.###.',
      '#...#',
      '#...#',
      '.###.',
      '..#..',
      '..##.',
      '..#..',
      '..##.',
    ],
  ),
  // ── Животные ────────────────────────────────────────────────────────────────
  _puzzle(
    id: 'ani-fish',
    name: 'Рыбка',
    category: PuzzleCategory.animals,
    difficulty: PuzzleDifficulty.easy,
    seed: 3001,
    art: const [
      '.####.#',
      '#######',
      '#######',
      '.####.#',
    ],
  ),
  _puzzle(
    id: 'ani-cat',
    name: 'Кот',
    category: PuzzleCategory.animals,
    difficulty: PuzzleDifficulty.medium,
    seed: 3002,
    art: const [
      '#.....#',
      '##...##',
      '#######',
      '#######',
      '.#####.',
      '.#####.',
    ],
  ),
  _puzzle(
    id: 'ani-bird',
    name: 'Птичка',
    category: PuzzleCategory.animals,
    difficulty: PuzzleDifficulty.hard,
    seed: 3003,
    art: const [
      '.##.....',
      '####....',
      '######..',
      '.#######',
      '..####..',
      '...#.#..',
    ],
  ),
];

/// Уровни заданной сложности (для группировки в списке выбора).
List<PuzzleDef> puzzlesByDifficulty(PuzzleDifficulty d) =>
    [for (final p in puzzlePack) if (p.difficulty == d) p];

/// Уровень по id (или `null`).
PuzzleDef? puzzleById(String id) {
  for (final p in puzzlePack) {
    if (p.id == id) return p;
  }
  return null;
}
