/// online_game_screen.dart — экран живого онлайн-матча (View, сборка).
///
/// За что отвечает файл:
///   Собирает онлайн-партию: адаптирует серверное состояние в [GameState] и
///   переиспустит игровые виджеты (BoardView/HandView/Scoreboard/TurnTimer),
///   отправляет ходы в [OnlineGameNotifier], играет звук/конфетти по диффу и
///   показывает оверлеи (соперник ушёл, переподключение, конец матча с
///   ремачом). Игровой логики нет — она на сервере; здесь только View+команды.
///
/// Соответствие TS: `screens/OnlineGame.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../achievements/achievement.dart';
import '../../../achievements/achievements_controller.dart';
import '../../../achievements/engine.dart';
import '../../../achievements/stats_controller.dart';
import '../../../audio/audio_service.dart';
import '../../../audio/sfx.dart';
import '../../../online/online_game_notifier.dart';
import '../../../online/online_match_state.dart';
import '../../../online/online_models.dart';
import '../../../online/online_to_game_state.dart';
import '../../../profile/profile_controller.dart';
import '../../../settings/settings_controller.dart';
import '../../../shop/skins.dart';
import '../../../shop/skins_controller.dart';
import '../../decor/toast_stack.dart';
import '../../design_tokens.dart';
import '../../game/confetti_overlay.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/board_view.dart';
import '../../widgets/hand_view.dart';
import '../../widgets/scoreboard.dart';
import '../../widgets/turn_timer.dart';
import 'online_overlays.dart';

/// Экран живого онлайн-матча.
class OnlineGameScreen extends ConsumerStatefulWidget {
  /// Id игровой комнаты.
  final String roomId;

  /// Свой профиль (для `hello`).
  final OnlineProfile me;

  /// Профиль соперника (для отображения до `joined`).
  final OnlineProfile opponent;

  /// Токен слота из `matched` (SEC-2) — для аутентификации в `hello`.
  final String? token;

  /// Создаёт экран.
  const OnlineGameScreen({
    super.key,
    required this.roomId,
    required this.me,
    required this.opponent,
    this.token,
  });

  @override
  ConsumerState<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends ConsumerState<OnlineGameScreen> {
  late final OnlineMatchArgs _args = OnlineMatchArgs(
    roomId: widget.roomId,
    me: widget.me,
    token: widget.token,
  );
  final ConfettiGame _confetti = ConfettiGame();

  /// id матча, по которому уже записан результат — защита от двойной записи;
  /// при ремаче приходит новый matchId, поэтому результат запишется снова.
  String? _recordedMatchId;

  /// Тосты о вновь разблокированных PvP-ачивках.
  final List<AchievementDef> _toasts = [];

  /// Сегодняшняя дата `YYYY-MM-DD` (клиентская) — для серии «дней подряд».
  String _today() {
    final d = DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Звук/эффекты по диффу состояния матча.
  void _reactToDiff(OnlineMatchState? prev, OnlineMatchState next) {
    final audio = ref.read(audioServiceProvider);
    final reduceMotion = ref.read(settingsControllerProvider).reduceMotion;

    // Ход совершён (любым игроком): звук + конфетти на perfect.
    if (prev != null && next.moveSeq > prev.moveSeq) {
      final cleared = next.game?.lastClearedCells ?? const [];
      if (next.lastPerfect) {
        audio.play(Sfx.perfect);
        if (!reduceMotion) {
          final t = Theme.of(context).extension<BlockDuelTheme>()!;
          _confetti.burst([t.p0, t.p1, t.good]);
        }
      } else if (cleared.isNotEmpty) {
        audio.playClear((cleared.length / 9).round().clamp(1, 8));
      } else {
        audio.play(Sfx.place);
      }
    }

    // Конец матча: звук исхода + запись результата (один раз на matchId).
    final justOver =
        (prev?.game?.isOver != true) && (next.game?.isOver == true);
    if (justOver) {
      final game = next.game!;
      final result = game.result;
      final winner = result?.winner ?? -1;
      final draw = winner < 0;
      audio.play(draw ? Sfx.draw : (winner == next.you ? Sfx.win : Sfx.lose));
      if (_recordedMatchId != game.matchId) {
        _recordedMatchId = game.matchId;
        _recordMatch(next);
      }
    }
  }

  /// Записывает итог онлайн-матча: профильные W/L/D, накопительную статистику и
  /// прогон движка PvP-ачивок (вновь разблокированные → тосты).
  void _recordMatch(OnlineMatchState s) {
    final game = s.game!;
    final result = game.result;
    final winner = result?.winner ?? -1;
    final won = winner == s.you;
    final drew = winner < 0;
    final you = s.you;
    final opIndex = 1 - you;

    final scores = result?.scores ?? const [0, 0];
    final myScore = you < scores.length ? scores[you] : 0;
    final opScore = opIndex < scores.length ? scores[opIndex] : 0;
    final scoreGap = myScore - opScore;
    final opId = opIndex < game.players.length
        ? game.players[opIndex].id
        : 'unknown';
    final themeId = ref.read(themeControllerProvider).name;

    // Профильные счётчики (как раньше).
    ref
        .read(profileControllerProvider.notifier)
        .recordOnlineResult(outcome: drew ? 0 : (won ? 1 : -1));

    // Накопительная статистика → снимок ПОСЛЕ матча.
    final stats = ref
        .read(statsControllerProvider.notifier)
        .recordOnline(
          won: won,
          drew: drew,
          matchClears: s.matchClears,
          perfects: s.matchPerfects,
          maxMultiClear: s.matchMaxMulti,
          bestCombo: s.matchBestCombo,
          turnCount: game.turnCount,
          themeId: themeId,
          opponentId: opId,
          today: _today(),
        );

    // PvP-ачивки. myElo пока неизвестен (ELO живёт в отдельном leaderboard-WS),
    // поэтому ELO-ачивки (on_e_*/on_top) ждут пробрасывания рейтинга.
    final fresh = ref
        .read(achievementsControllerProvider.notifier)
        .recordOnlineMatch(
          stats,
          OnlineMatchInfo(
            won: won,
            drew: drew,
            scoreGap: scoreGap,
            opponentScore: opScore,
            turnCount: game.turnCount,
            maxMultiClear: s.matchMaxMulti,
            bestCombo: s.matchBestCombo,
            themeId: themeId,
            opponentId: opId,
            reason: result?.reason,
          ),
        );
    if (fresh.isNotEmpty && mounted) {
      setState(() => _toasts.addAll(fresh));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    ref.listen(onlineGameProvider(_args), _reactToDiff);

    final match = ref.watch(onlineGameProvider(_args));
    final vm = ref.read(onlineGameProvider(_args).notifier);
    final game = match.game;

    if (game == null) {
      return Scaffold(
        backgroundColor: theme.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.p0),
              const SizedBox(height: 16),
              Text(
                'Подключение к матчу…',
                style: TextStyle(color: theme.muted, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final gs = onlineToGameState(game, you: match.you).copyWith(
      selectedPieceId: match.selectedPieceId,
      orientIndex: match.orientIndex,
    );
    final myTurn = match.connected && !game.isOver && game.current == match.you;
    final canRotate =
        gs.selectedPiece != null &&
        (game.cfg.rotationEnabled || game.cfg.flipEnabled);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyR) {
          vm.rotateSelected();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: theme.bg,
        body: Stack(
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TopBar(
                            theme: theme,
                            onMenu: () => context.go('/online'),
                            onResign: game.isOver ? null : vm.resign,
                            reconnecting: !match.connected && !game.isOver,
                          ),
                          const SizedBox(height: 10),
                          Scoreboard(state: gs, theme: theme),
                          if (myTurn) ...[
                            const SizedBox(height: 10),
                            TurnTimer(state: gs, theme: theme),
                          ],
                          const SizedBox(height: 12),
                          BoardView(
                            state: gs,
                            theme: theme,
                            onPlace: vm.placeAt,
                            skin: skinStyleOf(
                              ref.watch(skinsControllerProvider).equipped,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _Controls(
                            theme: theme,
                            myTurn: myTurn,
                            canRotate: canRotate,
                            hasSelection: gs.selectedPiece != null,
                            onRotate: vm.rotateSelected,
                            onDeselect: vm.deselect,
                          ),
                          const SizedBox(height: 10),
                          HandView(
                            hand: gs.currentPlayer.hand,
                            selectedId: gs.selectedPieceId,
                            selectedCells: gs.activeCells,
                            interactive: myTurn,
                            owner: game.current,
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
            Positioned.fill(child: ConfettiOverlay(game: _confetti)),
            if (match.opponentLeft && !game.isOver)
              OpponentLeftBanner(
                theme: theme,
                timeoutMs: match.opponentTimeoutMs,
              ),
            if (game.isOver && game.result != null)
              OnlineGameOverOverlay(
                theme: theme,
                themeId: ref.watch(themeControllerProvider),
                result: game.result!,
                you: match.you,
                rematchYours: match.rematchYours,
                rematchTheirs: match.rematchTheirs,
                onToggleRematch: () => match.rematchYours
                    ? vm.cancelRematch()
                    : vm.requestRematch(),
                onMenu: () => context.go('/online'),
              ),
            // Тосты о вновь разблокированных PvP-ачивках (поверх всего).
            ToastStack(
              toasts: _toasts,
              theme: theme,
              onDismiss: (id) =>
                  setState(() => _toasts.removeWhere((a) => a.id == id)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Верхняя панель: меню, статус соперника/переподключения, сдаться.
class _TopBar extends StatelessWidget {
  final BlockDuelTheme theme;
  final VoidCallback onMenu;
  final VoidCallback? onResign;
  final bool reconnecting;

  const _TopBar({
    required this.theme,
    required this.onMenu,
    required this.onResign,
    required this.reconnecting,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(theme: theme, label: '← меню', onTap: onMenu),
        const Spacer(),
        if (reconnecting)
          Text(
            'переподключение…',
            style: TextStyle(color: theme.muted, fontSize: 12),
          ),
        if (onResign != null) ...[
          const SizedBox(width: 8),
          _Chip(theme: theme, label: '🏳 сдаться', onTap: onResign!),
        ],
      ],
    );
  }
}

/// Контролы трансформации выбранной фигуры (поворот/снять выбор).
class _Controls extends StatelessWidget {
  final BlockDuelTheme theme;
  final bool myTurn;
  final bool canRotate;
  final bool hasSelection;
  final VoidCallback onRotate;
  final VoidCallback onDeselect;

  const _Controls({
    required this.theme,
    required this.myTurn,
    required this.canRotate,
    required this.hasSelection,
    required this.onRotate,
    required this.onDeselect,
  });

  @override
  Widget build(BuildContext context) {
    if (!myTurn) {
      return SizedBox(
        height: 38,
        child: Center(
          child: Text(
            'Ход соперника…',
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
        _Chip(
          theme: theme,
          label: '↻ повернуть',
          onTap: canRotate ? onRotate : null,
        ),
        const SizedBox(width: 10),
        _Chip(theme: theme, label: '✕ снять', onTap: onDeselect),
      ],
    );
  }
}

/// Маленькая кнопка-чип.
class _Chip extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final VoidCallback? onTap;

  const _Chip({required this.theme, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: theme.panel,
      borderRadius: BorderRadius.circular(theme.btnRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.btnRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.btnRadius),
            border: Border.all(color: theme.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? theme.ink : theme.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
