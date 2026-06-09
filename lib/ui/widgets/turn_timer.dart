/// turn_timer.dart — индикатор blitz-таймера хода (View).
///
/// За что отвечает файл:
///   Показывает оставшееся время хода человека: полоса прогресса
///   (remaining/limit) и число секунд. Цвет — цвет текущего игрока, при
///   нехватке времени (≤ 3 c) переключается на «тревожный». Чистый View поверх
///   [GameState]; логики отсчёта нет (она в ViewModel).
///
/// Соответствие TS: `components/TurnTimer.tsx`.
library;

import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../design_tokens.dart';

/// Порог «тревожного» цвета таймера (секунды).
const double _alarmThreshold = 3;

/// Индикатор времени на текущий ход.
class TurnTimer extends StatelessWidget {
  /// Состояние партии.
  final GameState state;

  /// Токены темы.
  final BlockDuelTheme theme;

  /// Создаёт индикатор таймера.
  const TurnTimer({super.key, required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    // Скрыт, если таймер выключен или партия окончена.
    if (!state.turnLimit.isFinite || state.gameOver) {
      return const SizedBox.shrink();
    }
    final ratio = (state.turnRemaining / state.turnLimit).clamp(0.0, 1.0);
    final low = state.turnRemaining <= _alarmThreshold;
    final color = low ? theme.bad : theme.playerColor(state.current);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.btnRadius),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: theme.panel2,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            state.turnRemaining.clamp(0, 999).toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: theme.fontMono,
            ),
          ),
        ),
      ],
    );
  }
}
