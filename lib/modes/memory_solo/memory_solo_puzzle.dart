/// memory_solo_puzzle.dart — pure-ядро режима «Память: соло» (Model-слой).
///
/// За что отвечает файл:
///   Детерминированная генерация задачи на память и её оценка. Игроку на
///   несколько секунд показывают раскладку из N тетромино на доске 9×9, затем
///   доска очищается и он должен воспроизвести её по памяти теми же фигурами.
///   Здесь — ТОЛЬКО чистая логика: [generateMemoryPuzzle] (раскладка + рука) и
///   [scoreMemory] (точность + тайм-бонус). Без UI/IO/таймеров.
///
/// Чистота и детерминизм (как у `lib/core/`):
///   единственный источник случайности — [makeRng] от целочисленного seed;
///   нет `DateTime.now()`, I/O, Flutter-импортов. Тот же `(difficulty, seed)` →
///   та же раскладка и рука (нужно для тестов и воспроизводимости результата).
///   Режим НЕ зеркалится в TS-ядре и НЕ участвует в golden-паритете 9×9 — он
///   лишь переиспользует примитивы доски/фигур из `lib/core/`.
///
/// Соответствие ROADMAP: § 5.2 (Memory Solo).
library;

import 'package:block_duel/core/core.dart';

/// Уровень сложности Memory Solo: число фигур + бюджеты времени (секунды).
///
/// ROADMAP § 5.2: 5 уровней (3 / 5 / 7 / 9 / 12 фигур). [showSeconds] — сколько
/// показывать раскладку, [reconstructSeconds] — сколько даётся на сборку.
enum MemoryDifficulty {
  /// 3 фигуры — знакомство.
  tutorial(pieceCount: 3, showSeconds: 3.0, reconstructSeconds: 40.0, label: 'Разминка'),

  /// 5 фигур.
  easy(pieceCount: 5, showSeconds: 3.5, reconstructSeconds: 50.0, label: 'Лёгкий'),

  /// 7 фигур.
  medium(pieceCount: 7, showSeconds: 4.0, reconstructSeconds: 60.0, label: 'Средний'),

  /// 9 фигур.
  hard(pieceCount: 9, showSeconds: 4.5, reconstructSeconds: 75.0, label: 'Сложный'),

  /// 12 фигур — эксперт.
  expert(pieceCount: 12, showSeconds: 5.0, reconstructSeconds: 90.0, label: 'Эксперт');

  /// Сколько тетромино в раскладке.
  final int pieceCount;

  /// Длительность фазы показа (секунды).
  final double showSeconds;

  /// Бюджет времени на сборку (секунды).
  final double reconstructSeconds;

  /// Человекочитаемая метка уровня.
  final String label;

  const MemoryDifficulty({
    required this.pieceCount,
    required this.showSeconds,
    required this.reconstructSeconds,
    required this.label,
  });
}

/// Сгенерированная задача: целевая доска + рука фигур для её воспроизведения.
class MemoryPuzzle {
  /// Целевая раскладка (заполненные клетки — то, что игрок должен повторить).
  final Board target;

  /// Рука фигур (тех же типов, что в раскладке, но в перемешанном порядке и в
  /// базовой ориентации — поворот/отражение игрок подбирает сам).
  final List<PieceInstance> hand;

  /// Сколько клеток заполнено в целевой раскладке (`4 * число фигур`).
  final int totalCells;

  /// Уровень сложности, по которому сгенерирована задача.
  final MemoryDifficulty difficulty;

  /// Seed генерации (для воспроизводимости/реплея).
  final int seed;

  /// Создаёт задачу.
  const MemoryPuzzle({
    required this.target,
    required this.hand,
    required this.totalCells,
    required this.difficulty,
    required this.seed,
  });
}

/// Результат оценки попытки воспроизведения.
class MemoryResult {
  /// Клетки, совпавшие с целевой раскладкой (заполнены и там, и там).
  final int correctCells;

  /// Клетки, ошибочно заполненные не на месте (есть у игрока, нет в цели).
  final int wrongCells;

  /// Всего клеток в целевой раскладке.
  final int totalCells;

  /// Точность как доля верно воспроизведённых клеток: `correct / total` (0..1).
  final double accuracy;

  /// Множитель за оставшееся время (`1 + 0.5 * timeRatio`).
  final double timeBonus;

  /// Идеальное воспроизведение (все клетки на месте, без лишних).
  final bool perfect;

  /// Итоговые очки.
  final int score;

  /// Создаёт результат.
  const MemoryResult({
    required this.correctCells,
    required this.wrongCells,
    required this.totalCells,
    required this.accuracy,
    required this.timeBonus,
    required this.perfect,
    required this.score,
  });
}

/// Максимум попыток разместить очередную фигуру при генерации (страховка от
/// зацикливания на почти заполненной доске; для N ≤ 12 запас огромный).
const int _maxPlacementAttempts = 4000;

/// Базовые очки за идеально воспроизведённую клетку (до тайм-бонуса).
const int _pointsPerCell = 25;

/// Фиксированная премия за идеальную сборку.
const int _perfectBonus = 200;

/// Перемешивание Фишера–Йетса на [rng] (без мутации источника). Та же формула
/// индекса, что в `bag.dart`, — детерминизм от seed.
List<T> _shuffle<T>(List<T> source, RandomSource rng) {
  final a = List<T>.from(source);
  for (int i = a.length - 1; i > 0; i--) {
    final j = (rng() * (i + 1)).floor();
    final tmp = a[i];
    a[i] = a[j];
    a[j] = tmp;
  }
  return a;
}

/// Генерирует задачу для [difficulty] от целочисленного [seed].
///
/// Алгоритм: на пустой доске детерминированно размещаем `pieceCount` тетромино
/// случайных типов/ориентаций/позиций так, чтобы они не пересекались и НЕ
/// образовывали ни одной полной линии/бокса (иначе раскладка «схлопнулась» бы
/// очисткой и стала бы неоднозначной). Затем собираем руку из использованных
/// типов в перемешанном порядке. Если за [_maxPlacementAttempts] не удалось
/// уложить все фигуры — возвращаем столько, сколько получилось (для N ≤ 12 это
/// практически недостижимо: 12 фигур = 48 клеток из 81).
MemoryPuzzle generateMemoryPuzzle(MemoryDifficulty difficulty, int seed) {
  final rng = makeRng(seed);
  final board = emptyBoard();
  final usedTypes = <PieceType>[];

  var attempts = 0;
  while (usedTypes.length < difficulty.pieceCount &&
      attempts < _maxPlacementAttempts) {
    attempts++;
    final type = allTypes[(rng() * allTypes.length).floor()];
    final os = orientations(type, true, true);
    final cells = os[(rng() * os.length).floor()];

    // Габариты ориентации, чтобы якорь не вышел за доску.
    var maxR = 0;
    var maxC = 0;
    for (final cell in cells) {
      if (cell.r > maxR) maxR = cell.r;
      if (cell.c > maxC) maxC = cell.c;
    }
    final r = (rng() * (boardSize - maxR)).floor();
    final c = (rng() * (boardSize - maxC)).floor();

    if (!canPlace(board, cells, r, c)) continue;

    // Пробная постановка: принимаем, только если не возникло очисток.
    place(board, cells, r, c, 0);
    if (findClears(board).count == 0) {
      usedTypes.add(type);
    } else {
      // Откат: освобождаем клетки.
      for (final cell in cells) {
        board[r + cell.r][c + cell.c] = Cell();
      }
    }
  }

  // Рука: перемешанные типы в базовой ориентации, со стабильными id.
  final shuffledTypes = _shuffle(usedTypes, rng);
  final hand = <PieceInstance>[
    for (int i = 0; i < shuffledTypes.length; i++)
      PieceInstance(
        id: 'm$i',
        type: shuffledTypes[i],
        cells: normalize(baseShapes[shuffledTypes[i]]!),
      ),
  ];

  return MemoryPuzzle(
    target: board,
    hand: hand,
    totalCells: usedTypes.length * 4,
    difficulty: difficulty,
    seed: seed,
  );
}

/// Оценивает воспроизведение: сравнивает [player] с [target] клетка-в-клетку.
///
/// [timeRatio] — доля оставшегося времени (0..1): даёт тайм-бонус только при
/// высокой точности (за брак время не вознаграждается сверх меры). Ошибочно
/// заполненные клетки штрафуют эффективную точность, но сам показатель
/// [MemoryResult.accuracy] остаётся «честным» `correct / total`.
MemoryResult scoreMemory(
  Board target,
  Board player, {
  required double timeRatio,
}) {
  var total = 0;
  var correct = 0;
  var wrong = 0;
  for (int r = 0; r < boardSize; r++) {
    for (int c = 0; c < boardSize; c++) {
      final t = target[r][c].filled;
      final p = player[r][c].filled;
      if (t) total++;
      if (t && p) correct++;
      if (p && !t) wrong++;
    }
  }

  final accuracy = total == 0 ? 0.0 : correct / total;
  final clampedTime = timeRatio.clamp(0.0, 1.0);
  final timeBonus = 1.0 + 0.5 * clampedTime;
  final perfect = total > 0 && correct == total && wrong == 0;

  // Эффективная доля со штрафом за лишние клетки (не ниже нуля).
  final effective = total == 0
      ? 0.0
      : ((correct - wrong) / total).clamp(0.0, 1.0);
  final base = (effective * total * _pointsPerCell * timeBonus).round();
  final score = base + (perfect ? _perfectBonus : 0);

  return MemoryResult(
    correctCells: correct,
    wrongCells: wrong,
    totalCells: total,
    accuracy: accuracy,
    timeBonus: timeBonus,
    perfect: perfect,
    score: score,
  );
}
