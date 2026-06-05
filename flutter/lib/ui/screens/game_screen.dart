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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../game/game_notifier.dart';
import '../../game/match_config.dart';
import '../design_tokens.dart';
import '../widgets/board_view.dart';
import '../widgets/hand_view.dart';
import '../widgets/scoreboard.dart';

/// Игровой экран для режима [modeRaw] (строка из маршрута).
class GameScreen extends ConsumerStatefulWidget {
  /// Код режима из маршрута (`bot`/`hotseat`/`botvbot`).
  final String modeRaw;

  /// Создаёт игровой экран.
  const GameScreen({super.key, required this.modeRaw});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  /// Конфиг партии, созданный один раз (стабильный ключ провайдера).
  late final MatchConfig _config;

  @override
  void initState() {
    super.initState();
    // Seed берётся во View (не в ядре) — ядро остаётся детерминированным.
    final seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    _config = MatchConfig(
      mode: MatchConfig.modeFromString(widget.modeRaw),
      seed: seed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
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
                      _TopBar(theme: theme, onNewGame: vm.newGame),
                      const SizedBox(height: 10),
                      Scoreboard(state: state, theme: theme),
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
          if (state.gameOver)
            _GameOverOverlay(
              theme: theme,
              winnerName: state.winner == null
                  ? null
                  : state.players[state.winner!].name,
              scores: [state.players[0].score, state.players[1].score],
              onNewGame: vm.newGame,
            ),
        ],
      ),
    );
  }
}

/// Верхняя панель игрового экрана: назад + новая игра.
class _TopBar extends StatelessWidget {
  final BlockDuelTheme theme;
  final VoidCallback onNewGame;

  const _TopBar({required this.theme, required this.onNewGame});

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
  final String? winnerName;
  final List<int> scores;
  final VoidCallback onNewGame;

  const _GameOverOverlay({
    required this.theme,
    required this.winnerName,
    required this.scores,
    required this.onNewGame,
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
                  _IconButton(
                    theme: theme,
                    label: '← меню',
                    onTap: () => context.go('/'),
                  ),
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
