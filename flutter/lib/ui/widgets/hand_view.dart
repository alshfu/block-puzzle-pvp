/// hand_view.dart — рука фигур текущего игрока (View).
///
/// За что отвечает файл:
///   Показывает фигуры в руке, подсвечивает выбранную (в её ТЕКУЩЕЙ ориентации,
///   а не в базовой) и сообщает о выборе через [onSelect]. Повторный тап по уже
///   выбранной фигуре поворачивает её ([onRotate]) — поворот прямо в руке. На
///   ходу бота ([interactive] = false) выбор заблокирован. Чистый View поверх
///   [MiniPiece]; логики нет.
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

  /// Клетки выбранной фигуры в ТЕКУЩЕЙ ориентации (для отрисовки в руке);
  /// `null`, если ничего не выбрано — тогда рисуется базовая форма.
  final List<Coord>? selectedCells;

  /// Команда выбора фигуры.
  final void Function(String pieceId) onSelect;

  /// Команда поворота выбранной фигуры (повторный тап по выбранной).
  final VoidCallback onRotate;

  /// Создаёт ряд руки.
  const HandView({
    super.key,
    required this.hand,
    required this.selectedId,
    required this.interactive,
    required this.owner,
    required this.theme,
    required this.onSelect,
    required this.onRotate,
    this.selectedCells,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final piece in hand)
          Builder(
            builder: (context) {
              final isSel = piece.id == selectedId;
              // Выбранную рисуем в текущей ориентации, остальные — в базовой.
              final cells = isSel && selectedCells != null
                  ? selectedCells!
                  : piece.cells;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _HandSlot(
                  selected: isSel,
                  interactive: interactive,
                  accent: theme.playerColor(owner),
                  theme: theme,
                  // Повторный тап по выбранной — поворот; иначе — выбор.
                  onTap: isSel ? onRotate : () => onSelect(piece.id),
                  child: MiniPiece(cells: cells, owner: owner, cellSize: 18),
                ),
              );
            },
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
