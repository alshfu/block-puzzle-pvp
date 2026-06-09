/// pieces.dart — геометрия тетромино (порт фигур из `src/core/index.ts`).
///
/// За что отвечает файл:
///   Базовые формы семи фигур и операции над наборами клеток: [normalize]
///   (сдвиг к началу координат + канонический порядок), [rotate90], [flipH] и
///   перечисление всех уникальных ориентаций [orientations]. Всё чистое и
///   детерминированное — порядок ориентаций обязан совпадать с TS, иначе
///   `enumerateMoves` даст другую последовательность ходов.
///
/// Соответствие TS:
///   BASE_SHAPES / normalize / rotate90 / flipH / orientations → этот файл.
library;

import 'types.dart';

/// Базовые офсеты семи фигур (до нормализации). 1:1 с TS `BASE_SHAPES`.
const Map<PieceType, List<Coord>> baseShapes = {
  PieceType.i: [Coord(0, 0), Coord(0, 1), Coord(0, 2), Coord(0, 3)],
  PieceType.o: [Coord(0, 0), Coord(0, 1), Coord(1, 0), Coord(1, 1)],
  PieceType.t: [Coord(0, 0), Coord(0, 1), Coord(0, 2), Coord(1, 1)],
  PieceType.s: [Coord(0, 1), Coord(0, 2), Coord(1, 0), Coord(1, 1)],
  PieceType.z: [Coord(0, 0), Coord(0, 1), Coord(1, 1), Coord(1, 2)],
  PieceType.j: [Coord(0, 0), Coord(1, 0), Coord(1, 1), Coord(1, 2)],
  PieceType.l: [Coord(0, 2), Coord(1, 0), Coord(1, 1), Coord(1, 2)],
};

/// Приводит набор клеток к каноническому виду: сдвигает так, чтобы минимальные
/// строка и столбец были 0, и сортирует по (row, col). Порядок сортировки
/// совпадает с TS (`a[0]-b[0] || a[1]-b[1]`), что важно для стабильности ключей.
List<Coord> normalize(List<Coord> cells) {
  int minR = cells.first.r;
  int minC = cells.first.c;
  for (final cell in cells) {
    if (cell.r < minR) minR = cell.r;
    if (cell.c < minC) minC = cell.c;
  }
  final shifted = [
    for (final cell in cells) Coord(cell.r - minR, cell.c - minC),
  ]..sort();
  return shifted;
}

/// Поворот на 90°: `(r, c) -> (c, -r)`, затем нормализация. TS: `rotate90`.
List<Coord> rotate90(List<Coord> cells) =>
    normalize([for (final cell in cells) Coord(cell.c, -cell.r)]);

/// Горизонтальное отражение: `(r, c) -> (r, -c)`, затем нормализация.
/// TS: `flipH`.
List<Coord> flipH(List<Coord> cells) =>
    normalize([for (final cell in cells) Coord(cell.r, -cell.c)]);

/// Канонический строковый ключ нормализованного набора клеток
/// (`"r,c|r,c|..."`). Используется для дедупликации ориентаций. TS: `key`.
String _key(List<Coord> cells) =>
    cells.map((cell) => '${cell.r},${cell.c}').join('|');

/// Все уникальные ориентации фигуры [type] при заданных настройках поворота и
/// отражения. Порядок результата идентичен TS `orientations`: сначала базовая
/// (и её повороты), затем — отражённая (и её повороты), с пропуском дубликатов.
List<List<Coord>> orientations(
  PieceType type,
  bool rotationEnabled,
  bool flipEnabled,
) {
  final seen = <String>{};
  final result = <List<Coord>>[];

  final bases = <List<Coord>>[normalize(baseShapes[type]!)];
  if (flipEnabled) bases.add(flipH(baseShapes[type]!));

  for (final base in bases) {
    var cur = base;
    final rots = rotationEnabled ? 4 : 1;
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
