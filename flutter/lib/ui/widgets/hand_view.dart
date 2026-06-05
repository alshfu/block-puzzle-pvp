/// hand_view.dart — рука фигур текущего игрока (View).
///
/// За что отвечает файл:
///   Показывает фигуры в руке, подсвечивает выбранную и сообщает о выборе через
///   [onSelect]. Когда ход не за человеком ([interactive] = false) — выбор
///   заблокирован. Чистый View поверх [MiniPiece]; логики нет.
///
/// Соответствие TS: `components/Hand.tsx`.
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';

import '../design_tokens.dart';
import 'mini_piece.dart';

/// Ряд фигур руки с подсветкой выбранной.
class HandView extends StatelessWidget {
  /// Фигуры в руке.
  final List<PieceInstance> hand;

  /// Id выбранной фигуры (или `null`).
  final String? selectedId;

  /// Доступен ли выбор (false на ходу бота).
  final bool interactive;

  /// Цвет владельца-текущего игрока (для рамки выбора).
  final int owner;

  /// Токены темы.
  final BlockDuelTheme theme;

  /// Команда выбора фигуры.
  final void Function(String pieceId) onSelect;

  /// Создаёт ряд руки.
  const HandView({
    super.key,
    required this.hand,
    required this.selectedId,
    required this.interactive,
    required this.owner,
    required this.theme,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final piece in hand)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _HandSlot(
              selected: piece.id == selectedId,
              interactive: interactive,
              accent: theme.playerColor(owner),
              theme: theme,
              onTap: () => onSelect(piece.id),
              child: MiniPiece(cells: piece.cells, owner: owner, cellSize: 18),
            ),
          ),
      ],
    );
  }
}

/// Слот руки: рамка-панель, подсветка выбора, кликабельность.
class _HandSlot extends StatelessWidget {
  final bool selected;
  final bool interactive;
  final Color accent;
  final BlockDuelTheme theme;
  final VoidCallback onTap;
  final Widget child;

  const _HandSlot({
    required this.selected,
    required this.interactive,
    required this.accent,
    required this.theme,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: interactive ? 1 : 0.5,
      child: Material(
        color: theme.panel,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(theme.cardRadius),
          onTap: interactive ? onTap : null,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.cardRadius),
              border: Border.all(
                color: selected ? accent : theme.line,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
