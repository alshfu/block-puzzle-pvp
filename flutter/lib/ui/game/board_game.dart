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

import '../../shop/skins.dart';
import '../design_tokens.dart';

/// Данные для отрисовки доски: что на поле, что в «призраке» и цвета темы.
class BoardRender {
  /// Текущая доска.
  final Board board;

  /// Абсолютные клетки превью выбранной фигуры (может быть пустым).
  final List<Coord> preview;

  /// Допустима ли постановка превью (зелёный/красный призрак).
  final bool previewValid;

  /// Клетки, которые ОЧИСТЯТСЯ при этой постановке (подсветка будущих очисток).
  final List<Coord> clearPreview;

  /// Токены темы (цвета и радиусы).
  final BlockDuelTheme theme;

  /// Стиль скина занятых клеток (надетый игроком).
  final SkinStyle skin;

  /// Создаёт данные отрисовки.
  const BoardRender({
    required this.board,
    required this.preview,
    required this.previewValid,
    required this.theme,
    this.clearPreview = const [],
    this.skin = SkinStyle.plain,
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
          _drawFilledCell(canvas, rect, theme, data.skin, boardCell.owner ?? 0);
        } else {
          canvas.drawRRect(rrect, fillEmpty);
          canvas.drawRRect(rrect, gridLine);
        }
      }
    }

    // Подсветка будущих очисток (ТЗ §8.2): клетки, которые исчезнут.
    if (data.clearPreview.isNotEmpty) {
      final glow = Paint()..color = theme.good.withValues(alpha: 0.35);
      final border = Paint()
        ..color = theme.good
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final coord in data.clearPreview) {
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
        final rr = RRect.fromRectAndRadius(
          rect,
          Radius.circular(theme.cellRadius),
        );
        canvas.drawRRect(rr, glow);
        canvas.drawRRect(rr, border);
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

  /// Рисует занятую клетку игрока [owner] согласно скину [skin] — порт
  /// CSS-стилей `.skin-*` из TS `styles.css` на Canvas.
  void _drawFilledCell(
    Canvas canvas,
    Rect rect,
    BlockDuelTheme theme,
    SkinStyle skin,
    int owner,
  ) {
    final base = theme.playerColor(owner);
    final dark = theme.playerColorDark(owner);
    final radius = skin == SkinStyle.pixel
        ? Radius.zero
        : Radius.circular(theme.cellRadius);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    switch (skin) {
      case SkinStyle.plain:
        canvas.drawRRect(rrect, Paint()..color = base);

      case SkinStyle.gem:
      case SkinStyle.candy:
        // Радиальный градиент: блик у верх-лево → цвет → тёмный край.
        final highlight = skin == SkinStyle.candy
            ? const Color(0x66FFFFFF)
            : const Color(0x33FFFFFF);
        canvas.drawRRect(
          rrect,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.4, -0.55),
              radius: 1.1,
              colors: [highlight, base, dark],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(rect),
        );
        // Глянцевый верхний блик.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.4),
            radius,
          ),
          Paint()..color = const Color(0x22FFFFFF),
        );

      case SkinStyle.bullet:
        // Холодный металл: вертикальный градиент + цветная нижняя кромка.
        canvas.drawRRect(
          rrect,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFCFD6E2), Color(0xFF7F8B9C), Color(0xFF3A4150)],
              stops: [0.0, 0.6, 1.0],
            ).createShader(rect),
        );
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.bottom - 2, rect.width, 2),
          Paint()..color = base,
        );

      case SkinStyle.neon:
        // Тёмная клетка + светящаяся рамка в цвете игрока.
        canvas.drawRRect(rrect, Paint()..color = theme.cell);
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = base
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3),
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = base
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );

      case SkinStyle.pixel:
        // Угловатый ретро-блок с бевелем (светлый верх-лево, тёмный низ-право).
        canvas.drawRRect(rrect, Paint()..color = base);
        final bevel = rect.width * 0.18;
        canvas.drawPath(
          Path()
            ..moveTo(rect.left, rect.top)
            ..lineTo(rect.right, rect.top)
            ..lineTo(rect.right - bevel, rect.top + bevel)
            ..lineTo(rect.left + bevel, rect.top + bevel)
            ..lineTo(rect.left + bevel, rect.bottom - bevel)
            ..lineTo(rect.left, rect.bottom)
            ..close(),
          Paint()..color = const Color(0x66FFFFFF),
        );
        canvas.drawPath(
          Path()
            ..moveTo(rect.right, rect.bottom)
            ..lineTo(rect.left, rect.bottom)
            ..lineTo(rect.left + bevel, rect.bottom - bevel)
            ..lineTo(rect.right - bevel, rect.bottom - bevel)
            ..lineTo(rect.right - bevel, rect.top + bevel)
            ..lineTo(rect.right, rect.top)
            ..close(),
          Paint()..color = const Color(0x59000000),
        );
    }
  }
}
