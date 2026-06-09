/// powerups_panel.dart — панель power-ups в игре (View).
///
/// За что отвечает файл:
///   Ряд кнопок расходуемых power-ups (иконка + остаток в инвентаре). Подсветка
///   активного (режим выбора клетки для палочки/бомбы), блокировка при нуле или
///   не своём ходе. Логики нет — клики уходят в [onTap] (обрабатывает экран).
///
/// Соответствие TS: `components/PowerupsPanel.tsx`.
library;

import 'package:flutter/material.dart';

import '../../shop/powerups.dart';
import '../design_tokens.dart';

/// Панель power-ups (одиночные режимы).
class PowerupsPanel extends StatelessWidget {
  /// Токены темы.
  final BlockDuelTheme theme;

  /// Инвентарь: id → количество.
  final Map<String, int> inventory;

  /// Активный power-up в режиме выбора клетки (или `null`).
  final String? active;

  /// Доступны ли клики (ход локального игрока, партия идёт).
  final bool enabled;

  /// Обработчик нажатия по power-up.
  final void Function(String id) onTap;

  /// Создаёт панель power-ups.
  const PowerupsPanel({
    super.key,
    required this.theme,
    required this.inventory,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final p in powerupDefs)
          _PuButton(
            theme: theme,
            def: p,
            count: inventory[p.id] ?? 0,
            isActive: active == p.id,
            enabled: enabled && (inventory[p.id] ?? 0) > 0,
            onTap: () => onTap(p.id),
          ),
      ],
    );
  }
}

/// Кнопка одного power-up.
class _PuButton extends StatelessWidget {
  final BlockDuelTheme theme;
  final PowerupDef def;
  final int count;
  final bool isActive;
  final bool enabled;
  final VoidCallback onTap;

  const _PuButton({
    required this.theme,
    required this.def,
    required this.count,
    required this.isActive,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dim = !enabled;
    return Tooltip(
      message: '${def.name} — ${def.hint}',
      child: Opacity(
        opacity: dim ? 0.45 : 1,
        child: Material(
          color: isActive ? theme.p0 : theme.panel,
          borderRadius: BorderRadius.circular(theme.btnRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(theme.btnRadius),
            onTap: enabled ? onTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(theme.btnRadius),
                border: Border.all(color: isActive ? theme.p0 : theme.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(def.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: isActive ? theme.bg : theme.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: theme.fontMono,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
