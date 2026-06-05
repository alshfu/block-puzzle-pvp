/// board_game.dart — отрисовка доски 9×9 на Flame (View-слой рендера).
///
/// За что отвечает файл:
///   Лёгкая Flame-игра, рисующая поле: занятые клетки в цвете игрока, пустые
///   клетки с сеткой и полупрозрачный «призрак» выбранной фигуры под курсором.
///   Данные ([BoardRender]) приходят снаружи из View и обновляются на каждый
///   кадр — сам по себе движок состояния игры не держит (это дело ViewModel).
///
/// Соответствие TS: `components/Board.tsx` (DOM-grid → Flame Canvas, как в
/// MIGRATION_FLUTTER §6.2).
library;

import 'package:block_duel/core/core.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Данные для отрисовки доски: что на поле, что в «призраке» и цвета темы.
class BoardRender {
  /// Текущая доска.
  final Board board;

  /// Абсолютные клетки превью выбранной фигуры (может быть пустым).
  final List<Coord> preview;

  /// Допустима ли постановка превью (зелёный/красный призрак).
  final bool previewValid;

  /// Токены темы (цвета и радиусы).
  final BlockDuelTheme theme;

  /// Создаёт данные отрисовки.
  const BoardRender({
    required this.board,
    required this.preview,
    required this.previewValid,
    required this.theme,
  });
}

/// Flame-игра доски. Хранит лишь ссылку на актуальные [data]; всю отрисовку
/// выполняет единственный [_BoardComponent].
class BoardGame extends FlameGame {
  /// Текущие данные отрисовки (обновляются View).
  BoardRender? data;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    add(_BoardComponent());
  }
}

/// Компонент, рисующий поле целиком (9×9 клеток + призрак).
class _BoardComponent extends Component with HasGameReference<BoardGame> {
  @override
  void render(Canvas canvas) {
    final data = game.data;
    if (data == null) return;
    final side = game.size.x;
    if (side <= 0) return;
    final cell = side / boardSize;
    final theme = data.theme;

    final fillEmpty = Paint()..color = theme.cell;
    final gridLine = Paint()
      ..color = theme.cellLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final filledPaint = Paint();

    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        final rect = Rect.fromLTWH(
          c * cell + 1,
          r * cell + 1,
          cell - 2,
          cell - 2,
        );
        final rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(theme.cellRadius),
        );
        final boardCell = data.board[r][c];
        if (boardCell.filled) {
          filledPaint.color = theme.playerColor(boardCell.owner ?? 0);
          canvas.drawRRect(rrect, filledPaint);
        } else {
          canvas.drawRRect(rrect, fillEmpty);
          canvas.drawRRect(rrect, gridLine);
        }
      }
    }

    // Призрак выбранной фигуры.
    if (data.preview.isNotEmpty) {
      final ghost = Paint()
        ..color = (data.previewValid ? theme.good : theme.bad).withValues(
          alpha: 0.45,
        );
      for (final coord in data.preview) {
        if (coord.r < 0 ||
            coord.r >= boardSize ||
            coord.c < 0 ||
            coord.c >= boardSize) {
          continue;
        }
        final rect = Rect.fromLTWH(
          coord.c * cell + 1,
          coord.r * cell + 1,
          cell - 2,
          cell - 2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(theme.cellRadius)),
          ghost,
        );
      }
    }
  }
}
