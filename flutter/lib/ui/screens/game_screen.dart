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

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../achievements/achievement.dart';
import '../../achievements/achievements_controller.dart';
import '../../audio/audio_service.dart';
import '../../audio/sfx.dart';
import '../../daily/daily.dart';
import '../../daily/daily_controller.dart';
import '../../game/game_notifier.dart';
import '../../game/game_state.dart';
import '../../game/match_config.dart';
import '../../profile/profile_controller.dart';
import '../../settings/settings_controller.dart';
import '../decor/combo_flash.dart';
import '../decor/mascot.dart';
import '../decor/pause_overlay.dart';
import '../decor/toast_stack.dart';
import '../design_tokens.dart';
import '../game/confetti_overlay.dart';
import '../theme/theme_controller.dart';
import '../widgets/board_view.dart';
import '../widgets/hand_view.dart';
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

class _GameScreenState extends ConsumerState<GameScreen> {
  /// Конфиг партии, созданный один раз (стабильный ключ провайдера).
  late final MatchConfig _config;

  /// Flame-салют конфетти (живёт всё время жизни экрана).
  final ConfettiGame _confetti = ConfettiGame();

  /// Активная вспышка комбо (null — ничего не показываем).
  _ComboFlashData? _comboFlash;

  /// Очередь тостов о вновь разблокированных ачивках.
  final List<Achievement> _toasts = [];

  /// Проигрывает звук клика по элементу UI.
  void _click() => ref.read(audioServiceProvider).play(Sfx.click);

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

  /// Запускает визуальные эффекты на новом ходу: салют конфетти на perfect и
  /// вспышку комбо при пересечении вех (3/5/10) ходившим человеком. Эффекты
  /// гасятся при reduceMotion. [prev]/[next] — состояния до/после хода.
  void _playMoveEffects(GameState? prev, GameState next) {
    if (prev == null || next.moveSeq <= prev.moveSeq) return;
    if (ref.read(settingsControllerProvider).reduceMotion) return;
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;

    if (next.lastPerfect) {
      _confetti.burst([tokens.p0, tokens.p1, tokens.good]);
    }

    // Веха комбо: ходивший игрок — prev.current; его combo выросло после хода.
    final mover = prev.current;
    if (_config.isBot(mover)) return;
    final oldC = prev.players[mover].combo;
    final newC = next.players[mover].combo;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    // Начисляем награды игроку 0 (человеку) при завершении партии — кроме
    // зрительского bot×bot. Срабатывает один раз на переходе в gameOver.
    ref.listen(gameProvider(_config), (prev, next) {
      _playMoveSfx(prev, next);
      _playMoveEffects(prev, next);
      final justEnded = (prev == null || !prev.gameOver) && next.gameOver;
      if (justEnded && _config.mode != MatchMode.botvbot) {
        final won = next.winner == 0;
        final draw = next.winner == null;
        final coins = ref
            .read(profileControllerProvider.notifier)
            .recordResult(won: won, draw: draw);
        // Пересчёт достижений (вновь разблокированные → тосты) и прогресс
        // ежедневных квестов.
        final fresh = ref
            .read(achievementsControllerProvider.notifier)
            .evaluate();
        if (fresh.isNotEmpty) setState(() => _toasts.addAll(fresh));
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

    return Scaffold(
      backgroundColor: theme.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
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
                      Scoreboard(state: state, theme: theme),
                      if (humanTurn) ...[
                        const SizedBox(height: 10),
                        TurnTimer(state: state, theme: theme),
                      ],
                      const SizedBox(height: 12),
                      BoardView(
                        state: state,
                        theme: theme,
                        onPlace: vm.placeAt,
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
                      const SizedBox(height: 10),
                      HandView(
                        hand: state.currentPlayer.hand,
                        selectedId: state.selectedPieceId,
                        interactive: humanTurn,
                        owner: state.current,
                        theme: theme,
                        onSelect: vm.selectPiece,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Салют конфетти (perfect clear) — поверх поля, под оверлеями.
          Positioned.fill(child: ConfettiOverlay(game: _confetti)),
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
        ],
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
  final VoidCallback onNewGame;
  final VoidCallback onMenu;

  const _GameOverOverlay({
    required this.theme,
    required this.themeId,
    required this.winnerName,
    required this.scores,
    required this.onNewGame,
    required this.onMenu,
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
                winnerName == null ? 'Ничья' : 'Победил $winnerName',
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: theme.fontDisplay,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'счёт ${scores[0]} : ${scores[1]}',
                style: TextStyle(
                  color: theme.muted,
                  fontSize: 15,
                  fontFamily: theme.fontMono,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconButton(theme: theme, label: '← меню', onTap: onMenu),
                  const SizedBox(width: 12),
                  _IconButton(
                    theme: theme,
                    label: '↺ новая игра',
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
