/// match_config.dart — конфигурация партии (Model-слой игры).
///
/// За что отвечает файл:
///   Неизменяемые параметры запускаемой партии: режим, какие игроки — боты,
///   уровень бота, правила ядра и seed для детерминированных мешков. Создаётся
///   один раз во View (GameScreen.initState) и служит ключом семейства
///   провайдера ViewModel, поэтому имеет значимое равенство.
///
/// Соответствие TS: входные параметры `useGame` (mode/botLevel/seed).
library;

import 'package:block_duel/core/core.dart';

/// Режим партии, поддерживаемый игровым экраном Фазы 2.3.
enum MatchMode {
  /// Двое за одним устройством (оба — люди).
  hotseat,

  /// Игрок против бота (игрок 0 — человек, игрок 1 — бот).
  bot,

  /// Бот против бота (зрительский режим).
  botvbot,

  /// Соло на рекорд (ходит только игрок 0; партия до собственного тупика).
  arcade,
}

/// Параметры партии. Неизменяемые, со значимым равенством (для Riverpod family).
class MatchConfig {
  /// Режим партии.
  final MatchMode mode;

  /// Уровень бота (для режимов с ботом).
  final BotLevel botLevel;

  /// Правила игры.
  final RuleConfig cfg;

  /// Seed для мешков обоих игроков (задаётся один раз при старте партии).
  final int seed;

  /// Продолжить ли сохранённую партию с этим seed (resume), а не начать новую.
  final bool resume;

  /// Создаёт конфигурацию партии.
  const MatchConfig({
    required this.mode,
    required this.seed,
    this.botLevel = BotLevel.medium,
    this.cfg = defaultConfig,
    this.resume = false,
  });

  /// Является ли игрок [player] (0/1) ботом в этом режиме.
  bool isBot(int player) => switch (mode) {
    MatchMode.hotseat => false,
    MatchMode.bot => player == 1,
    MatchMode.botvbot => true,
    MatchMode.arcade => false,
  };

  /// Соло-режим (ходит только игрок 0, ход никогда не передаётся).
  bool get isSolo => mode == MatchMode.arcade;

  /// Разбирает строковый код режима из маршрута.
  /// Неизвестные значения трактуются как [MatchMode.bot].
  static MatchMode modeFromString(String raw) => switch (raw) {
    'hotseat' => MatchMode.hotseat,
    'botvbot' => MatchMode.botvbot,
    'arcade' => MatchMode.arcade,
    _ => MatchMode.bot,
  };

  @override
  bool operator ==(Object other) =>
      other is MatchConfig &&
      other.mode == mode &&
      other.botLevel == botLevel &&
      other.seed == seed &&
      other.resume == resume &&
      identical(other.cfg, cfg);

  @override
  int get hashCode =>
      Object.hash(mode, botLevel, seed, resume, identityHashCode(cfg));
}
