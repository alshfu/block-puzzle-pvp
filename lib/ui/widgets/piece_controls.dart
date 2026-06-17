/// piece_controls.dart — панель управления фигурой (View).
///
/// За что отвечает файл:
///   Переиспользуемая «панель управления» для режимов с постановкой фигур
///   тапом (Co-op Tetris, Memory Solo, Memory Duel): кнопки «↻ повернуть» и
///   «✕ снять» при выбранной фигуре, иначе — подсказка-инструкция. Делает
///   поворот фигуры явным и обнаруживаемым (в отличие от скрытого «тапни по
///   выбранной фигуре в руке»), как на главном экране 9×9.
///
/// Чистый View: команды наружу через колбэки, состояние — у вызывающего.
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Панель управления выбранной фигурой.
class PieceControls extends StatelessWidget {
  /// Токены темы.
  final BlockDuelTheme theme;

  /// Выбрана ли фигура (иначе показывается подсказка).
  final bool hasSelection;

  /// Доступен ли поворот (у фигуры > 1 ориентации).
  final bool canRotate;

  /// Команда поворота выбранной фигуры.
  final VoidCallback onRotate;

  /// Команда снятия выбора.
  final VoidCallback onDeselect;

  /// Подсказка, когда фигура не выбрана.
  final String hint;

  /// Создаёт панель управления.
  const PieceControls({
    super.key,
    required this.theme,
    required this.hasSelection,
    required this.canRotate,
    required this.onRotate,
    required this.onDeselect,
    this.hint = 'Выбери фигуру и тапни по доске, чтобы поставить',
  });

  @override
  Widget build(BuildContext context) {
    if (!hasSelection) {
      return SizedBox(
        height: 42,
        child: Center(
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.muted, fontSize: 13),
          ),
        ),
      );
    }
    return SizedBox(
      height: 42,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Btn(
            theme: theme,
            icon: Icons.rotate_right_rounded,
            label: 'повернуть',
            primary: true,
            onTap: canRotate ? onRotate : null,
          ),
          const SizedBox(width: 10),
          _Btn(
            theme: theme,
            icon: Icons.close_rounded,
            label: 'снять',
            onTap: onDeselect,
          ),
        ],
      ),
    );
  }
}

/// Кнопка-панель: иконка + текст.
class _Btn extends StatelessWidget {
  final BlockDuelTheme theme;
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback? onTap;

  const _Btn({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = primary && onTap != null;
    return Material(
      color: accent ? theme.p0.withValues(alpha: 0.16) : theme.panel,
      borderRadius: BorderRadius.circular(theme.btnRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.btnRadius),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.btnRadius),
              border: Border.all(color: accent ? theme.p0 : theme.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: theme.ink),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: theme.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
