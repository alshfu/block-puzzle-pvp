/// puzzle_core.dart — pure-ядро режима «Силуэты» (Puzzle Silhouettes, Model).
///
/// За что отвечает файл:
///   Модель головоломки-силуэта (ROADMAP § 9.1): описание уровня [PuzzleDef]
///   (сетка W×H, маска-цель, эталонное решение-замощение), производные маска
///   ([PuzzleDef.mask]) и рука ([PuzzleDef.handShapeIds]), проверка постановки
///   только внутри маски ([puzzleCanPlace]), фиксация ([puzzlePlace]), проверка
///   решённости ([isPuzzleSolved]), бюджет ходов и скоринг ([puzzleScore],
///   [puzzleCoinReward]). (Де)сериализация уровня в JSON — для внешних паков и
///   будущего редактора. Всё чистое: без UI/IO/таймеров/`DateTime`/RNG.
///
/// Соответствие ROADMAP: § 9.1 (игровой режим), § 9.3 (JSON-схема уровня),
///   § 9.4 (скоринг/награда по сложности).
library;

import 'package:block_duel/core/core.dart';

/// Сложность головоломки (влияет на бюджет ходов, скоринг и награду).
enum PuzzleDifficulty { easy, medium, hard, expert }

/// Категория силуэта — для группировки в списке выбора.
enum PuzzleCategory { animals, objects, symbols }

/// Одна постановка эталонного решения: id фигуры и её абсолютные клетки на сетке.
class PuzzlePlacement {
  /// Идентификатор фигуры (`puzzleBaseShapes` ключ).
  final String shapeId;

  /// Абсолютные клетки на сетке (в координатах поля).
  final List<Coord> cells;

  /// Создаёт постановку.
  const PuzzlePlacement({required this.shapeId, required this.cells});

  /// JSON: `{"s": "T", "c": [[r,c],...]}`.
  Map<String, dynamic> toJson() => {
    's': shapeId,
    'c': [for (final cell in cells) [cell.r, cell.c]],
  };

  /// Восстанавливает из JSON.
  factory PuzzlePlacement.fromJson(Map<String, dynamic> json) =>
      PuzzlePlacement(
        shapeId: json['s'] as String,
        cells: [
          for (final pair in (json['c'] as List))
            Coord((pair as List)[0] as int, pair[1] as int),
        ],
      );
}

/// Описание уровня-силуэта.
class PuzzleDef {
  /// Стабильный id уровня.
  final String id;

  /// Отображаемое имя («Кот», «Домик»…).
  final String name;

  /// Категория.
  final PuzzleCategory category;

  /// Сложность.
  final PuzzleDifficulty difficulty;

  /// Ширина сетки (столбцов).
  final int width;

  /// Высота сетки (строк).
  final int height;

  /// Эталонное решение — замощение маски фигурами (гарантирует разрешимость).
  final List<PuzzlePlacement> solution;

  /// Создаёт описание уровня.
  const PuzzleDef({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.width,
    required this.height,
    required this.solution,
  });

  /// Клетки маски-цели — объединение клеток решения.
  Set<Coord> get mask => {for (final p in solution) ...p.cells};

  /// Рука игрока — мультимножество id фигур из решения (порядок решения).
  List<String> get handShapeIds => [for (final p in solution) p.shapeId];

  /// Число фигур (минимально необходимое число ходов).
  int get pieceCount => solution.length;

  /// JSON-схема уровня (§ 9.3).
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'difficulty': difficulty.name,
    'w': width,
    'h': height,
    'solution': [for (final p in solution) p.toJson()],
  };

  /// Восстанавливает уровень из JSON.
  factory PuzzleDef.fromJson(Map<String, dynamic> json) => PuzzleDef(
    id: json['id'] as String,
    name: json['name'] as String,
    category: PuzzleCategory.values.byName(json['category'] as String),
    difficulty: PuzzleDifficulty.values.byName(json['difficulty'] as String),
    width: json['w'] as int,
    height: json['h'] as int,
    solution: [
      for (final p in (json['solution'] as List))
        PuzzlePlacement.fromJson(p as Map<String, dynamic>),
    ],
  );
}

/// Создаёт пустое поле [height]×[width].
Board puzzleEmptyBoard(int width, int height) => [
  for (int r = 0; r < height; r++)
    [for (int c = 0; c < width; c++) Cell()],
];

/// Можно ли поставить фигуру [cells] с якорем `(r, c)`: каждая клетка лежит
/// ВНУТРИ маски [mask] и не занята. Клетки вне маски — заблокированы (§ 9.1).
bool puzzleCanPlace(
  Board board,
  Set<Coord> mask,
  List<Coord> cells,
  int r,
  int c,
) {
  for (final cell in cells) {
    final coord = Coord(r + cell.r, c + cell.c);
    if (!mask.contains(coord)) return false;
    if (coord.r < 0 || coord.r >= board.length) return false;
    if (coord.c < 0 || coord.c >= board[0].length) return false;
    if (board[coord.r][coord.c].filled) return false;
  }
  return true;
}

/// Ставит фигуру [cells] с якорем `(r, c)` от имени [owner] (цвет). Мутирует.
void puzzlePlace(Board board, List<Coord> cells, int r, int c, int owner) {
  for (final cell in cells) {
    board[r + cell.r][c + cell.c] = Cell(filled: true, owner: owner);
  }
}

/// Решена ли головоломка: каждая клетка маски [mask] заполнена. (Постановка
/// допускается только внутри маски, поэтому проверять «лишнее» не нужно.)
bool isPuzzleSolved(Board board, Set<Coord> mask) {
  for (final coord in mask) {
    if (!board[coord.r][coord.c].filled) return false;
  }
  return true;
}

/// Базовые очки за решённый уровень по сложности.
int _difficultyBase(PuzzleDifficulty d) => switch (d) {
  PuzzleDifficulty.easy => 100,
  PuzzleDifficulty.medium => 200,
  PuzzleDifficulty.hard => 350,
  PuzzleDifficulty.expert => 500,
};

/// Допустимый «люфт» лишних ходов (промахов) сверх минимума по сложности.
int _difficultySlack(PuzzleDifficulty d) => switch (d) {
  PuzzleDifficulty.easy => 6,
  PuzzleDifficulty.medium => 4,
  PuzzleDifficulty.hard => 3,
  PuzzleDifficulty.expert => 2,
};

/// Бюджет ходов уровня: минимум (число фигур) + люфт по сложности (§ 9.1).
int puzzleMoveBudget(PuzzleDef def) =>
    def.pieceCount + _difficultySlack(def.difficulty);

/// Очки за прохождение: база по сложности + бонус за неиспользованные ходы
/// (эффективность). [movesUsed] — сколько постановок сделано (промахи их тратят).
int puzzleScore(PuzzleDef def, int movesUsed) {
  final base = _difficultyBase(def.difficulty);
  final remaining = puzzleMoveBudget(def) - movesUsed;
  final bonus = remaining > 0 ? remaining * 20 : 0;
  return base + bonus;
}

/// Награда монетами за ПЕРВОЕ прохождение уровня (10–100 по сложности, § 9.4).
int puzzleCoinReward(PuzzleDifficulty d) => switch (d) {
  PuzzleDifficulty.easy => 10,
  PuzzleDifficulty.medium => 25,
  PuzzleDifficulty.hard => 50,
  PuzzleDifficulty.expert => 100,
};
