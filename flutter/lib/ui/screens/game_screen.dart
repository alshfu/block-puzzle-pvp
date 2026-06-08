/// game_screen.dart — игровой экран (View, сборка партии).
///
/// За что отвечает файл:
///   Собирает игровой UI: скорборд, доску [BoardView], контролы трансформации,
///   руку [HandView] и оверлей конца партии. Чистый View по MVVM: создаёт
///   стабильный [MatchConfig] один раз (включая seed), читает состояние из
///   [gameProvider] (ViewModel) и шлёт ему команды; игровой логики не содержит.
///
/// Соответствие TS: `screens/GameScreen.tsx`. Blitz-таймер/force-place и
/// результат-оверлей с XP — Фазы 3–4.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../achievements/achievement.dart';
import '../../achievements/achievements_controller.dart';
import '../../achievements/engine.dart';
import '../../achievements/stats_controller.dart';
import '../../audio/audio_service.dart';
import '../../audio/sfx.dart';
import '../../daily/daily.dart';
import '../../daily/daily_controller.dart';
import '../../game/game_notifier.dart';
import '../../game/game_state.dart';
import '../../game/match_config.dart';
import '../../pilot/developer.dart';
import '../../profile/profile_controller.dart';
import '../../settings/settings.dart';
import '../../settings/settings_controller.dart';
import '../../shop/inventory_controller.dart';
import '../../shop/skins.dart';
import '../../shop/skins_controller.dart';
import '../decor/combo_flash.dart';
import '../decor/mascot.dart';
import '../decor/pause_overlay.dart';
import '../decor/toast_stack.dart';
import '../design_tokens.dart';
import '../game/confetti_overlay.dart';
import '../theme/theme_controller.dart';
import '../widgets/board_view.dart';
import '../widgets/hand_view.dart';
import '../widgets/mini_piece.dart';
import '../widgets/powerups_panel.dart';
import '../widgets/scoreboard.dart';
import '../widgets/turn_timer.dart';

/// Игровой экран для режима [modeRaw] (строка из маршрута).
class GameScreen extends ConsumerStatefulWidget {
  /// Код режима из маршрута (`bot`/`hotseat`/`botvbot`).
  final String modeRaw;

  /// Seed сохранённой партии для продолжения (resume) либо `null` — новая игра.
  final int? resumeSeed;

  /// Уровень бота (из SetupScreen); null — дефолт.
  final BotLevel? botLevel;

  /// Правила партии (из SetupScreen); null — [defaultConfig].
  final RuleConfig? cfg;

  /// Создаёт игровой экран.
  const GameScreen({
    super.key,
    required this.modeRaw,
    this.resumeSeed,
    this.botLevel,
    this.cfg,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  /// Конфиг партии, созданный один раз (стабильный ключ провайдера).
  late final MatchConfig _config;

  /// Flame-салют конфетти (живёт всё время жизни экрана).
  final ConfettiGame _confetti = ConfettiGame();

  /// Активная вспышка комбо (null — ничего не показываем).
  _ComboFlashData? _comboFlash;

  /// Активный всплывающий «+N» (null — ничего не показываем).
  _ScorePopupData? _scorePopup;

  /// Контроллер экранной встряски (большие комбо/мульти-очистки).
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  // ── Скрытый pilot (локально для экрана, см. _PilotHud) ────────────────────
  /// Таймер цикла пилота (null — выключен).
  Timer? _pilotTimer;

  /// На паузе ли пилот.
  bool _pilotPaused = false;

  /// Сколько ходов сделал пилот за сессию.
  int _pilotMoves = 0;

  /// Период хода пилота.
  static const Duration _pilotTick = Duration(milliseconds: 650);

  /// Запускает пилота: по таймеру сам играет, по концу партии перезапускает.
  void _startPilot() {
    if (_pilotTimer != null) return;
    setState(() {
      _pilotPaused = false;
      _pilotMoves = 0;
    });
    _pilotTimer = Timer.periodic(_pilotTick, (_) => _pilotStep());
  }

  /// Один тик пилота: ход за человека либо перезапуск завершённой партии.
  void _pilotStep() {
    if (_pilotPaused) return;
    final vm = ref.read(gameProvider(_config).notifier);
    final game = ref.read(gameProvider(_config));
    if (game.gameOver) {
      vm.newGame(); // непрерывный демо-цикл
      return;
    }
    if (_config.isBot(game.current)) return; // ждём ход бота
    if (vm.pilotPlayTurn()) {
      setState(() => _pilotMoves++);
    }
  }

  void _togglePilotPause() => setState(() => _pilotPaused = !_pilotPaused);

  void _stopPilot() {
    _pilotTimer?.cancel();
    _pilotTimer = null;
    setState(() => _pilotPaused = false);
  }

  @override
  void dispose() {
    _pilotTimer?.cancel();
    _shake.dispose();
    super.dispose();
  }

  /// Очередь тостов о вновь разблокированных ачивках.
  final List<AchievementDef> _toasts = [];

  // Итог последнего матча (для экрана результата).
  int _resultXp = 0;
  int _resultCoins = 0;
  int _resultStreak = 0;
  List<AchievementDef> _resultAchievements = const [];

  // Накопители статистики текущего матча (ходы игрока 0 — «ты»).
  int _matchClears = 0;
  int _matchMaxMulti = 0;
  int _matchBestCombo = 0;
  bool _matchPerfect = false;

  /// Активный power-up в режиме выбора клетки (палочка/бомба) или `null`.
  String? _activePowerup;

  /// Проигрывает звук клика по элементу UI.
  void _click() => ref.read(audioServiceProvider).play(Sfx.click);

  /// Нажатие по power-up в панели: мгновенные эффекты применяются сразу,
  /// палочка/бомба переводят доску в режим выбора клетки.
  void _handlePowerup(String id) {
    final inv = ref.read(inventoryControllerProvider.notifier);
    if (inv.count(id) <= 0) return;
    final vm = ref.read(gameProvider(_config).notifier);
    _click();
    switch (id) {
      case 'swap_hand':
        if (vm.powerSwapHand()) inv.consume(id);
        setState(() => _activePowerup = null);
      case 'auto_play':
        if (vm.powerAutoPlay()) inv.consume(id);
        setState(() => _activePowerup = null);
      case 'hint':
        if (vm.powerHint()) inv.consume(id);
        setState(() => _activePowerup = null);
      default:
        // stick_row / stick_col / bomb_3x3 — режим выбора клетки (toggle).
        setState(() => _activePowerup = _activePowerup == id ? null : id);
    }
  }

  /// Тап по доске: либо применяем активный power-up к клетке, либо ставим фигуру.
  void _onBoardTap(int r, int c) {
    final active = _activePowerup;
    if (active != null) {
      final vm = ref.read(gameProvider(_config).notifier);
      final used = switch (active) {
        'stick_row' => vm.powerClearRow(r),
        'stick_col' => vm.powerClearCol(c),
        'bomb_3x3' => vm.powerBomb(r, c),
        _ => false,
      };
      if (used) ref.read(inventoryControllerProvider.notifier).consume(active);
      setState(() => _activePowerup = null);
      return;
    }
    ref.read(gameProvider(_config).notifier).placeAt(r, c);
  }

  /// Горячие клавиши (десктоп): R — поворот выбранной фигуры, Esc — снять
  /// выбор/отменить активный power-up. Порт r/escape из TS-версии.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.keyR) {
      ref.read(gameProvider(_config).notifier).rotateSelected();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      if (_activePowerup != null) {
        setState(() => _activePowerup = null);
      } else {
        ref.read(gameProvider(_config).notifier).deselect();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Горизонтальное смещение встряски для фазы [t] (0..1): затухающая синусоида.
  double _shakeDx(double t) => math.sin(t * math.pi * 6) * (1 - t) * 9;

  /// Тактильная отдача по режиму [mode]; [clear] — была ли очистка (сильнее).
  /// На web/десктопе без вибромотора — no-op.
  void _vibrate(VibrationMode mode, bool clear) {
    switch (mode) {
      case VibrationMode.off:
        return;
      case VibrationMode.light:
        HapticFeedback.lightImpact();
      case VibrationMode.strong:
        clear ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
    }
  }

  @override
  void initState() {
    super.initState();
    final mode = MatchConfig.modeFromString(widget.modeRaw);
    if (widget.resumeSeed != null) {
      // Продолжение: тот же seed + флаг resume (ViewModel восстановит снимок).
      _config = MatchConfig(mode: mode, seed: widget.resumeSeed!, resume: true);
    } else {
      // Новая игра: seed берётся во View (ядро остаётся детерминированным).
      // Уровень бота и правила приходят из SetupScreen (или дефолт).
      final seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
      _config = MatchConfig(
        mode: mode,
        seed: seed,
        botLevel: widget.botLevel ?? BotLevel.medium,
        cfg: widget.cfg ?? defaultConfig,
      );
    }
  }

  /// Граница «danger-зоны» таймера (с) — ниже неё тикает звук.
  static const double _dangerThreshold = 3.0;

  /// Играет звук хода по диффу состояния: постановка/очистка/perfect — на новом
  /// ходу ([moveSeq] вырос); тик — при входе остатка таймера в danger-зону.
  void _playMoveSfx(GameState? prev, GameState next) {
    final audio = ref.read(audioServiceProvider);
    if (prev != null && next.moveSeq > prev.moveSeq) {
      if (next.lastPerfect) {
        audio.play(Sfx.perfect);
      } else if (next.lastClearCount > 0) {
        audio.playClear(next.lastClearCount);
      } else {
        audio.play(Sfx.place);
      }
    }
    // Тик таймера: только на ходу человека, при пересечении порога вниз.
    if (prev != null &&
        !next.gameOver &&
        !_config.isBot(next.current) &&
        next.turnLimit.isFinite) {
      final crossedDown =
          prev.turnRemaining > _dangerThreshold &&
          next.turnRemaining <= _dangerThreshold;
      if (crossedDown) audio.play(Sfx.tick);
    }
  }

  /// Запускает эффекты на новом ходу: вибрация, салют конфетти на perfect и
  /// вспышку комбо при пересечении вех (3/5/10) ходившим человеком. Анимации
  /// гасятся при reduceMotion / выключенных тогглах. [prev]/[next] — до/после.
  void _playMoveEffects(GameState? prev, GameState next) {
    if (prev == null || next.moveSeq <= prev.moveSeq) return;
    final settings = ref.read(settingsControllerProvider);

    // Вибрация (тач-устройства; на web no-op) — независимо от reduceMotion.
    _vibrate(settings.vibration, next.lastClearCount > 0 || next.lastPerfect);

    if (settings.reduceMotion) return;
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;

    if (next.lastPerfect && settings.confettiEnabled) {
      _confetti.burst([tokens.p0, tokens.p1, tokens.good]);
    }

    // Всплывающие очки «+N» на очистках (ТЗ §8.2).
    final mover = prev.current;
    final gained = next.players[mover].score - prev.players[mover].score;
    if (gained > 0) {
      setState(() {
        _scorePopup = _ScorePopupData(key: next.moveSeq, gained: gained);
      });
    }

    // Экранная встряска на больших комбо/мульти-очистках (ТЗ §8.2).
    final newC = next.players[mover].combo;
    if (next.lastClearCount >= 4 || newC >= 5) _shake.forward(from: 0);

    // Веха комбо: ходивший игрок — prev.current; его combo выросло после хода.
    if (_config.isBot(mover)) return;
    final oldC = prev.players[mover].combo;
    var level = 0;
    if (oldC < 3 && newC >= 3) level = 1;
    if (oldC < 5 && newC >= 5) level = 2;
    if (oldC < 10 && newC >= 10) level = 3;
    if (level == 0) return;

    final themeId = ref.read(themeControllerProvider);
    setState(() {
      _comboFlash = _ComboFlashData(
        key: next.moveSeq,
        level: level,
        combo: newC,
        message: pickComboMessage(themeId, level),
      );
    });
  }

  /// Накапливает статистику матча по ходам игрока 0 («ты»); сбрасывает на новой
  /// партии (когда [moveSeq] обнулился).
  void _accumulateMatch(GameState? prev, GameState next) {
    if (prev != null && next.moveSeq < prev.moveSeq) {
      _matchClears = 0;
      _matchMaxMulti = 0;
      _matchBestCombo = 0;
      _matchPerfect = false;
    }
    if (prev == null || next.moveSeq <= prev.moveSeq) return;
    if (prev.current != 0) return; // считаем только свои ходы
    _matchClears += next.lastClearCount;
    if (next.lastClearCount > _matchMaxMulti) {
      _matchMaxMulti = next.lastClearCount;
    }
    final combo = next.players[0].combo;
    if (combo > _matchBestCombo) _matchBestCombo = combo;
    if (next.lastPerfect) _matchPerfect = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    // Начисляем награды игроку 0 (человеку) при завершении партии — кроме
    // зрительского bot×bot. Срабатывает один раз на переходе в gameOver.
    ref.listen(gameProvider(_config), (prev, next) {
      _playMoveSfx(prev, next);
      _playMoveEffects(prev, next);
      _accumulateMatch(prev, next);
      final justEnded = (prev == null || !prev.gameOver) && next.gameOver;
      if (justEnded && _config.mode != MatchMode.botvbot) {
        final won = next.winner == 0;
        final draw = next.winner == null;
        final xpBefore = ref.read(profileControllerProvider).xp;
        final coins = ref
            .read(profileControllerProvider.notifier)
            .recordResult(won: won, draw: draw);
        // Статистика матча → достижения (вновь разблокированные → тосты).
        final winner = draw ? -1 : (won ? 0 : 1);
        final stats = ref
            .read(statsControllerProvider.notifier)
            .recordOffline(
              winner: winner,
              matchClears: _matchClears,
              maxMulti: _matchMaxMulti,
              bestScore: next.players[0].score,
            );
        final fresh = ref
            .read(achievementsControllerProvider.notifier)
            .recordMatch(
              MatchContext(
                winner: winner,
                hadPerfectClear: _matchPerfect,
                maxMultiClear: _matchMaxMulti,
                bestCombo: _matchBestCombo,
                mode: _config.mode.name,
                botLevel: _config.mode == MatchMode.bot
                    ? _config.botLevel.name
                    : null,
                statsAfter: stats,
                winStreak: stats.currentWinStreak,
              ),
            );
        // Кристаллы за очки (1 за 150) — премиум-валюта для power-ups.
        ref
            .read(profileControllerProvider.notifier)
            .earnCrystalsFromScore(next.players[0].score);
        // Прирост XP за матч (награды + XP ачивок) — для экрана результата.
        final gainedXp = ref.read(profileControllerProvider).xp - xpBefore;
        setState(() {
          if (fresh.isNotEmpty) _toasts.addAll(fresh);
          _resultXp = gainedXp;
          _resultCoins = coins;
          _resultAchievements = fresh;
          _resultStreak = won && !draw ? stats.currentWinStreak : 0;
        });
        ref
            .read(dailyControllerProvider.notifier)
            .recordGame(DailyGameEvent(won: won && !draw, coinsEarned: coins));
      }
      if (justEnded) {
        final audio = ref.read(audioServiceProvider);
        audio.play(
          next.winner == null
              ? Sfx.draw
              : (next.winner == 0 ? Sfx.win : Sfx.lose),
        );
      }
    });
    final state = ref.watch(gameProvider(_config));
    final vm = ref.read(gameProvider(_config).notifier);
    final humanTurn = !state.gameOver && !_config.isBot(state.current);
    final canRotate =
        state.selectedPiece != null &&
        (_config.cfg.rotationEnabled || _config.cfg.flipEnabled);

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: theme.bg,
        body: Stack(
          children: [
            // Контент с экранной встряской на больших комбо.
            AnimatedBuilder(
              animation: _shake,
              builder: (context, child) => Transform.translate(
                offset: Offset(_shakeDx(_shake.value), 0),
                child: child,
              ),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    // Прокрутка, если окно ниже контента (десктоп-ресайз/короткий
                    // экран): иначе RenderFlex overflow по высоте.
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TopBar(
                              theme: theme,
                              onNewGame: vm.newGame,
                              onPause: () {
                                _click();
                                vm.setPaused(true);
                              },
                            ),
                            const SizedBox(height: 10),
                            Scoreboard(
                              state: state,
                              theme: theme,
                              solo: _config.isSolo,
                            ),
                            if (humanTurn) ...[
                              const SizedBox(height: 10),
                              TurnTimer(state: state, theme: theme),
                            ],
                            const SizedBox(height: 12),
                            BoardView(
                              state: state,
                              theme: theme,
                              onPlace: _onBoardTap,
                              showGhost: ref
                                  .watch(settingsControllerProvider)
                                  .ghostEnabled,
                              skin: skinStyleOf(
                                ref.watch(skinsControllerProvider).equipped,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _Controls(
                              theme: theme,
                              humanTurn: humanTurn,
                              canRotate: canRotate,
                              hasSelection: state.selectedPiece != null,
                              onRotate: vm.rotateSelected,
                              onDeselect: vm.deselect,
                            ),
                            if (_config.mode != MatchMode.botvbot) ...[
                              const SizedBox(height: 8),
                              PowerupsPanel(
                                theme: theme,
                                inventory: ref.watch(
                                  inventoryControllerProvider,
                                ),
                                active: _activePowerup,
                                enabled: humanTurn,
                                onTap: _handlePowerup,
                              ),
                            ],
                            const SizedBox(height: 8),
                            if (state.nextPieces.length > state.current)
                              _NextPreview(
                                theme: theme,
                                type: state.nextPieces[state.current],
                                owner: state.current,
                              ),
                            const SizedBox(height: 6),
                            HandView(
                              hand: state.currentPlayer.hand,
                              selectedId: state.selectedPieceId,
                              selectedCells: state.activeCells,
                              interactive: humanTurn,
                              owner: state.current,
                              theme: theme,
                              onSelect: vm.selectPiece,
                              onRotate: vm.rotateSelected,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Салют конфетти (perfect clear) — поверх поля, под оверлеями.
            Positioned.fill(child: ConfettiOverlay(game: _confetti)),
            // Всплывающие очки «+N».
            if (_scorePopup != null)
              _ScorePopup(
                key: ValueKey(_scorePopup!.key),
                gained: _scorePopup!.gained,
                theme: theme,
                onDone: () => setState(() => _scorePopup = null),
              ),
            // Вспышка комбо-вехи.
            if (_comboFlash != null)
              ComboFlash(
                key: ValueKey(_comboFlash!.key),
                themeId: ref.watch(themeControllerProvider),
                level: _comboFlash!.level,
                combo: _comboFlash!.combo,
                message: _comboFlash!.message,
                onComplete: () => setState(() => _comboFlash = null),
              ),
            // Оверлей паузы (таймеры остановлены в ViewModel).
            if (state.paused && !state.gameOver)
              PauseOverlay(
                theme: theme,
                onResume: () {
                  _click();
                  vm.setPaused(false);
                },
                onRestart: () {
                  _click();
                  vm.setPaused(false);
                  vm.newGame();
                },
                onExit: () {
                  _click();
                  context.go('/');
                },
              ),
            if (state.gameOver)
              _GameOverOverlay(
                theme: theme,
                themeId: ref.watch(themeControllerProvider),
                winnerName: state.winner == null
                    ? null
                    : state.players[state.winner!].name,
                scores: [state.players[0].score, state.players[1].score],
                gainedXp: _resultXp,
                gainedCoins: _resultCoins,
                achievements: _resultAchievements,
                winStreak: _resultStreak,
                solo: _config.isSolo,
                onNewGame: () {
                  _click();
                  vm.newGame();
                },
                onMenu: () {
                  _click();
                  context.go('/');
                },
              ),
            // Тосты о вновь разблокированных ачивках (поверх всего).
            ToastStack(
              toasts: _toasts,
              theme: theme,
              onDismiss: (id) =>
                  setState(() => _toasts.removeWhere((a) => a.id == id)),
            ),
            // Скрытый pilot — только в режиме разработчика.
            if (ref.watch(isDeveloperProvider))
              Positioned(
                left: 12,
                bottom: 12,
                child: _PilotHud(
                  theme: theme,
                  running: _pilotTimer != null,
                  paused: _pilotPaused,
                  moves: _pilotMoves,
                  onStart: _startPilot,
                  onPause: _togglePilotPause,
                  onStop: _stopPilot,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// HUD скрытого пилота (виден только разработчику). Запуск/пауза/стоп + счётчик.
class _PilotHud extends StatelessWidget {
  final BlockDuelTheme theme;
  final bool running;
  final bool paused;
  final int moves;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onStop;

  const _PilotHud({
    required this.theme,
    required this.running,
    required this.paused,
    required this.moves,
    required this.onStart,
    required this.onPause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (!running) {
      return _PillButton(theme: theme, label: '🛩 Pilot', onTap: onStart);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(theme.btnRadius),
        border: Border.all(color: theme.p0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🛩 $moves',
            style: TextStyle(
              color: theme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: theme.fontMono,
            ),
          ),
          const SizedBox(width: 8),
          _MiniIcon(theme: theme, icon: paused ? '▶' : '⏸', onTap: onPause),
          const SizedBox(width: 4),
          _MiniIcon(theme: theme, icon: '⏹', onTap: onStop),
        ],
      ),
    );
  }
}

/// Маленькая иконка-кнопка пилот-HUD.
class _MiniIcon extends StatelessWidget {
  final BlockDuelTheme theme;
  final String icon;
  final VoidCallback onTap;

  const _MiniIcon({
    required this.theme,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Text(icon, style: TextStyle(color: theme.ink, fontSize: 14)),
    ),
  );
}

/// Пилюля-кнопка запуска пилота.
class _PillButton extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final VoidCallback onTap;

  const _PillButton({
    required this.theme,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: theme.panel.withValues(alpha: 0.85),
    borderRadius: BorderRadius.circular(theme.btnRadius),
    child: InkWell(
      borderRadius: BorderRadius.circular(theme.btnRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.btnRadius),
          border: Border.all(color: theme.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: theme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

/// Превью «дальше»: следующая фигура текущего игрока (ТЗ §8.1).
class _NextPreview extends StatelessWidget {
  final BlockDuelTheme theme;
  final PieceType type;
  final int owner;

  const _NextPreview({
    required this.theme,
    required this.type,
    required this.owner,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Дальше',
          style: TextStyle(
            color: theme.muted,
            fontSize: 11,
            fontFamily: theme.fontMono,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: theme.panel,
            borderRadius: BorderRadius.circular(theme.btnRadius),
            border: Border.all(color: theme.line),
          ),
          child: MiniPiece(
            cells: baseShapes[type]!,
            owner: owner,
            cellSize: 10,
          ),
        ),
      ],
    );
  }
}

/// Данные активного всплывающего «+N» ([key] перезапускает анимацию).
class _ScorePopupData {
  final int key;
  final int gained;
  const _ScorePopupData({required this.key, required this.gained});
}

/// Всплывающие очки «+N»: всплывает вверх и гаснет (~0.9с), затем [onDone].
class _ScorePopup extends StatefulWidget {
  final int gained;
  final BlockDuelTheme theme;
  final VoidCallback onDone;

  const _ScorePopup({
    super.key,
    required this.gained,
    required this.theme,
    required this.onDone,
  });

  @override
  State<_ScorePopup> createState() => _ScorePopupState();
}

class _ScorePopupState extends State<_ScorePopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: const Alignment(0, -0.45),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final opacity = (t < 0.2 ? t / 0.2 : 1 - (t - 0.2) / 0.8).clamp(
                0.0,
                1.0,
              );
              return Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, -40 * t),
                  child: Text(
                    '+${widget.gained}',
                    style: TextStyle(
                      color: widget.theme.p0,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      fontFamily: widget.theme.fontMono,
                      shadows: [
                        Shadow(
                          color: widget.theme.p0.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Данные активной вспышки комбо ([key] перезапускает анимацию на новой вехе).
class _ComboFlashData {
  final int key;
  final int level;
  final int combo;
  final String message;

  const _ComboFlashData({
    required this.key,
    required this.level,
    required this.combo,
    required this.message,
  });
}

/// Верхняя панель игрового экрана: назад + новая игра.
class _TopBar extends StatelessWidget {
  final BlockDuelTheme theme;
  final VoidCallback onNewGame;
  final VoidCallback onPause;

  const _TopBar({
    required this.theme,
    required this.onNewGame,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconButton(
          theme: theme,
          label: '← меню',
          onTap: () => context.go('/'),
        ),
        const Spacer(),
        _IconButton(theme: theme, label: '⏸ пауза', onTap: onPause),
        const SizedBox(width: 8),
        _IconButton(theme: theme, label: '↺ новая', onTap: onNewGame),
      ],
    );
  }
}

/// Контролы трансформации выбранной фигуры.
class _Controls extends StatelessWidget {
  final BlockDuelTheme theme;
  final bool humanTurn;
  final bool canRotate;
  final bool hasSelection;
  final VoidCallback onRotate;
  final VoidCallback onDeselect;

  const _Controls({
    required this.theme,
    required this.humanTurn,
    required this.canRotate,
    required this.hasSelection,
    required this.onRotate,
    required this.onDeselect,
  });

  @override
  Widget build(BuildContext context) {
    if (!humanTurn) {
      return SizedBox(
        height: 38,
        child: Center(
          child: Text(
            'Ход бота…',
            style: TextStyle(color: theme.muted, fontSize: 13),
          ),
        ),
      );
    }
    if (!hasSelection) {
      return SizedBox(
        height: 38,
        child: Center(
          child: Text(
            'выбери фигуру, затем тапни по доске',
            style: TextStyle(color: theme.muted, fontSize: 13),
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _IconButton(
          theme: theme,
          label: '↻ повернуть',
          onTap: canRotate ? onRotate : null,
        ),
        const SizedBox(width: 10),
        _IconButton(theme: theme, label: '✕ снять', onTap: onDeselect),
      ],
    );
  }
}

/// Небольшая кнопка-панель с текстом.
class _IconButton extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final VoidCallback? onTap;

  const _IconButton({
    required this.theme,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.panel,
      borderRadius: BorderRadius.circular(theme.btnRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.btnRadius),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.btnRadius),
              border: Border.all(color: theme.line),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: theme.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Оверлей конца партии: результат + кнопки.
class _GameOverOverlay extends StatelessWidget {
  final BlockDuelTheme theme;
  final ThemeId themeId;
  final String? winnerName;
  final List<int> scores;
  final int gainedXp;
  final int gainedCoins;
  final List<AchievementDef> achievements;
  final int winStreak;
  final bool solo;
  final VoidCallback onNewGame;
  final VoidCallback onMenu;

  const _GameOverOverlay({
    required this.theme,
    required this.themeId,
    required this.winnerName,
    required this.scores,
    required this.gainedXp,
    required this.gainedCoins,
    required this.achievements,
    required this.onNewGame,
    required this.onMenu,
    this.winStreak = 0,
    this.solo = false,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.panel,
            borderRadius: BorderRadius.circular(theme.cardRadius),
            border: Border.all(color: theme.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Mascot(themeId: themeId, size: 96),
              const SizedBox(height: 8),
              Text(
                solo
                    ? 'Игра окончена'
                    : (winnerName == null ? 'Ничья' : 'Победил $winnerName'),
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: theme.fontDisplay,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                solo ? 'счёт ${scores[0]}' : 'счёт ${scores[0]} : ${scores[1]}',
                style: TextStyle(
                  color: theme.muted,
                  fontSize: 15,
                  fontFamily: theme.fontMono,
                ),
              ),
              const SizedBox(height: 10),
              // Награды за матч (ТЗ §8.1): XP + монеты.
              Text(
                '+$gainedXp XP   ·   +$gainedCoins 🪙',
                style: TextStyle(
                  color: theme.good,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: theme.fontMono,
                ),
              ),
              // Баннер серии побед (от 2 подряд).
              if (winStreak >= 2) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.p0.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(theme.btnRadius),
                    border: Border.all(color: theme.p0),
                  ),
                  child: Text(
                    '🔥 Серия побед ×$winStreak',
                    style: TextStyle(
                      color: theme.p0,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              // Разблокированные за матч ачивки.
              if (achievements.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Новые ачивки',
                  style: TextStyle(color: theme.muted, fontSize: 11),
                ),
                const SizedBox(height: 4),
                for (final a in achievements)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      '${a.icon} ${a.title}',
                      style: TextStyle(color: theme.ink, fontSize: 13),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconButton(theme: theme, label: '← меню', onTap: onMenu),
                  const SizedBox(width: 12),
                  _IconButton(
                    theme: theme,
                    label: '↺ Реванш',
                    onTap: onNewGame,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
