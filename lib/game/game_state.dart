/// game_state.dart — неизменяемое состояние партии (Model-слой игры).
///
/// За что отвечает файл:
///   Снимок партии, которым управляет ViewModel ([GameNotifier]): доска, два
///   игрока (счёт/комбо/рука), чей ход, выбранная фигура и её ориентация, флаги
///   конца игры. Содержит чистые query-методы ([activeCells], [canPlaceAt],
///   [previewCells]) — чтобы View оставался «тонким» и не считал логику сам.
///
/// Соответствие TS: агрегированное состояние из `useGame.ts`.
library;

import 'package:block_duel/core/core.dart';

/// Состояние одного игрока: счёт, текущее комбо, рука и отображаемое имя.
class PlayerState {
  /// Накопленный счёт.
  final int score;

  /// Текущее комбо-комбо (число подряд идущих очисток).
  final int combo;

  /// Фигуры в руке.
  final List<PieceInstance> hand;

  /// Отображаемое имя игрока.
  final String name;

  /// Создаёт состояние игрока.
  const PlayerState({
    required this.score,
    required this.combo,
    required this.hand,
    required this.name,
  });

  /// Копия с изменёнными полями.
  PlayerState copyWith({
    int? score,
    int? combo,
    List<PieceInstance>? hand,
    String? name,
  }) => PlayerState(
    score: score ?? this.score,
    combo: combo ?? this.combo,
    hand: hand ?? this.hand,
    name: name ?? this.name,
  );
}

/// Неизменяемый снимок партии.
class GameState {
  /// Текущая доска (снимок; ViewModel отдаёт копию на каждом изменении).
  final Board board;

  /// Состояния обоих игроков (индексы 0 и 1).
  final List<PlayerState> players;

  /// Чей сейчас ход (0/1).
  final int current;

  /// Номер раунда (пара ходов обоих игроков).
  final int round;

  /// Окончена ли партия (тупик).
  final bool gameOver;

  /// Победитель (0/1) или `null` при ничьей/незавершённой партии.
  final int? winner;

  /// Id выбранной фигуры в руке текущего игрока (или `null`).
  final String? selectedPieceId;

  /// Индекс текущей ориентации выбранной фигуры (в списке [orientations]).
  final int orientIndex;

  /// Лимит времени на текущий ход (секунды; `infinity` если blitz выключен).
  final double turnLimit;

  /// Остаток времени на текущий ход (секунды).
  final double turnRemaining;

  /// Правила партии.
  final RuleConfig cfg;

  /// Счётчик сделанных постановок (растёт на каждый ход). View использует его,
  /// чтобы отличить новый ход от прочих обновлений (тик таймера) и сыграть звук.
  final int moveSeq;

  /// Сколько линий очистил последний ход (0 — без очистки).
  final int lastClearCount;

  /// Был ли последний ход perfect clear.
  final bool lastPerfect;

  /// Разбивка очков ПОСЛЕДНЕГО хода (для накопления и экрана результата):
  /// база + placement.
  final int lastBaseGain;

  /// Бонус-часть очков последнего хода (комбо + multi-clear + speed —
  /// total − base − placement − perfect).
  final int lastBonusGain;

  /// Бонус за perfect clear в последнем ходе.
  final int lastPerfectGain;

  /// Стоит ли партия на паузе (таймеры остановлены, показан оверлей).
  final bool paused;

  /// Следующая фигура каждого игрока (превью «дальше», индексы 0/1). Пусто —
  /// нет данных (например, в онлайне сервер очередь мешка не присылает).
  final List<PieceType> nextPieces;

  /// Подсветка лучшего хода (power-up «Подсказка»): абсолютные клетки цели либо
  /// пусто. Снимается по таймеру или следующим действием игрока.
  final List<Coord> hintCells;

  /// Создаёт снимок партии.
  const GameState({
    required this.board,
    required this.players,
    required this.current,
    required this.round,
    required this.gameOver,
    required this.winner,
    required this.selectedPieceId,
    required this.orientIndex,
    required this.turnLimit,
    required this.turnRemaining,
    required this.cfg,
    this.moveSeq = 0,
    this.lastClearCount = 0,
    this.lastPerfect = false,
    this.lastBaseGain = 0,
    this.lastBonusGain = 0,
    this.lastPerfectGain = 0,
    this.paused = false,
    this.nextPieces = const [],
    this.hintCells = const [],
  });

  /// Текущий игрок.
  PlayerState get currentPlayer => players[current];

  /// Выбранная фигура (из руки текущего игрока) или `null`.
  PieceInstance? get selectedPiece {
    final id = selectedPieceId;
    if (id == null) return null;
    for (final p in currentPlayer.hand) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Клетки выбранной фигуры в текущей ориентации (нормализованные), либо
  /// `null`, если ничего не выбрано.
  List<Coord>? get activeCells {
    final piece = selectedPiece;
    if (piece == null) return null;
    final os = orientations(piece.type, cfg.rotationEnabled, cfg.flipEnabled);
    return os[orientIndex % os.length];
  }

  /// Можно ли поставить выбранную фигуру с якорем в `(r, c)`.
  bool canPlaceAt(int r, int c) {
    final cells = activeCells;
    if (cells == null) return false;
    return canPlace(board, cells, r, c);
  }

  /// Абсолютные клетки превью выбранной фигуры при якоре `(r, c)`, либо пустой
  /// список, если фигура не выбрана. Используется для отрисовки «призрака».
  List<Coord> previewCells(int r, int c) {
    final cells = activeCells;
    if (cells == null) return const [];
    return [for (final cell in cells) Coord(r + cell.r, c + cell.c)];
  }

  /// Копия с изменёнными полями (board заменяется ссылкой, остальное — точечно).
  GameState copyWith({
    Board? board,
    List<PlayerState>? players,
    int? current,
    int? round,
    bool? gameOver,
    int? winner,
    bool clearWinner = false,
    String? selectedPieceId,
    bool clearSelection = false,
    int? orientIndex,
    double? turnLimit,
    double? turnRemaining,
    int? moveSeq,
    int? lastClearCount,
    bool? lastPerfect,
    int? lastBaseGain,
    int? lastBonusGain,
    int? lastPerfectGain,
    bool? paused,
    List<PieceType>? nextPieces,
    List<Coord>? hintCells,
    bool clearHint = false,
  }) => GameState(
    board: board ?? this.board,
    players: players ?? this.players,
    current: current ?? this.current,
    round: round ?? this.round,
    gameOver: gameOver ?? this.gameOver,
    winner: clearWinner ? null : (winner ?? this.winner),
    selectedPieceId: clearSelection
        ? null
        : (selectedPieceId ?? this.selectedPieceId),
    orientIndex: orientIndex ?? this.orientIndex,
    turnLimit: turnLimit ?? this.turnLimit,
    turnRemaining: turnRemaining ?? this.turnRemaining,
    cfg: cfg,
    moveSeq: moveSeq ?? this.moveSeq,
    lastClearCount: lastClearCount ?? this.lastClearCount,
    lastPerfect: lastPerfect ?? this.lastPerfect,
    lastBaseGain: lastBaseGain ?? this.lastBaseGain,
    lastBonusGain: lastBonusGain ?? this.lastBonusGain,
    lastPerfectGain: lastPerfectGain ?? this.lastPerfectGain,
    paused: paused ?? this.paused,
    nextPieces: nextPieces ?? this.nextPieces,
    hintCells: clearHint ? const [] : (hintCells ?? this.hintCells),
  );
}
