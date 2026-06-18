/// mirror_pieces.dart — бонусный «зеркальный набор» фигур (Model, pure).
///
/// За что отвечает файл:
///   Реализация бонус-контента ROADMAP § 8.5 — отражённые версии классических
///   тетромино, разблокируемые на 100-м уровне ([mirrorPiecesUnlock]) и
///   включаемые опционально в настройках. Геометрически горизонтальное
///   отражение тетромино отображает типы: S↔Z и J↔L, а I/O/T самосимметричны —
///   поэтому «зеркальный набор» — это детерминированное переотображение типов
///   [mirrorOf]. [mirrorShape] даёт отражённые клетки для превью/тестов.
///
/// Почему не трогаем ядро 9×9:
///   `lib/core/` обязано оставаться bit-for-bit с TS (golden-паритет). Поэтому
///   зеркальный набор живёт отдельным pure-модулем и применяется в режимах
///   платформы (например, «Tetris»), а не подменяет `baseShapes` ядра.
///
/// Соответствие ROADMAP: § 8.5 (бонусный piece-set, 100-й уровень).
library;

import 'package:block_duel/core/core.dart';

import 'level_rewards.dart' show mirrorPiecesUnlock;

export 'level_rewards.dart' show mirrorPiecesUnlock;

/// Зеркальное (горизонтальное отражение) отображение типа фигуры:
/// S↔Z, J↔L; I/O/T отражаются сами в себя.
PieceType mirrorOf(PieceType type) => switch (type) {
  PieceType.s => PieceType.z,
  PieceType.z => PieceType.s,
  PieceType.j => PieceType.l,
  PieceType.l => PieceType.j,
  PieceType.i || PieceType.o || PieceType.t => type,
};

/// Отражённые клетки фигуры [type] (горизонтальное зеркало базовой формы,
/// нормализованные). Для превью набора и тестов; геометрически совпадает с
/// базовой формой [mirrorOf]`(type)`.
List<Coord> mirrorShape(PieceType type) => flipH(baseShapes[type]!);

/// Самосимметрична ли фигура относительно горизонтального отражения
/// (`mirrorOf(type) == type`): верно для I/O/T.
bool isSelfMirror(PieceType type) => mirrorOf(type) == type;
