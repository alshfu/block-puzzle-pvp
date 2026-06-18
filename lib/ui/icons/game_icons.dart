/// game_icons.dart — иконки режимов и power-ups (View, без ассет-файлов).
///
/// За что отвечает файл:
///   Заменяет emoji-плейсхолдеры в меню режимов и в power-ups на векторные
///   Material-иконки (приоритет № 2 из `ASSETS.md`). Один источник правды:
///   id режима/power-up → [IconData]. Так UI выглядит как настоящее приложение,
///   единообразно по темам и без внешних спрайт-файлов (Material-иконки уже
///   включены — `uses-material-design: true` в `pubspec.yaml`).
///
/// Почему Material-иконки, а не картинки:
///   проект почти полностью процедурный (см. `ASSETS.md`); векторные иконки дают
///   чёткость на любом DPI, тему-независимый цвет и нулевой вес ассетов. Когда
///   появится художественный набор — достаточно заменить эти мапы (или отрисовку
///   в виджетах), не трогая бизнес-логику.
library;

import 'package:flutter/material.dart';

/// Иконка режима по его id (`GameMode.<name>` / `GameModeDescriptor.id`).
/// Неизвестный id → нейтральная игровая иконка.
IconData modeIcon(String id) => switch (id) {
  'bot' => Icons.smart_toy_outlined,
  'hotseat' => Icons.people_alt_outlined,
  'arcade' => Icons.sports_esports_outlined,
  'botvbot' => Icons.movie_outlined,
  'memorySolo' => Icons.psychology_outlined,
  'memoryDuel' => Icons.style_outlined,
  'coop' => Icons.grid_view_outlined,
  'match3' => Icons.bubble_chart_outlined,
  'tetris' => Icons.extension_outlined,
  'showcase' => Icons.live_tv_outlined,
  'tutorial' => Icons.school_outlined,
  'online' => Icons.public,
  _ => Icons.videogame_asset_outlined,
};

/// Иконка power-up по его id (`PowerupDef.id`).
/// Неизвестный id → нейтральная «искра».
IconData powerUpIcon(String id) => switch (id) {
  'hint' => Icons.lightbulb_outline,
  'swap_hand' => Icons.cached,
  'stick_row' => Icons.table_rows_outlined,
  'stick_col' => Icons.view_week_outlined,
  'bomb_3x3' => Icons.crisis_alert,
  'auto_play' => Icons.auto_awesome,
  _ => Icons.bolt,
};
