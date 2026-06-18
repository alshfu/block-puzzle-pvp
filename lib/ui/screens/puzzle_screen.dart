/// puzzle_screen.dart — экран режима «Силуэты» (View): выбор + прохождение.
///
/// За что отвечает файл:
///   Две фазы в одном экране: СПИСОК уровней (по сложности, с отметкой «решено»
///   и рекордом) и ПРОХОЖДЕНИЕ выбранного уровня (поле-силуэт, рука фигур,
///   управление: поворот/отмена/рестарт/подсказка, клавиатура для web/desktop,
///   таймер speedrun, оверлей победы). На решении начисляет монеты за ПЕРВОЕ
///   прохождение и пишет рекорд счёта/времени (репозиторий `PuzzleStore`).
///   Игровой логики нет — всё делегируется в [PuzzleNotifier].
///
/// Управление (web/desktop): 1–9 — выбрать фигуру, R — поворот, U — отмена,
///   H — подсказка, Esc — снять выбор/назад.
///
/// Соответствие ROADMAP: § 9.1/§ 9.4 (режим, прогрессия, рекорды).
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../audio/audio_service.dart';
import '../../audio/sfx.dart';
import '../../modes/puzzle/puzzle_core.dart';
import '../../modes/puzzle/puzzle_notifier.dart';
import '../../modes/puzzle/puzzle_pack.dart';
import '../../modes/puzzle/puzzle_pieces.dart';
import '../../modes/puzzle/puzzle_state.dart';
import '../../modes/puzzle/puzzle_store.dart';
import '../../profile/profile_controller.dart';
import '../../settings/settings_controller.dart';
import '../decor/theme_backdrop.dart';
import '../design_tokens.dart';
import '../widgets/puzzle_board_view.dart';
import '../widgets/screen_scaffold.dart';

/// Порог ширины для раскладки «поле слева + рука справа».
const double _puzzleSideBySideWidth = 720;

/// Подписи сложностей.
const Map<PuzzleDifficulty, String> _difficultyLabel = {
  PuzzleDifficulty.easy: 'Лёгкие',
  PuzzleDifficulty.medium: 'Средние',
  PuzzleDifficulty.hard: 'Сложные',
  PuzzleDifficulty.expert: 'Эксперт',
};

/// Экран режима «Силуэты».
class PuzzleScreen extends ConsumerStatefulWidget {
  /// Создаёт экран.
  const PuzzleScreen({super.key});

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen>
    with SingleTickerProviderStateMixin {
  /// Идёт ли прохождение (иначе — список выбора).
  bool _playing = false;

  /// Тикер таймера speedrun.
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _accum = 0;

  /// Прошло секунд на текущем уровне.
  int _elapsed = 0;

  /// Учтено ли завершение текущего уровня (награды/рекорд — один раз).
  bool _solveHandled = false;

  /// Текущая подсказка (подсвеченные клетки) или пусто.
  List<Coord> _hint = const [];

  /// Узел фокуса для клавиатуры.
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    final st = ref.read(puzzleProvider);
    if (st.solved) return;
    _accum += dt;
    if (_accum >= 1.0) {
      _accum -= 1.0;
      setState(() => _elapsed += 1);
    }
  }

  /// Запускает прохождение уровня [def].
  void _start(PuzzleDef def) {
    ref.read(puzzleProvider.notifier).loadPuzzle(def);
    setState(() {
      _playing = true;
      _elapsed = 0;
      _accum = 0;
      _solveHandled = false;
      _hint = const [];
    });
    _last = Duration.zero;
    _ticker
      ..stop()
      ..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  /// Перезапуск текущего уровня.
  void _restart() {
    ref.read(puzzleProvider.notifier).restart();
    setState(() {
      _elapsed = 0;
      _accum = 0;
      _solveHandled = false;
      _hint = const [];
    });
  }

  /// Возврат к списку.
  void _toList() {
    _ticker.stop();
    setState(() => _playing = false);
  }

  /// Загрузка следующего уровня пака (по кругу).
  void _next() {
    final pack = puzzlePack;
    final idx = pack.indexWhere((p) => p.id == ref.read(puzzleProvider).def.id);
    _start(pack[(idx + 1) % pack.length]);
  }

  void _showHint() {
    final cells = ref.read(puzzleProvider.notifier).hint();
    setState(() => _hint = cells ?? const []);
  }

  /// Клавиатура (web/desktop).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final vm = ref.read(puzzleProvider.notifier);
    final st = ref.read(puzzleProvider);
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.keyR) {
      vm.rotate();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyU || k == LogicalKeyboardKey.backspace) {
      vm.undo();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyH) {
      _showHint();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      if (st.selectedInstanceId != null) {
        vm.deselect();
      } else {
        _toList();
      }
      return KeyEventResult.handled;
    }
    // 1..9 — выбор фигуры руки по номеру.
    final digits = {
      LogicalKeyboardKey.digit1: 0,
      LogicalKeyboardKey.digit2: 1,
      LogicalKeyboardKey.digit3: 2,
      LogicalKeyboardKey.digit4: 3,
      LogicalKeyboardKey.digit5: 4,
      LogicalKeyboardKey.digit6: 5,
      LogicalKeyboardKey.digit7: 6,
      LogicalKeyboardKey.digit8: 7,
      LogicalKeyboardKey.digit9: 8,
    };
    final idx = digits[k];
    if (idx != null) {
      if (idx < st.hand.length) vm.selectPiece(st.hand[idx].instanceId);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Реакция на решение: рекорд/монеты/звук — один раз.
  void _onState(PuzzleState? prev, PuzzleState next) {
    if (next.solved && !_solveHandled) {
      _solveHandled = true;
      _ticker.stop();
      final store = ref.read(puzzleStoreProvider);
      final first = store.recordSolved(next.def.id, next.score, _elapsed);
      ref.read(audioServiceProvider).play(Sfx.win);
      if (first) {
        ref
            .read(profileControllerProvider.notifier)
            .addCoins(puzzleCoinReward(next.def.difficulty));
      }
      setState(() => _hint = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    ref.listen(puzzleProvider, _onState);
    if (!_playing) return _buildPicker(theme);
    return _buildPlay(theme);
  }

  // ── Список уровней ───────────────────────────────────────────────────────────

  Widget _buildPicker(BlockDuelTheme theme) {
    final store = ref.watch(puzzleStoreProvider);
    final solved = store.solvedIds();
    return ScreenScaffold(
      title: 'Силуэты',
      theme: theme,
      onBack: () => context.go('/'),
      children: [
        Text(
          'Собери силуэт из выданных фигур. Ставить можно только внутри контура.',
          style: TextStyle(color: theme.muted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(
          'Решено: ${solved.length} / ${puzzlePack.length}',
          style: TextStyle(color: theme.ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final diff in PuzzleDifficulty.values)
          if (puzzlesByDifficulty(diff).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                _difficultyLabel[diff]!,
                style: TextStyle(
                  color: theme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final def in puzzlesByDifficulty(diff))
                  _PuzzleCard(
                    theme: theme,
                    def: def,
                    solved: solved.contains(def.id),
                    bestScore: store.bestScore(def.id),
                    bestTime: store.bestTimeSeconds(def.id),
                    onTap: () => _start(def),
                  ),
              ],
            ),
          ],
      ],
    );
  }

  // ── Прохождение ──────────────────────────────────────────────────────────────

  Widget _buildPlay(BlockDuelTheme theme) {
    final state = ref.watch(puzzleProvider);
    final ghost =
        ref.watch(settingsControllerProvider.select((s) => s.ghostEnabled));
    final vm = ref.read(puzzleProvider.notifier);

    final board = PuzzleBoardView(
      state: state,
      theme: theme,
      onPlace: (r, c) {
        setState(() => _hint = const []);
        vm.placeAt(r, c);
      },
      showGhost: ghost,
      hintCells: _hint,
    );
    final side = _SidePanel(
      theme: theme,
      state: state,
      elapsed: _elapsed,
      onSelect: vm.selectPiece,
      onRotate: vm.rotate,
      onUndo: vm.undo,
      onReset: _restart,
      onHint: _showHint,
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
                  _PlayTopBar(
                    theme: theme,
                    title: state.def.name,
                    moves: state.movesUsed,
                    budget: puzzleMoveBudget(state.def),
                    elapsed: _elapsed,
                    onBack: _toList,
                    onRestart: _restart,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide =
                            constraints.maxWidth >= _puzzleSideBySideWidth;
                        final content = wide
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        flex: 5,
                                        child: Center(child: board)),
                                    const SizedBox(width: 16),
                                    Expanded(
                                        flex: 4,
                                        child: SingleChildScrollView(
                                            child: side)),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                child: Column(
                                  children: [
                                    Center(child: board),
                                    const SizedBox(height: 12),
                                    side,
                                  ],
                                ),
                              );
                        return Stack(
                          children: [
                            content,
                            if (state.solved)
                              _WinOverlay(
                                theme: theme,
                                score: state.score,
                                elapsed: _elapsed,
                                onNext: _next,
                                onList: _toList,
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

/// Карточка уровня в списке выбора.
class _PuzzleCard extends StatelessWidget {
  final BlockDuelTheme theme;
  final PuzzleDef def;
  final bool solved;
  final int bestScore;
  final int bestTime;
  final VoidCallback onTap;

  const _PuzzleCard({
    required this.theme,
    required this.def,
    required this.solved,
    required this.bestScore,
    required this.bestTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Material(
        color: theme.panel,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(theme.cardRadius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.cardRadius),
              border: Border.all(
                color: solved ? theme.good : theme.line,
                width: solved ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        def.name,
                        style: TextStyle(
                          color: theme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (solved)
                      Icon(Icons.check_circle, color: theme.good, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${def.pieceCount} фигур',
                  style: TextStyle(color: theme.muted, fontSize: 11),
                ),
                if (solved && bestScore > 0)
                  Text(
                    'рекорд: $bestScore'
                    '${bestTime > 0 ? ' · ${_fmt(bestTime)}' : ''}',
                    style: TextStyle(color: theme.muted, fontSize: 11),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Боковая/нижняя панель прохождения: рука + управление + таймер.
class _SidePanel extends StatelessWidget {
  final BlockDuelTheme theme;
  final PuzzleState state;
  final int elapsed;
  final ValueChanged<String> onSelect;
  final VoidCallback onRotate;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onHint;

  const _SidePanel({
    required this.theme,
    required this.state,
    required this.elapsed,
    required this.onSelect,
    required this.onRotate,
    required this.onUndo,
    required this.onReset,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Фигуры (${state.hand.length})',
            style: TextStyle(
              color: theme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in state.hand)
                _HandChip(
                  theme: theme,
                  piece: p,
                  selected: p.instanceId == state.selectedInstanceId,
                  onTap: () => onSelect(p.instanceId),
                ),
              if (state.hand.isEmpty)
                Text('— рука пуста —',
                    style: TextStyle(color: theme.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ActBtn(theme: theme, icon: Icons.rotate_right, label: 'Поворот', onTap: onRotate),
              const SizedBox(width: 8),
              _ActBtn(theme: theme, icon: Icons.undo, label: 'Отмена', onTap: onUndo),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ActBtn(theme: theme, icon: Icons.lightbulb_outline, label: 'Подсказка', onTap: onHint),
              const SizedBox(width: 8),
              _ActBtn(theme: theme, icon: Icons.refresh, label: 'Заново', onTap: onReset),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Клавиши: 1–9 выбрать · R поворот · U отмена · H подсказка · Esc назад',
            style: TextStyle(color: theme.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Чип фигуры в руке (мини-рендер в цвете + выделение).
class _HandChip extends StatelessWidget {
  final BlockDuelTheme theme;
  final HandPiece piece;
  final bool selected;
  final VoidCallback onTap;

  const _HandChip({
    required this.theme,
    required this.piece,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(theme.btnRadius),
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.bg2,
          borderRadius: BorderRadius.circular(theme.btnRadius),
          border: Border.all(
            color: selected ? theme.p0 : theme.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: CustomPaint(
          size: const Size(40, 40),
          painter: _MiniShapePainter(
            cells: puzzleBaseShapes[piece.shapeId]!,
            color: puzzlePalette[piece.color % puzzlePalette.length],
          ),
        ),
      ),
    );
  }
}

/// Рисует мини-полимино, вписывая его в доступный квадрат.
class _MiniShapePainter extends CustomPainter {
  final List<Coord> cells;
  final Color color;

  const _MiniShapePainter({required this.cells, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var maxR = 0;
    var maxC = 0;
    for (final c in cells) {
      if (c.r > maxR) maxR = c.r;
      if (c.c > maxC) maxC = c.c;
    }
    final cols = maxC + 1;
    final rows = maxR + 1;
    final cell = (size.width / cols).clamp(0.0, size.height / rows);
    final offX = (size.width - cell * cols) / 2;
    final offY = (size.height - cell * rows) / 2;
    final paint = Paint()..color = color;
    final edge = Paint()
      ..color = Color.lerp(color, const Color(0xFF000000), 0.35)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final c in cells) {
      final rect = Rect.fromLTWH(
        offX + c.c * cell + 1,
        offY + c.r * cell + 1,
        cell - 2,
        cell - 2,
      );
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(2));
      canvas.drawRRect(rr, paint);
      canvas.drawRRect(rr, edge);
    }
  }

  @override
  bool shouldRepaint(_MiniShapePainter old) => old.color != color;
}

/// Кнопка действия панели.
class _ActBtn extends StatelessWidget {
  final BlockDuelTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActBtn({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.ink,
          side: BorderSide(color: theme.line),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.btnRadius),
          ),
        ),
      ),
    );
  }
}

/// Верхняя панель прохождения.
class _PlayTopBar extends StatelessWidget {
  final BlockDuelTheme theme;
  final String title;
  final int moves;
  final int budget;
  final int elapsed;
  final VoidCallback onBack;
  final VoidCallback onRestart;

  const _PlayTopBar({
    required this.theme,
    required this.title,
    required this.moves,
    required this.budget,
    required this.elapsed,
    required this.onBack,
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
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: theme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: theme.fontDisplay,
              ),
            ),
          ),
          Text(
            '⏱ ${_fmt(elapsed)}   ходы $moves/$budget',
            style: TextStyle(color: theme.muted, fontSize: 12),
          ),
          IconButton(
            tooltip: 'Заново',
            onPressed: onRestart,
            icon: Icon(Icons.refresh, color: theme.ink),
          ),
        ],
      ),
    );
  }
}

/// Оверлей победы.
class _WinOverlay extends StatelessWidget {
  final BlockDuelTheme theme;
  final int score;
  final int elapsed;
  final VoidCallback onNext;
  final VoidCallback onList;

  const _WinOverlay({
    required this.theme,
    required this.score,
    required this.elapsed,
    required this.onNext,
    required this.onList,
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
                'Силуэт собран! 🎉',
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  fontFamily: theme.fontDisplay,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Счёт: $score   ·   Время: ${_fmt(elapsed)}',
                style: TextStyle(color: theme.muted, fontSize: 16),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: onList,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.ink,
                      side: BorderSide(color: theme.line),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    child: const Text('К списку'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.p0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                    child: const Text('Следующий'),
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

/// Формат времени `m:ss`.
String _fmt(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
