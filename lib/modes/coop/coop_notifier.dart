/// coop_notifier.dart — ViewModel матча «Co-op Tetris» (MVVM, слой ViewModel).
///
/// За что отвечает файл:
///   Управляет ходом hot-seat-партии на поле 10×20 поверх pure-ядра
///   (`coop_core.dart`): держит мешки фигур обоих игроков, выставляет команды
///   View (выбор/поворот/постановка, новая игра), применяет очистку полных
///   строк с начислением очков тому, чей ход, переключает игроков и завершает
///   партию при тупике. Без `BuildContext`/виджетов/таймеров — два игрока ходят
///   по очереди на одном устройстве (ELO-ladder — онлайн-надстройка, отдельно).
///
/// Соответствие ROADMAP: § 5.4 (Co-op Tetris, turn-based 10×20).
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'coop_core.dart';
import 'coop_state.dart';

/// Размер руки каждого игрока (ROADMAP § 5.4: «Hand с 3 фигурами»).
const int coopHandSize = 3;

/// Правила Co-op: повороты/отражения разрешены, blitz выключен.
final RuleConfig _coopCfg = defaultConfig.copyWith(turnTimerEnabled: false);

/// Смещение seed для мешка второго игрока (свой мешок у каждого).
const int _player1SeedSalt = 0x9e3779b9;

/// ViewModel матча Co-op Tetris.
class CoopNotifier extends Notifier<CoopState> {
  /// Мешки фигур обоих игроков (свой у каждого).
  late List<Bag> _bags;

  @override
  CoopState build() => _freshState(_defaultSeed());

  /// Сид по умолчанию для первого построения (UI обычно вызывает [newGame]).
  int _defaultSeed() => 0x1234abcd;

  // ── Команды View ───────────────────────────────────────────────────────────

  /// Начинает новую партию с заданным [seed].
  void newGame(int seed) {
    state = _freshState(seed);
  }

  /// Выбирает фигуру из руки текущего игрока (сбрасывает ориентацию).
  void selectPiece(String pieceId) {
    if (state.gameOver) return;
    state = state.copyWith(selectedPieceId: pieceId, orientIndex: 0);
  }

  /// Поворачивает выбранную фигуру (следующая ориентация).
  void rotate() {
    if (state.gameOver || state.selectedPiece == null) return;
    state = state.copyWith(orientIndex: state.orientIndex + 1);
  }

  /// Снимает выбор фигуры.
  void deselect() {
    if (state.selectedPieceId == null) return;
    state = state.copyWith(clearSelection: true);
  }

  /// Ставит выбранную фигуру с якорем `(r, c)`: применяет очистку строк,
  /// начисляет очки, пополняет руку, переключает ход и проверяет тупик.
  void placeAt(int r, int c) {
    if (state.gameOver) return;
    final cells = state.activeCells;
    final piece = state.selectedPiece;
    if (cells == null || piece == null) return;
    if (!coopCanPlace(state.board, cells, r, c)) return;

    final cur = state.current;
    final board = cloneCoopBoard(state.board);
    coopPlace(board, cells, r, c, cur);

    // Очистка полных строк → очки тому, чей ход.
    final fullRows = coopFullRows(board);
    final gain = coopScoreForClear(fullRows.length);
    if (fullRows.isNotEmpty) coopClearRows(board, fullRows);

    // Пополнение руки: убираем поставленную, добираем одну (анти-дубль в руке).
    final restHand = [
      for (final p in state.currentPlayer.hand) if (p.id != piece.id) p,
    ];
    final avoid = restHand.map((p) => p.type).toSet();
    final newHand = [...restHand, _bags[cur].drawAvoiding(avoid)];

    final players = [
      for (int i = 0; i < state.players.length; i++)
        i == cur
            ? state.players[i].copyWith(
                score: state.players[i].score + gain,
                hand: newHand,
              )
            : state.players[i],
    ];

    final next = 1 - cur;
    final nextRound = cur == 1 ? state.round + 1 : state.round;

    // Тупик: следующий игрок не может сходить ни одной фигурой → конец партии.
    final nextStuck = !coopHasAnyMove(
      board,
      players[next].hand,
      rotationEnabled: state.cfg.rotationEnabled,
      flipEnabled: state.cfg.flipEnabled,
    );

    state = CoopState(
      board: board,
      players: players,
      current: nextStuck ? cur : next,
      round: nextRound,
      gameOver: nextStuck,
      winner: nextStuck ? _winnerOf(players) : null,
      selectedPieceId: null,
      orientIndex: 0,
      cfg: state.cfg,
      lastClearedRows: fullRows,
      lastGain: gain,
      moveSeq: state.moveSeq + 1,
    );
  }

  // ── Внутреннее ──────────────────────────────────────────────────────────────

  /// Победитель по очкам (или `null` при равенстве).
  int? _winnerOf(List<CoopPlayer> players) {
    if (players[0].score > players[1].score) return 0;
    if (players[1].score > players[0].score) return 1;
    return null;
  }

  /// Свежая партия: новые мешки и розданные руки.
  CoopState _freshState(int seed) {
    _bags = [Bag(seed), Bag(seed ^ _player1SeedSalt)];
    final players = [
      CoopPlayer(score: 0, hand: _dealHand(_bags[0]), name: 'Игрок 1'),
      CoopPlayer(score: 0, hand: _dealHand(_bags[1]), name: 'Игрок 2'),
    ];
    return CoopState(
      board: emptyCoopBoard(),
      players: players,
      current: 0,
      round: 0,
      gameOver: false,
      winner: null,
      selectedPieceId: null,
      orientIndex: 0,
      cfg: _coopCfg,
    );
  }

  /// Раздаёт руку из [coopHandSize] фигур с анти-дублированием типов в руке.
  List<PieceInstance> _dealHand(Bag bag) {
    final hand = <PieceInstance>[];
    for (int i = 0; i < coopHandSize; i++) {
      hand.add(bag.drawAvoiding(hand.map((p) => p.type).toSet()));
    }
    return hand;
  }
}

/// Провайдер ViewModel матча Co-op Tetris.
final coopProvider = NotifierProvider<CoopNotifier, CoopState>(
  CoopNotifier.new,
);
