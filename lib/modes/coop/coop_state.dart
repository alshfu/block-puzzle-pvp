/// coop_state.dart — неизменяемое состояние матча «Co-op Tetris» (Model-слой).
///
/// За что отвечает файл:
///   Снимок партии на поле 10×20, которым управляет [CoopNotifier]: поле, два
///   игрока (счёт/рука), чей ход, выбранная фигура и ориентация, флаги конца
///   игры и сведения о последней очистке. Содержит чистые query-методы
///   ([activeCells], [canPlaceAt], [previewCells]), чтобы View оставался тонким.
///
/// Соответствие ROADMAP: § 5.4 (Co-op Tetris).
library;

import 'package:block_duel/core/core.dart';

import 'coop_core.dart';

/// Состояние одного игрока Co-op: счёт, рука, имя.
class CoopPlayer {
  /// Накопленный счёт.
  final int score;

  /// Фигуры в руке.
  final List<PieceInstance> hand;

  /// Отображаемое имя.
  final String name;

  /// Создаёт состояние игрока.
  const CoopPlayer({required this.score, required this.hand, required this.name});

  /// Копия с изменёнными полями.
  CoopPlayer copyWith({int? score, List<PieceInstance>? hand, String? name}) =>
      CoopPlayer(
        score: score ?? this.score,
        hand: hand ?? this.hand,
        name: name ?? this.name,
      );
}

/// Неизменяемый снимок матча Co-op Tetris.
class CoopState {
  /// Текущее поле 10×20.
  final Board board;

  /// Состояния обоих игроков (0 и 1).
  final List<CoopPlayer> players;

  /// Чей сейчас ход (0/1).
  final int current;

  /// Номер раунда (пара ходов).
  final int round;

  /// Окончена ли партия (тупик у того, чей ход).
  final bool gameOver;

  /// Победитель (0/1) или `null` при ничьей/незавершённой партии.
  final int? winner;

  /// Id выбранной фигуры (или `null`).
  final String? selectedPieceId;

  /// Индекс текущей ориентации выбранной фигуры.
  final int orientIndex;

  /// Правила (повороты/отражения).
  final RuleConfig cfg;

  /// Строки, очищенные последним ходом (для подсветки/звука).
  final List<int> lastClearedRows;

  /// Очки, начисленные последним ходом.
  final int lastGain;

  /// Счётчик ходов (растёт на каждую постановку) — для звука/анимаций.
  final int moveSeq;

  /// Создаёт снимок.
  const CoopState({
    required this.board,
    required this.players,
    required this.current,
    required this.round,
    required this.gameOver,
    required this.winner,
    required this.selectedPieceId,
    required this.orientIndex,
    required this.cfg,
    this.lastClearedRows = const [],
    this.lastGain = 0,
    this.moveSeq = 0,
  });

  /// Текущий игрок.
  CoopPlayer get currentPlayer => players[current];

  /// Выбранная фигура (из руки текущего игрока) или `null`.
  PieceInstance? get selectedPiece {
    final id = selectedPieceId;
    if (id == null) return null;
    for (final p in currentPlayer.hand) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Клетки выбранной фигуры в текущей ориентации (нормализованные) либо `null`.
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
    return coopCanPlace(board, cells, r, c);
  }

  /// Абсолютные клетки превью выбранной фигуры при якоре `(r, c)`.
  List<Coord> previewCells(int r, int c) {
    final cells = activeCells;
    if (cells == null) return const [];
    return [for (final cell in cells) Coord(r + cell.r, c + cell.c)];
  }

  /// Копия с изменёнными полями.
  CoopState copyWith({
    Board? board,
    List<CoopPlayer>? players,
    int? current,
    int? round,
    bool? gameOver,
    int? winner,
    bool clearWinner = false,
    String? selectedPieceId,
    bool clearSelection = false,
    int? orientIndex,
    List<int>? lastClearedRows,
    int? lastGain,
    int? moveSeq,
  }) => CoopState(
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
    cfg: cfg,
    lastClearedRows: lastClearedRows ?? this.lastClearedRows,
    lastGain: lastGain ?? this.lastGain,
    moveSeq: moveSeq ?? this.moveSeq,
  );
}
