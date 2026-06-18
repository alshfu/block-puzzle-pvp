/// tetris_state.dart — неизменяемое состояние «Классического Tetris» (Model).
///
/// За что отвечает файл:
///   Снимок партии, которым управляет [TetrisNotifier]: поле 10×20, активная
///   падающая фигура (тип/поворот/позиция), очередь следующих фигур (превью),
///   ячейка «удержания» (hold) и флаг доступности hold, счёт/линии/уровень,
///   статус (идёт/пауза/конец) и сведения о последней очистке (для вспышки/
///   звука). Содержит чистые query-методы ([activeCells], [ghostRow]), чтобы
///   View оставался тонким. Без UI/IO/таймеров.
///
/// Соответствие ROADMAP: Фаза 5, режим «Tetris».
library;

import 'package:block_duel/core/core.dart';

import 'tetris_core.dart';

/// Статус партии Tetris.
enum TetrisStatus {
  /// Идёт игра (фигура падает).
  playing,

  /// Пауза (гравитация и ввод заморожены).
  paused,

  /// Конец (новая фигура не помещается при спавне).
  over,
}

/// Активная падающая фигура: тип, индекс поворота (0..3) и якорь `(r, c)`.
class ActivePiece {
  /// Тип тетромино.
  final PieceType type;

  /// Индекс состояния поворота (0..3).
  final int rot;

  /// Строка-якорь (верхняя-левая клетка нормализованной формы).
  final int r;

  /// Столбец-якорь.
  final int c;

  /// Создаёт активную фигуру.
  const ActivePiece({
    required this.type,
    required this.rot,
    required this.r,
    required this.c,
  });

  /// Копия с изменёнными полями.
  ActivePiece copyWith({PieceType? type, int? rot, int? r, int? c}) =>
      ActivePiece(
        type: type ?? this.type,
        rot: rot ?? this.rot,
        r: r ?? this.r,
        c: c ?? this.c,
      );
}

/// Неизменяемый снимок партии «Классический Tetris».
class TetrisState {
  /// Поле 10×20 (зафиксированная стопка; активная фигура хранится отдельно).
  final Board board;

  /// Падающая фигура (или `null`, если партия окончена).
  final ActivePiece? piece;

  /// Очередь следующих фигур (для превью «дальше»; голова — ближайшая).
  final List<PieceType> queue;

  /// Удержанная фигура (hold) или `null`.
  final PieceType? hold;

  /// Можно ли сейчас положить фигуру в hold (раз за «жизнь» фигуры).
  final bool canHold;

  /// Текущий счёт.
  final int score;

  /// Суммарно очищено линий.
  final int lines;

  /// Текущий уровень (производное от [lines], но кэшируется для UI).
  final int level;

  /// Статус партии.
  final TetrisStatus status;

  /// Строки, очищённые последним lock'ом (для вспышки/звука).
  final List<int> lastClearedRows;

  /// Сколько строк очищено последним lock'ом.
  final int lastClearCount;

  /// Счётчик «событий» (lock/очистка) — для привязки звука/эффектов во View.
  final int moveSeq;

  /// Создаёт снимок.
  const TetrisState({
    required this.board,
    required this.piece,
    required this.queue,
    required this.hold,
    required this.canHold,
    required this.score,
    required this.lines,
    required this.level,
    required this.status,
    this.lastClearedRows = const [],
    this.lastClearCount = 0,
    this.moveSeq = 0,
  });

  /// Окончена ли партия.
  bool get gameOver => status == TetrisStatus.over;

  /// На паузе ли.
  bool get isPaused => status == TetrisStatus.paused;

  /// Абсолютные клетки активной фигуры (или пусто, если фигуры нет).
  List<Coord> get activeCells {
    final p = piece;
    if (p == null) return const [];
    return [
      for (final cell in tetrisCells(p.type, p.rot))
        Coord(p.r + cell.r, p.c + cell.c),
    ];
  }

  /// Строка-якорь «призрака» — куда фигура упадёт при hard drop (или `null`).
  int? get ghostRow {
    final p = piece;
    if (p == null) return null;
    return p.r + tetrisDropDistance(board, p.type, p.rot, p.r, p.c);
  }

  /// Абсолютные клетки «призрака» приземления (или пусто).
  List<Coord> get ghostCells {
    final p = piece;
    final gr = ghostRow;
    if (p == null || gr == null) return const [];
    return [
      for (final cell in tetrisCells(p.type, p.rot))
        Coord(gr + cell.r, p.c + cell.c),
    ];
  }

  /// Копия с изменёнными полями.
  TetrisState copyWith({
    Board? board,
    ActivePiece? piece,
    bool clearPiece = false,
    List<PieceType>? queue,
    PieceType? hold,
    bool clearHold = false,
    bool? canHold,
    int? score,
    int? lines,
    int? level,
    TetrisStatus? status,
    List<int>? lastClearedRows,
    int? lastClearCount,
    int? moveSeq,
  }) => TetrisState(
    board: board ?? this.board,
    piece: clearPiece ? null : (piece ?? this.piece),
    queue: queue ?? this.queue,
    hold: clearHold ? null : (hold ?? this.hold),
    canHold: canHold ?? this.canHold,
    score: score ?? this.score,
    lines: lines ?? this.lines,
    level: level ?? this.level,
    status: status ?? this.status,
    lastClearedRows: lastClearedRows ?? this.lastClearedRows,
    lastClearCount: lastClearCount ?? this.lastClearCount,
    moveSeq: moveSeq ?? this.moveSeq,
  );
}
