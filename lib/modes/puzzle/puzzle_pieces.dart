/// puzzle_pieces.dart — нестандартный набор фигур режима «Силуэты» (Model, pure).
///
/// За что отвечает файл:
///   Расширенный набор полимино для режима Puzzle Silhouettes (ROADMAP § 9.2):
///   кроме семи классических тетромино — мини (1×1), домино, тримино (I/L),
///   плюс-пентамино, несколько пентамино (I/L/P/T) и «диагональная лесенка»
///   (W-пентамино). Каждая фигура — нормализованный набор клеток [Coord].
///   Здесь же — обобщённые ориентации [shapeOrientations] (повороты/отражения
///   ЛЮБОЙ формы, не только `PieceType`), переиспользующие `rotate90`/`flipH`/
///   `normalize` из ядра. Всё чистое и детерминированное; режим не зеркалится в
///   TS и не входит в golden-паритет 9×9.
///
/// Соответствие ROADMAP: § 9.2 (не-стандартный piece-set).
library;

import 'package:block_duel/core/core.dart';

/// Идентификаторы фигур пазла (стабильные ключи для пака/JSON/руки).
/// Семь классических тетромино берут код `PieceType` (`'I'`…`'L'`), остальные —
/// собственные имена.
const String puzzleMini = 'MINI';
const String puzzleDomino = 'DOMINO';
const String puzzleTrominoI = 'TROMINO_I';
const String puzzleTrominoL = 'TROMINO_L';
const String puzzlePlus = 'PLUS';
const String puzzlePentI = 'PENT_I';
const String puzzlePentL = 'PENT_L';
const String puzzlePentP = 'PENT_P';
const String puzzlePentT = 'PENT_T';
const String puzzleStep = 'STEP'; // W-пентамино — «диагональная лесенка»

/// Базовые (нормализованные) формы всех фигур пазла по их id. Классические
/// тетромино включены под буквенными кодами `PieceType` для единообразия.
final Map<String, List<Coord>> puzzleBaseShapes = {
  // Классические тетромино (переиспользуем формы ядра).
  for (final t in allTypes) pieceTypeCode(t): normalize(baseShapes[t]!),
  // Мелкие полимино.
  puzzleMini: const [Coord(0, 0)],
  puzzleDomino: const [Coord(0, 0), Coord(0, 1)],
  puzzleTrominoI: const [Coord(0, 0), Coord(0, 1), Coord(0, 2)],
  puzzleTrominoL: const [Coord(0, 0), Coord(1, 0), Coord(1, 1)],
  // Пентамино.
  puzzlePlus: const [
    Coord(0, 1),
    Coord(1, 0),
    Coord(1, 1),
    Coord(1, 2),
    Coord(2, 1),
  ],
  puzzlePentI: const [
    Coord(0, 0),
    Coord(0, 1),
    Coord(0, 2),
    Coord(0, 3),
    Coord(0, 4),
  ],
  puzzlePentL: const [
    Coord(0, 0),
    Coord(1, 0),
    Coord(2, 0),
    Coord(3, 0),
    Coord(3, 1),
  ],
  puzzlePentP: const [
    Coord(0, 0),
    Coord(0, 1),
    Coord(1, 0),
    Coord(1, 1),
    Coord(2, 0),
  ],
  puzzlePentT: const [
    Coord(0, 0),
    Coord(0, 1),
    Coord(0, 2),
    Coord(1, 1),
    Coord(2, 1),
  ],
  // W-пентамино — «диагональная лесенка».
  puzzleStep: const [
    Coord(0, 0),
    Coord(1, 0),
    Coord(1, 1),
    Coord(2, 1),
    Coord(2, 2),
  ],
};

/// Число клеток фигуры [shapeId] (размер полимино).
int puzzleShapeSize(String shapeId) => puzzleBaseShapes[shapeId]!.length;

/// Канонический строковый ключ нормализованного набора (для дедупликации
/// ориентаций) — тот же формат, что в ядре.
String _key(List<Coord> cells) =>
    cells.map((c) => '${c.r},${c.c}').join('|');

/// Все уникальные ориентации произвольной формы [cells] при заданных
/// разрешениях [rotation]/[flip]. Алгоритм идентичен `orientations` ядра, но
/// работает с любыми клетками (не только `PieceType`). Порядок: базовая и её
/// повороты, затем отражённая и её повороты, с пропуском дубликатов.
List<List<Coord>> shapeOrientations(
  List<Coord> cells, {
  bool rotation = true,
  bool flip = true,
}) {
  final seen = <String>{};
  final result = <List<Coord>>[];
  final bases = <List<Coord>>[normalize(cells)];
  if (flip) bases.add(flipH(cells));
  for (final base in bases) {
    var cur = base;
    final rots = rotation ? 4 : 1;
    for (int i = 0; i < rots; i++) {
      final k = _key(cur);
      if (!seen.contains(k)) {
        seen.add(k);
        result.add(cur);
      }
      cur = rotate90(cur);
    }
  }
  return result;
}

/// Ориентации фигуры пазла по её [shapeId].
List<List<Coord>> puzzleOrientations(
  String shapeId, {
  bool rotation = true,
  bool flip = true,
}) => shapeOrientations(
  puzzleBaseShapes[shapeId]!,
  rotation: rotation,
  flip: flip,
);
