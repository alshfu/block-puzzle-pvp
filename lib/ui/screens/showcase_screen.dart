/// showcase_screen.dart — режим «Авто-шоу» (View): пилот авто-играет vs бот.
///
/// За что отвечает файл:
///   Самоиграющаяся витрина для YouTube Shorts: ИИ против ИИ (botvbot) в
///   вертикальном формате 9:16 с «эфирной» шапкой, авто-перезапуском партий и
///   кнопкой «В эфир». Партию ведёт существующий `GameNotifier` (botvbot сам
///   ходит за обоих); по окончании — пауза и новая партия с новым seed.
///   Кнопка «В эфир» запускает браузерный захват/запись клипа ([Broadcaster]);
///   прямой RTMP-эфир на YouTube требует серверного релея (🔒).
///
/// Соответствие ROADMAP: дополнительный showcase-режим (вне § 1–11; промо).
library;

import 'dart:async';

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../game/game_notifier.dart';
import '../../game/match_config.dart';
import '../../showcase/broadcast.dart';
import '../decor/theme_backdrop.dart';
import '../design_tokens.dart';
import '../widgets/board_view.dart';
import '../widgets/scoreboard.dart';

/// Экран режима «Авто-шоу».
class ShowcaseScreen extends ConsumerStatefulWidget {
  /// Создаёт экран.
  const ShowcaseScreen({super.key});

  @override
  ConsumerState<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends ConsumerState<ShowcaseScreen> {
  final Broadcaster _broadcaster = Broadcaster();
  late int _seed;
  late MatchConfig _config;
  Timer? _restart;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    _config = _makeConfig(_seed);
  }

  MatchConfig _makeConfig(int seed) => MatchConfig(
    mode: MatchMode.botvbot,
    seed: seed,
    botLevel: BotLevel.hard,
  );

  @override
  void dispose() {
    _restart?.cancel();
    _broadcaster.dispose();
    super.dispose();
  }

  /// Планирует новую партию (новый seed) после паузы на показ результата.
  void _scheduleRestart() {
    if (_restart != null) return;
    _restart = Timer(const Duration(seconds: 4), () {
      final old = _config;
      setState(() {
        _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
        _config = _makeConfig(_seed);
        _restart = null;
      });
      ref.invalidate(gameProvider(old));
    });
  }

  /// Кнопка «В эфир»: запускает/останавливает запись или объясняет live-эфир.
  Future<void> _toggleBroadcast() async {
    if (!_broadcaster.supported) {
      _showLiveInfo();
      return;
    }
    if (_recording) {
      _broadcaster.stop();
      setState(() => _recording = false);
      _snack('Клип сохранён. Загрузите его как YouTube Shorts.');
      return;
    }
    final ok = await _broadcaster.startRecording();
    if (!mounted) return;
    setState(() => _recording = ok);
    _snack(
      ok
          ? 'Запись началась — выберите вкладку с Авто-шоу.'
          : 'Доступ к захвату не получен.',
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
    );
  }

  /// Поясняет, что прямой live-эфир требует серверного релея.
  void _showLiveInfo() {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.panel,
        title: Text('Прямой эфир на YouTube', style: TextStyle(color: tokens.ink)),
        content: Text(
          'Прямая RTMP-трансляция из браузера невозможна без серверного '
          'медиа-релея + YouTube Live API. Это серверная часть (в работе вместе '
          'с онлайн-сервером). Пока доступна запись вертикального клипа для '
          'Shorts — на десктоп-браузере.',
          style: TextStyle(color: tokens.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text('Понятно', style: TextStyle(color: tokens.p0)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    final state = ref.watch(gameProvider(_config));

    // Авто-перезапуск партии по окончании.
    ref.listen(gameProvider(_config), (prev, next) {
      if (next.gameOver && (prev == null || !prev.gameOver)) {
        _scheduleRestart();
      }
    });

    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          const ThemeBackdrop(),
          SafeArea(
            child: Center(
              // Вертикальный кадр 9:16 (формат Shorts).
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        tokens.panel,
                        Color.lerp(tokens.panel, tokens.bg, 0.6)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(tokens.cardRadius),
                    border: Border.all(color: tokens.line),
                  ),
                  child: Column(
                    children: [
                      _LiveHeader(tokens: tokens, recording: _recording),
                      const SizedBox(height: 10),
                      Scoreboard(state: state, theme: tokens, solo: false),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: BoardView(
                            state: state,
                            theme: tokens,
                            onPlace: (_, _) {},
                            showGhost: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        state.gameOver
                            ? (state.winner == null
                                  ? '🤝 Ничья — новая партия…'
                                  : '🏆 Победил Игрок ${state.winner! + 1} — новая партия…')
                            : 'BlockDuel 9×9 · ИИ против ИИ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Верхняя панель: назад.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () => context.go('/'),
                icon: Icon(Icons.arrow_back, color: tokens.ink),
              ),
            ),
          ),
          // Кнопка «В эфир».
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FilledButton.icon(
                  onPressed: _toggleBroadcast,
                  style: FilledButton.styleFrom(
                    backgroundColor: _recording ? tokens.bad : tokens.p0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 13,
                    ),
                  ),
                  icon: Icon(
                    _recording ? Icons.stop_rounded : Icons.videocam_rounded,
                  ),
                  label: Text(_recording ? 'Стоп · сохранить' : 'В эфир'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Эфирная» шапка: пульсирующий индикатор LIVE/REC + название.
class _LiveHeader extends StatefulWidget {
  final BlockDuelTheme tokens;
  final bool recording;

  const _LiveHeader({required this.tokens, required this.recording});

  @override
  State<_LiveHeader> createState() => _LiveHeaderState();
}

class _LiveHeaderState extends State<_LiveHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final label = widget.recording ? 'REC' : 'LIVE';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(
          opacity: _pulse,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: t.bad,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: t.bad.withValues(alpha: 0.7), blurRadius: 8),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: t.bad,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '🟦 BlockDuel',
          style: TextStyle(
            color: t.ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: t.fontDisplay,
          ),
        ),
      ],
    );
  }
}
