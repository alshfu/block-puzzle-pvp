/// scoreboard.dart — карточки счёта обоих игроков (View).
///
/// За что отвечает файл:
///   Показывает имя, счёт и комбо каждого игрока; активного игрока подсвечивает
///   его цветом. Чистый View поверх [GameState]; логики нет.
///
/// Соответствие TS: `components/Scoreboard.tsx` + `PlayerCard.tsx`.
library;

import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../design_tokens.dart';

/// Ряд из двух карточек игроков.
class Scoreboard extends StatelessWidget {
  /// Состояние партии.
  final GameState state;

  /// Токены темы.
  final BlockDuelTheme theme;

  /// Соло-режим (аркада): показываем только карточку игрока 0.
  final bool solo;

  /// Создаёт скорборд.
  const Scoreboard({
    super.key,
    required this.state,
    required this.theme,
    this.solo = false,
  });

  @override
  Widget build(BuildContext context) {
    if (solo) {
      return _PlayerCard(state: state, player: 0, theme: theme);
    }
    return Row(
      children: [
        Expanded(
          child: _PlayerCard(state: state, player: 0, theme: theme),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PlayerCard(state: state, player: 1, theme: theme),
        ),
      ],
    );
  }
}

/// Карточка одного игрока.
class _PlayerCard extends StatelessWidget {
  final GameState state;
  final int player;
  final BlockDuelTheme theme;

  const _PlayerCard({
    required this.state,
    required this.player,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final p = state.players[player];
    final active = !state.gameOver && state.current == player;
    final color = theme.playerColor(player);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(
          color: active ? color : theme.line,
          width: active ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${p.score}'
                  '${p.combo > 1 ? '  ×${p.combo}' : ''}',
                  style: TextStyle(
                    color: active ? color : theme.muted,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: theme.fontMono,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
