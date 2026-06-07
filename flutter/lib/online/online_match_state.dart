/// online_match_state.dart — состояние онлайн-матча и ключ его провайдера.
///
/// За что отвечает файл:
///   [OnlineMatchState] — снимок для View: серверное состояние игры + мета
///   соединения (подключён ли, ушёл ли соперник), локальный выбор фигуры,
///   флаги ремача и поля последнего хода (для звука/эффектов по диффу).
///   [OnlineMatchArgs] — ключ семейства провайдера (комната + свой профиль) со
///   значимым равенством.
library;

import 'online_models.dart';

/// Снимок онлайн-матча для View.
class OnlineMatchState {
  /// Серверное состояние игры (null до первого `joined`).
  final OnlineGameState? game;

  /// Индекс локального игрока (0/1), приходит в `joined`.
  final int you;

  /// Есть ли WS-соединение.
  final bool connected;

  /// Отключился ли соперник.
  final bool opponentLeft;

  /// Сколько мс даётся сопернику на возврат (для отсчёта).
  final int? opponentTimeoutMs;

  /// Текст последней ошибки/отказа хода.
  final String? lastError;

  /// Запросил ли ремач локальный игрок.
  final bool rematchYours;

  /// Запросил ли ремач соперник.
  final bool rematchTheirs;

  /// Кто сделал последний ход (для эффектов).
  final int? lastMoveOwner;

  /// Очки за последний ход.
  final int lastGained;

  /// Был ли последний ход perfect.
  final bool lastPerfect;

  /// Счётчик ходов (растёт на каждый `state` с ходом) — триггер SFX/FX в View.
  final int moveSeq;

  /// Локально выбранная фигура (id) или null.
  final String? selectedPieceId;

  /// Индекс ориентации выбранной фигуры.
  final int orientIndex;

  /// Счётчик отказов хода (триггер shake-анимации).
  final int rejectSeq;

  const OnlineMatchState({
    this.game,
    this.you = 0,
    this.connected = false,
    this.opponentLeft = false,
    this.opponentTimeoutMs,
    this.lastError,
    this.rematchYours = false,
    this.rematchTheirs = false,
    this.lastMoveOwner,
    this.lastGained = 0,
    this.lastPerfect = false,
    this.moveSeq = 0,
    this.selectedPieceId,
    this.orientIndex = 0,
    this.rejectSeq = 0,
  });

  /// Копия с изменениями (флаги сброса для nullable-полей — явными булями).
  OnlineMatchState copyWith({
    OnlineGameState? game,
    int? you,
    bool? connected,
    bool? opponentLeft,
    int? opponentTimeoutMs,
    bool clearOpponentTimeout = false,
    String? lastError,
    bool clearError = false,
    bool? rematchYours,
    bool? rematchTheirs,
    int? lastMoveOwner,
    int? lastGained,
    bool? lastPerfect,
    int? moveSeq,
    String? selectedPieceId,
    bool clearSelection = false,
    int? orientIndex,
    int? rejectSeq,
  }) => OnlineMatchState(
    game: game ?? this.game,
    you: you ?? this.you,
    connected: connected ?? this.connected,
    opponentLeft: opponentLeft ?? this.opponentLeft,
    opponentTimeoutMs: clearOpponentTimeout
        ? null
        : (opponentTimeoutMs ?? this.opponentTimeoutMs),
    lastError: clearError ? null : (lastError ?? this.lastError),
    rematchYours: rematchYours ?? this.rematchYours,
    rematchTheirs: rematchTheirs ?? this.rematchTheirs,
    lastMoveOwner: lastMoveOwner ?? this.lastMoveOwner,
    lastGained: lastGained ?? this.lastGained,
    lastPerfect: lastPerfect ?? this.lastPerfect,
    moveSeq: moveSeq ?? this.moveSeq,
    selectedPieceId: clearSelection
        ? null
        : (selectedPieceId ?? this.selectedPieceId),
    orientIndex: orientIndex ?? this.orientIndex,
    rejectSeq: rejectSeq ?? this.rejectSeq,
  );
}

/// Ключ семейства провайдера онлайн-матча: комната + свой профиль.
class OnlineMatchArgs {
  final String roomId;
  final OnlineProfile me;

  const OnlineMatchArgs({required this.roomId, required this.me});

  @override
  bool operator ==(Object other) =>
      other is OnlineMatchArgs &&
      other.roomId == roomId &&
      other.me.id == me.id;

  @override
  int get hashCode => Object.hash(roomId, me.id);
}
