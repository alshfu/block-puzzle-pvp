/// tetris_screen.dart — экран «Классического Tetris» (View).
///
/// За что отвечает файл:
///   Живой экран падающего Tetris: ведёт гравитацию через [Ticker] (темп —
///   `tetrisGravitySeconds`, ядро без таймеров), принимает классическое
///   управление с клавиатуры (стрелки/Space/Z-X/C/P) для web/desktop и
///   дублирует его экранными кнопками для тача. Показывает HUD (счёт/уровень/
///   линии, очередь NEXT, ячейку HOLD), адаптивную раскладку (поле слева +
///   панель справа на широких экранах) и оверлеи паузы/конца партии. Логики
///   игры здесь нет — всё делегируется в [TetrisNotifier]; экран лишь рисует
///   состояние и шлёт команды.
///
/// Управление (web/desktop):
///   ← → — сдвиг, ↓ — soft drop, ↑/X — поворот CW, Z/Ctrl — поворот CCW,
///   Space — hard drop, C/Shift — hold, P — пауза, Esc — пауза/назад,
///   Enter — рестарт на экране конца партии.
///
/// Соответствие ROADMAP: Фаза 5 (режим «Tetris»); § 8.5 (зеркальный набор).
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../audio/audio_service.dart';
import '../../audio/sfx.dart';
import '../../modes/tetris/tetris_core.dart';
import '../../modes/tetris/tetris_notifier.dart';
import '../../modes/tetris/tetris_state.dart';
import '../../settings/settings_controller.dart';
import '../../storage/prefs.dart';
import '../decor/theme_backdrop.dart';
import '../design_tokens.dart';
import '../widgets/tetris_board_view.dart';

/// Порог ширины для раскладки «поле слева + панель справа».
const double _tetrisSideBySideWidth = 720;

/// Ключ хранения рекорда Tetris (SharedPreferences).
const String _tetrisBestKey = 'bd_tetris_best';

/// Экран живого Tetris.
class TetrisScreen extends ConsumerStatefulWidget {
  /// Создаёт экран.
  const TetrisScreen({super.key});

  @override
  ConsumerState<TetrisScreen> createState() => _TetrisScreenState();
}

class _TetrisScreenState extends ConsumerState<TetrisScreen>
    with SingleTickerProviderStateMixin {
  /// Тикер гравитации (delta-время → `notifier.tick`).
  late final Ticker _ticker;

  /// Прошлое значение elapsed (для расчёта delta).
  Duration _last = Duration.zero;

  /// Узел фокуса для клавиатуры (web/desktop).
  final FocusNode _focus = FocusNode();

  /// Текущий рекорд (для HUD и сохранения).
  int _best = 0;

  /// Был ли уже учтён конец текущей партии (чтобы не писать рекорд дважды).
  bool _endHandled = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _best = prefs.getInt(_tetrisBestKey) ?? 0;
    _ticker = createTicker(_onTick);
    // Старт партии и тикера — после первого кадра (модификация провайдера вне
    // build, фокус на готовом дереве).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restart();
      _ticker.start();
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Шаг тикера: считает delta и передаёт в ViewModel.
  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    ref.read(tetrisProvider.notifier).tick(dt);
  }

  /// Запускает новую партию (seed — из времени, ядро остаётся детерминированным;
  /// зеркальный набор — если включён в настройках и разблокирован 100-м ур.).
  void _restart() {
    final seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    ref.read(tetrisProvider.notifier).newGame(seed, mirror: _mirrorActive());
    _endHandled = false;
  }

  /// Активен ли зеркальный набор: включён в настройках. (Видимость тумблера в
  /// настройках гейтится разблокировкой 100-го уровня.)
  bool _mirrorActive() =>
      ref.read(settingsControllerProvider).mirrorPiecesEnabled;

  /// Обработка клавиатуры (web/desktop). Движение/soft drop принимают и
  /// авто-повтор (KeyRepeatEvent — DAS), остальное — только нажатие.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final isDown = event is KeyDownEvent;
    final isRepeat = event is KeyRepeatEvent;
    if (!isDown && !isRepeat) return KeyEventResult.ignored;
    final vm = ref.read(tetrisProvider.notifier);
    final k = event.logicalKey;

    // Конец партии: Enter/Space — рестарт.
    if (ref.read(tetrisProvider).gameOver) {
      if (isDown &&
          (k == LogicalKeyboardKey.enter ||
              k == LogicalKeyboardKey.space ||
              k == LogicalKeyboardKey.numpadEnter)) {
        _restart();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Движение и soft drop — с авто-повтором.
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      vm.move(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) {
      vm.move(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) {
      vm.softDrop();
      return KeyEventResult.handled;
    }
    // Остальное — только на нажатии (без авто-повтора).
    if (!isDown) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyX ||
        k == LogicalKeyboardKey.keyW) {
      vm.rotate(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyZ ||
        k == LogicalKeyboardKey.controlLeft ||
        k == LogicalKeyboardKey.controlRight) {
      vm.rotate(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.space) {
      vm.hardDrop();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyC ||
        k == LogicalKeyboardKey.shiftLeft ||
        k == LogicalKeyboardKey.shiftRight) {
      vm.hold();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyP || k == LogicalKeyboardKey.escape) {
      vm.togglePause();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Звук на новом lock'е/очистке + рекорд при завершении.
  void _onStateChange(TetrisState? prev, TetrisState next) {
    final audio = ref.read(audioServiceProvider);
    if (prev != null && next.moveSeq > prev.moveSeq) {
      if (next.lastClearCount > 0) {
        audio.playClear(next.lastClearCount);
      } else {
        audio.play(Sfx.place);
      }
    }
    if (next.gameOver && !_endHandled) {
      _endHandled = true;
      audio.play(Sfx.lose);
      if (next.score > _best) {
        _best = next.score;
        ref.read(sharedPreferencesProvider).setInt(_tetrisBestKey, _best);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    ref.listen(tetrisProvider, _onStateChange);
    final state = ref.watch(tetrisProvider);
    final ghost = ref.watch(
      settingsControllerProvider.select((s) => s.ghostEnabled),
    );

    final board = TetrisBoardView(state: state, theme: theme, showGhost: ghost);
    final hud = _Hud(state: state, theme: theme, best: _best);
    final controls = _TouchControls(
      theme: theme,
      onLeft: () => ref.read(tetrisProvider.notifier).move(-1),
      onRight: () => ref.read(tetrisProvider.notifier).move(1),
      onDown: () => ref.read(tetrisProvider.notifier).softDrop(),
      onRotate: () => ref.read(tetrisProvider.notifier).rotate(1),
      onDrop: () => ref.read(tetrisProvider.notifier).hardDrop(),
      onHold: () => ref.read(tetrisProvider.notifier).hold(),
    );

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: theme.bg,
        body: Stack(
          children: [
            const ThemeBackdrop(),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    theme: theme,
                    paused: state.isPaused,
                    onBack: () => context.go('/'),
                    onPause: () =>
                        ref.read(tetrisProvider.notifier).togglePause(),
                    onRestart: _restart,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide =
                            constraints.maxWidth >= _tetrisSideBySideWidth;
                        final content = wide
                            ? _WideLayout(board: board, hud: hud, controls: controls)
                            : _NarrowLayout(
                                board: board, hud: hud, controls: controls);
                        return Stack(
                          children: [
                            content,
                            if (state.isPaused)
                              _Overlay(
                                theme: theme,
                                title: 'Пауза',
                                buttonLabel: 'Продолжить',
                                onButton: () => ref
                                    .read(tetrisProvider.notifier)
                                    .togglePause(),
                              ),
                            if (state.gameOver)
                              _Overlay(
                                theme: theme,
                                title: 'Игра окончена',
                                subtitle:
                                    'Счёт: ${state.score}   ·   Линии: ${state.lines}',
                                buttonLabel: 'Ещё раз',
                                onButton: _restart,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Верхняя панель: назад, заголовок, пауза, рестарт.
class _TopBar extends StatelessWidget {
  final BlockDuelTheme theme;
  final bool paused;
  final VoidCallback onBack;
  final VoidCallback onPause;
  final VoidCallback onRestart;

  const _TopBar({
    required this.theme,
    required this.paused,
    required this.onBack,
    required this.onPause,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back, color: theme.ink),
          ),
          Text(
            '🧱 Tetris',
            style: TextStyle(
              color: theme.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: theme.fontDisplay,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Пауза (P)',
            onPressed: onPause,
            icon: Icon(paused ? Icons.play_arrow : Icons.pause, color: theme.ink),
          ),
          IconButton(
            tooltip: 'Новая игра',
            onPressed: onRestart,
            icon: Icon(Icons.refresh, color: theme.ink),
          ),
        ],
      ),
    );
  }
}

/// Широкая раскладка: поле слева, HUD + управление справа.
class _WideLayout extends StatelessWidget {
  final Widget board;
  final Widget hud;
  final Widget controls;

  const _WideLayout({
    required this.board,
    required this.hud,
    required this.controls,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: Center(child: board)),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: Column(
                children: [hud, const SizedBox(height: 16), controls],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Узкая раскладка: HUD сверху, поле в центре, управление снизу.
class _NarrowLayout extends StatelessWidget {
  final Widget board;
  final Widget hud;
  final Widget controls;

  const _NarrowLayout({
    required this.board,
    required this.hud,
    required this.controls,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          hud,
          const SizedBox(height: 8),
          Expanded(child: Center(child: board)),
          const SizedBox(height: 8),
          controls,
        ],
      ),
    );
  }
}

/// HUD: счёт/уровень/линии, очередь NEXT, ячейка HOLD.
class _Hud extends StatelessWidget {
  final TetrisState state;
  final BlockDuelTheme theme;
  final int best;

  const _Hud({required this.state, required this.theme, required this.best});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Stat(theme: theme, label: 'Счёт', value: '${state.score}'),
              _Stat(theme: theme, label: 'Линии', value: '${state.lines}'),
              _Stat(theme: theme, label: 'Уровень', value: '${state.level}'),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Рекорд: $best',
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PieceBox(
                theme: theme,
                label: 'HOLD',
                type: state.hold,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT',
                      style: TextStyle(
                        color: theme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        for (final t in state.queue.take(4))
                          _MiniTetromino(type: t, cell: 9),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Одна метрика HUD (заголовок + значение).
class _Stat extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final String value;

  const _Stat({required this.theme, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: theme.ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            fontFamily: theme.fontDisplay,
          ),
        ),
      ],
    );
  }
}

/// Рамка-«ячейка» для HOLD-фигуры.
class _PieceBox extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final PieceType? type;

  const _PieceBox({required this.theme, required this.label, this.type});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 58,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.bg2,
            borderRadius: BorderRadius.circular(theme.btnRadius),
            border: Border.all(color: theme.line),
          ),
          child: type == null
              ? const SizedBox.shrink()
              : _MiniTetromino(type: type!, cell: 9),
        ),
      ],
    );
  }
}

/// Мини-рендер тетромино в его классическом цвете (для NEXT/HOLD).
class _MiniTetromino extends StatelessWidget {
  final PieceType type;
  final double cell;

  const _MiniTetromino({required this.type, required this.cell});

  @override
  Widget build(BuildContext context) {
    final cells = tetrisCells(type, 0);
    var maxR = 0;
    var maxC = 0;
    for (final c in cells) {
      if (c.r > maxR) maxR = c.r;
      if (c.c > maxC) maxC = c.c;
    }
    return SizedBox(
      width: (maxC + 1) * cell,
      height: (maxR + 1) * cell,
      child: CustomPaint(
        painter: _MiniPainter(cells: cells, cell: cell, color: tetrisColorFor(type)),
      ),
    );
  }
}

/// Отрисовщик мини-тетромино.
class _MiniPainter extends CustomPainter {
  final List<Coord> cells;
  final double cell;
  final Color color;

  const _MiniPainter({
    required this.cells,
    required this.cell,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final edge = Paint()
      ..color = Color.lerp(color, const Color(0xFF000000), 0.35)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final c in cells) {
      final rect = Rect.fromLTWH(
        c.c * cell + 1,
        c.r * cell + 1,
        cell - 2,
        cell - 2,
      );
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(2));
      canvas.drawRRect(rr, paint);
      canvas.drawRRect(rr, edge);
    }
  }

  @override
  bool shouldRepaint(_MiniPainter old) =>
      old.color != color || old.cell != cell;
}

/// Экранные кнопки управления (тач): ◀ ▼ ▶ · поворот · сброс · hold.
class _TouchControls extends StatelessWidget {
  final BlockDuelTheme theme;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onDown;
  final VoidCallback onRotate;
  final VoidCallback onDrop;
  final VoidCallback onHold;

  const _TouchControls({
    required this.theme,
    required this.onLeft,
    required this.onRight,
    required this.onDown,
    required this.onRotate,
    required this.onDrop,
    required this.onHold,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _CtlButton(theme: theme, icon: Icons.chevron_left, onTap: onLeft),
            const SizedBox(width: 8),
            _CtlButton(theme: theme, icon: Icons.keyboard_arrow_down, onTap: onDown),
            const SizedBox(width: 8),
            _CtlButton(theme: theme, icon: Icons.chevron_right, onTap: onRight),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _CtlButton(theme: theme, icon: Icons.rotate_right, onTap: onRotate),
            const SizedBox(width: 8),
            _CtlButton(
              theme: theme,
              icon: Icons.vertical_align_bottom,
              onTap: onDrop,
              primary: true,
            ),
            const SizedBox(width: 8),
            _CtlButton(theme: theme, icon: Icons.swap_vert, onTap: onHold),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Клавиши: ← → двигать · ↓ ускорить · ↑/X повернуть · '
          'Space — сброс · C — hold · P — пауза',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.muted, fontSize: 11),
        ),
      ],
    );
  }
}

/// Кнопка управления.
class _CtlButton extends StatelessWidget {
  final BlockDuelTheme theme;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _CtlButton({
    required this.theme,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: primary ? theme.p0 : theme.panel,
        borderRadius: BorderRadius.circular(theme.btnRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(theme.btnRadius),
          onTap: onTap,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.btnRadius),
              border: Border.all(color: theme.line),
            ),
            child: Icon(icon, color: primary ? Colors.white : theme.ink, size: 26),
          ),
        ),
      ),
    );
  }
}

/// Полупрозрачный оверлей паузы/конца партии.
class _Overlay extends StatelessWidget {
  final BlockDuelTheme theme;
  final String title;
  final String? subtitle;
  final String buttonLabel;
  final VoidCallback onButton;

  const _Overlay({
    required this.theme,
    required this.title,
    this.subtitle,
    required this.buttonLabel,
    required this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: theme.bg.withValues(alpha: 0.82),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  fontFamily: theme.fontDisplay,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 10),
                Text(subtitle!, style: TextStyle(color: theme.muted, fontSize: 16)),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: onButton,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.p0,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                child: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
