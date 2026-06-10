/// pilot_hud.dart — HUD скрытого пилота (View, общий для офлайна и онлайна).
///
/// За что отвечает файл:
///   Маленькая панель управления авто-игроком (pilot): кнопка запуска
///   («🛩 Pilot»), счётчик сделанных ходов, пауза/продолжить и стоп.
///   Чистый View: всё состояние и колбэки приходят снаружи (экран владеет
///   таймером пилота и решает, что значит «ход»). Показывается только в
///   режиме разработчика — гейт `isDeveloperProvider` ставит экран-владелец.
///
/// Виджеты:
///   [PilotHud]    — сама панель (или пилюля запуска, когда пилот выключен);
///   `_MiniIcon`   — иконка-кнопка (пауза/стоп);
///   `_PillButton` — пилюля запуска.
///
/// Соответствие TS: HUD `src/ui/pilot/dom.ts`. Вынесен из `game_screen.dart`
/// при добавлении онлайн-пилота (2026-06-10), чтобы не дублировать View.
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// HUD скрытого пилота (виден только разработчику). Запуск/пауза/стоп + счётчик.
class PilotHud extends StatelessWidget {
  /// Тема оформления.
  final BlockDuelTheme theme;

  /// Запущен ли пилот (таймер активен у экрана-владельца).
  final bool running;

  /// На паузе ли пилот.
  final bool paused;

  /// Сколько ходов сделал пилот за сессию.
  final int moves;

  /// Запустить пилота.
  final VoidCallback onStart;

  /// Пауза/продолжить.
  final VoidCallback onPause;

  /// Остановить пилота.
  final VoidCallback onStop;

  /// Создаёт HUD.
  const PilotHud({
    super.key,
    required this.theme,
    required this.running,
    required this.paused,
    required this.moves,
    required this.onStart,
    required this.onPause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (!running) {
      return _PillButton(theme: theme, label: '🛩 Pilot', onTap: onStart);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(theme.btnRadius),
        border: Border.all(color: theme.p0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🛩 $moves',
            style: TextStyle(
              color: theme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: theme.fontMono,
            ),
          ),
          const SizedBox(width: 8),
          _MiniIcon(theme: theme, icon: paused ? '▶' : '⏸', onTap: onPause),
          const SizedBox(width: 4),
          _MiniIcon(theme: theme, icon: '⏹', onTap: onStop),
        ],
      ),
    );
  }
}

/// Маленькая иконка-кнопка пилот-HUD.
class _MiniIcon extends StatelessWidget {
  final BlockDuelTheme theme;
  final String icon;
  final VoidCallback onTap;

  const _MiniIcon({
    required this.theme,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Text(icon, style: TextStyle(color: theme.ink, fontSize: 14)),
    ),
  );
}

/// Пилюля-кнопка запуска пилота.
class _PillButton extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final VoidCallback onTap;

  const _PillButton({
    required this.theme,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: theme.panel.withValues(alpha: 0.85),
    borderRadius: BorderRadius.circular(theme.btnRadius),
    child: InkWell(
      borderRadius: BorderRadius.circular(theme.btnRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.btnRadius),
          border: Border.all(color: theme.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: theme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
