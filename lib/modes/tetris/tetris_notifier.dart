/// tetris_notifier.dart — ViewModel «Классического Tetris» (MVVM, ViewModel).
///
/// За что отвечает файл:
///   Управляет живой партией поверх pure-ядра (`tetris_core.dart`): держит
///   засеянный мешок фигур, спавнит падающую фигуру, обрабатывает команды View
///   (влево/вправо, soft/hard drop, повороты CW/CCW, hold, пауза, новая игра) и
///   ведёт гравитацию через [tick] (темп задаёт Ticker во View — ядро остаётся
///   без таймеров). При lock'е применяет схлопывающую очистку строк, начисляет
///   классический счёт, поднимает уровень и завершает партию, если новая фигура
///   не помещается. Без `BuildContext`/виджетов.
///
/// Опция «зеркальный набор» (ROADMAP § 8.5): при [mirror] фигуры берутся в
/// отражённом отображении типов (S↔Z, J↔L; I/O/T самосимметричны) — это
/// меняет ощущение набора, не трогая parity-связанное ядро 9×9.
///
/// Соответствие ROADMAP: Фаза 5, режим «Tetris»; § 8.5 (зеркальный набор).
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/mirror_pieces.dart';
import 'tetris_core.dart';
import 'tetris_state.dart';

/// Длина превью очереди следующих фигур.
const int tetrisQueuePreview = 5;

/// ViewModel живой партии Tetris.
class TetrisNotifier extends Notifier<TetrisState> {
  /// Засеянный мешок фигур (7-bag).
  late Bag _bag;

  /// Включён ли зеркальный набор фигур (§ 8.5).
  bool _mirror = false;

  /// Накопитель времени для гравитации (секунды).
  double _accum = 0;

  @override
  TetrisState build() => _freshState(0x7e7415, mirror: false);

  // ── Команды View ───────────────────────────────────────────────────────────

  /// Начинает новую партию с заданным [seed]; [mirror] — зеркальный набор.
  void newGame(int seed, {bool mirror = false}) {
    state = _freshState(seed, mirror: mirror);
  }

  /// Пауза/снятие паузы (во время партии).
  void togglePause() {
    if (state.gameOver) return;
    state = state.copyWith(
      status: state.isPaused ? TetrisStatus.playing : TetrisStatus.paused,
    );
  }

  /// Сдвиг активной фигуры на [dc] столбцов (−1 влево, +1 вправо).
  void move(int dc) {
    final p = _activeOrNull();
    if (p == null) return;
    if (tetrisCanPlace(state.board, p.type, p.rot, p.r, p.c + dc)) {
      state = state.copyWith(piece: p.copyWith(c: p.c + dc));
    }
  }

  /// Soft drop: шаг вниз вручную (+1 очко), сброс таймера гравитации. Если вниз
  /// нельзя — фиксирует фигуру.
  void softDrop() {
    final p = _activeOrNull();
    if (p == null) return;
    _accum = 0;
    if (tetrisCanPlace(state.board, p.type, p.rot, p.r + 1, p.c)) {
      state = state.copyWith(
        piece: p.copyWith(r: p.r + 1),
        score: state.score + 1,
      );
    } else {
      _lockAndSpawn(p);
    }
  }

  /// Hard drop: мгновенно роняет фигуру до упора (+2 очка за ряд) и фиксирует.
  void hardDrop() {
    final p = _activeOrNull();
    if (p == null) return;
    final dist = tetrisDropDistance(state.board, p.type, p.rot, p.r, p.c);
    final landed = p.copyWith(r: p.r + dist);
    _lockAndSpawn(landed, dropBonus: dist * 2);
  }

  /// Поворот: [dir] = +1 по часовой, −1 против. Применяет wall-kick.
  void rotate(int dir) {
    final p = _activeOrNull();
    if (p == null) return;
    final res = tetrisTryRotate(state.board, p.type, p.rot, p.r, p.c, dir);
    if (res != null) {
      state = state.copyWith(
        piece: p.copyWith(rot: res.rot, r: res.r, c: res.c),
      );
    }
  }

  /// Hold: убирает текущую фигуру в «удержание» и достаёт следующую/удержанную
  /// (один раз за «жизнь» фигуры).
  void hold() {
    final p = _activeOrNull();
    if (p == null || !state.canHold) return;
    _accum = 0;
    final held = state.hold;
    if (held == null) {
      // Кладём текущую, спавним следующую из очереди.
      final spawned = _spawnFromQueue();
      state = state.copyWith(
        hold: p.type,
        piece: spawned,
        canHold: false,
        status: spawned == null ? TetrisStatus.over : TetrisStatus.playing,
        clearPiece: spawned == null,
      );
    } else {
      // Меняем местами с удержанной (тип held спавним заново сверху).
      final spawned = _spawnPiece(held);
      state = state.copyWith(
        hold: p.type,
        piece: spawned,
        canHold: false,
        status: spawned == null ? TetrisStatus.over : TetrisStatus.playing,
        clearPiece: spawned == null,
      );
    }
  }

  /// Шаг времени [dt] (секунды) от Ticker'а View: копит время и опускает фигуру
  /// гравитацией, когда накоплен интервал уровня. На паузе/конце — no-op.
  void tick(double dt) {
    if (state.status != TetrisStatus.playing) return;
    _accum += dt;
    final interval = tetrisGravitySeconds(state.level);
    // Ограничиваем число шагов за один тик (защита от «провала» при лагах).
    var steps = 0;
    while (_accum >= interval && state.status == TetrisStatus.playing && steps < 4) {
      _accum -= interval;
      steps++;
      _gravityStep();
    }
  }

  // ── Внутреннее ──────────────────────────────────────────────────────────────

  /// Активная фигура, если партия идёт и не на паузе (иначе `null`).
  ActivePiece? _activeOrNull() =>
      state.status == TetrisStatus.playing ? state.piece : null;

  /// Один шаг гравитации: вниз, либо фиксация при упоре.
  void _gravityStep() {
    final p = state.piece;
    if (p == null) return;
    if (tetrisCanPlace(state.board, p.type, p.rot, p.r + 1, p.c)) {
      state = state.copyWith(piece: p.copyWith(r: p.r + 1));
    } else {
      _lockAndSpawn(p);
    }
  }

  /// Фиксирует фигуру [p] на поле, очищает полные строки (со схлопыванием),
  /// начисляет счёт (+[dropBonus] за hard drop), поднимает уровень и спавнит
  /// следующую. Если новая фигура не помещается — конец партии.
  void _lockAndSpawn(ActivePiece p, {int dropBonus = 0}) {
    final board = cloneTetrisBoard(state.board);
    tetrisLock(board, p.type, p.rot, p.r, p.c);
    final fullRows = tetrisFullRows(board);
    final cleared = tetrisClearRows(board);
    final totalLines = state.lines + cleared.cleared;
    final level = tetrisLevelForLines(totalLines);
    final gained = tetrisLineScore(cleared.cleared, state.level) + dropBonus;

    final spawned = _spawnPiece(state.queue.first, advanceQueue: true);
    _accum = 0;
    state = state.copyWith(
      board: cleared.board,
      piece: spawned,
      clearPiece: spawned == null,
      canHold: true,
      score: state.score + gained,
      lines: totalLines,
      level: level,
      status: spawned == null ? TetrisStatus.over : TetrisStatus.playing,
      lastClearedRows: fullRows,
      lastClearCount: cleared.cleared,
      moveSeq: state.moveSeq + 1,
    );
  }

  /// Достаёт следующий тип из очереди (и пополняет её), спавнит фигуру сверху.
  /// Возвращает `null`, если фигура не помещается (конец).
  ActivePiece? _spawnFromQueue() {
    final next = state.queue.first;
    final p = _spawnPiece(next, advanceQueue: true);
    return p;
  }

  /// Спавнит фигуру типа [type] сверху по центру. Если [advanceQueue] — сдвигает
  /// очередь и дозаполняет её из мешка. Возвращает `null` при коллизии (конец).
  ActivePiece? _spawnPiece(PieceType type, {bool advanceQueue = false}) {
    if (advanceQueue) {
      final q = [...state.queue]..removeAt(0);
      while (q.length < tetrisQueuePreview) {
        q.add(_drawType());
      }
      state = state.copyWith(queue: q);
    }
    final col = tetrisSpawnCol(type);
    final piece = ActivePiece(type: type, rot: 0, r: 0, c: col);
    if (!tetrisCanPlace(state.board, type, 0, 0, col)) return null;
    return piece;
  }

  /// Тянет следующий тип из мешка с учётом зеркального набора (§ 8.5).
  PieceType _drawType() {
    final t = _bag.draw().type;
    return _mirror ? mirrorOf(t) : t;
  }

  /// Свежая партия: новый мешок, заполненная очередь, первая фигура.
  TetrisState _freshState(int seed, {required bool mirror}) {
    _bag = Bag(seed);
    _mirror = mirror;
    _accum = 0;
    final queue = <PieceType>[for (int i = 0; i < tetrisQueuePreview + 1; i++) _drawType()];
    final firstType = queue.removeAt(0);
    final col = tetrisSpawnCol(firstType);
    return TetrisState(
      board: emptyTetrisBoard(),
      piece: ActivePiece(type: firstType, rot: 0, r: 0, c: col),
      queue: queue,
      hold: null,
      canHold: true,
      score: 0,
      lines: 0,
      level: 1,
      status: TetrisStatus.playing,
    );
  }
}

/// Провайдер ViewModel живой партии Tetris.
final tetrisProvider = NotifierProvider<TetrisNotifier, TetrisState>(
  TetrisNotifier.new,
);
