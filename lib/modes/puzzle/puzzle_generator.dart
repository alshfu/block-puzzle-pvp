/// puzzle_generator.dart — детерминированное замощение маски (Model, pure).
///
/// За что отвечает файл:
///   По маске-силуэту строит ЭТАЛОННОЕ решение — список постановок фигур,
///   точно покрывающих маску без наложений и без выхода за её пределы. Это даёт
///   и гарантию разрешимости уровня, и руку игрока (мультимножество фигур
///   решения). Алгоритм: жадно покрываем первую незакрытую клетку самой крупной
///   подходящей фигурой из пула (с детерминированным выбором среди равных по
///   размеру через засеянный RNG), а фигура «мини» 1×1 всегда подходит — поэтому
///   процесс гарантированно завершается точным покрытием. Сложность задаёт пул
///   доступных фигур. Чистый и детерминированный (seed выбирается в UI/паке).
///
/// Соответствие ROADMAP: § 9.1/§ 9.3 (генерация разрешимых уровней).
library;

import 'package:block_duel/core/core.dart';

import 'puzzle_core.dart';
import 'puzzle_pieces.dart';

/// Пул фигур (без `мини` — она всегда доступна как fallback) по сложности.
/// Чем «крупнее» пул, тем меньше и крупнее фигуры в руке.
List<String> poolForDifficulty(PuzzleDifficulty d) => switch (d) {
  PuzzleDifficulty.easy => [
    puzzlePentI,
    puzzlePentL,
    puzzlePentP,
    puzzlePentT,
    puzzlePlus,
    puzzleStep,
    'I',
    'O',
    'T',
    'L',
    'J',
  ],
  PuzzleDifficulty.medium => ['I', 'O', 'T', 'S', 'Z', 'J', 'L', puzzleStep],
  PuzzleDifficulty.hard => [
    'T',
    'S',
    'Z',
    'L',
    'J',
    puzzleTrominoL,
    puzzleTrominoI,
  ],
  PuzzleDifficulty.expert => [
    puzzleTrominoL,
    puzzleTrominoI,
    puzzleDomino,
  ],
};

/// Все валидные постановки, покрывающие клетку [target], из пула [pool] на маске
/// [mask] при занятых [filled]. Каждая — (shapeId, абсолютные клетки).
List<PuzzlePlacement> _placementsCovering(
  Coord target,
  List<String> pool,
  Set<Coord> mask,
  Set<Coord> filled,
) {
  final out = <PuzzlePlacement>[];
  for (final shapeId in pool) {
    for (final orient in puzzleOrientations(shapeId)) {
      // Пробуем «накрыть» target любой клеткой фигуры.
      for (final o in orient) {
        final ar = target.r - o.r;
        final ac = target.c - o.c;
        final abs = [for (final cell in orient) Coord(ar + cell.r, ac + cell.c)];
        var ok = true;
        for (final coord in abs) {
          if (!mask.contains(coord) || filled.contains(coord)) {
            ok = false;
            break;
          }
        }
        if (ok) out.add(PuzzlePlacement(shapeId: shapeId, cells: abs));
      }
    }
  }
  return out;
}

/// Строит эталонное решение для [mask] фигурами пула [difficulty], детерминируя
/// выбор по [seed]. Гарантирует точное покрытие маски (fallback — `мини` 1×1).
List<PuzzlePlacement> tilePuzzle(
  Set<Coord> mask,
  PuzzleDifficulty difficulty,
  int seed,
) {
  final rng = makeRng(seed);
  final pool = poolForDifficulty(difficulty);
  // Порядок сканирования — row-major (стабильный).
  final order = mask.toList()
    ..sort((a, b) => a.r != b.r ? a.r - b.r : a.c - b.c);
  final filled = <Coord>{};
  final result = <PuzzlePlacement>[];

  for (final target in order) {
    if (filled.contains(target)) continue;
    final candidates = _placementsCovering(target, pool, mask, filled);
    PuzzlePlacement chosen;
    if (candidates.isEmpty) {
      // Fallback: одиночная клетка «мини» — всегда помещается.
      chosen = PuzzlePlacement(shapeId: puzzleMini, cells: [target]);
    } else {
      // Берём самые крупные; среди равных — детерминированный случайный выбор.
      var maxSize = 0;
      for (final p in candidates) {
        if (p.cells.length > maxSize) maxSize = p.cells.length;
      }
      final best = [for (final p in candidates) if (p.cells.length == maxSize) p];
      chosen = best[(rng() * best.length).floor() % best.length];
    }
    filled.addAll(chosen.cells);
    result.add(chosen);
  }
  return result;
}
