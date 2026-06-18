/// avatar_view.dart — отрисовка аватара профиля/соперника (View).
///
/// За что отвечает файл:
///   Универсально показывает аватар по его строковому значению из
///   `Profile.avatar` / `OnlineProfile.avatar`: если значение — известный id из
///   `avatarIds` (`avatarIcon` вернул иконку) → рисует векторную Material-иконку;
///   иначе значение трактуется как текст (старый emoji-аватар локального
///   профиля или соперника из онлайна) — обратная совместимость. Единая точка
///   рендера: меню, экран профиля, лидерборд.
///
/// Соответствие ROADMAP/ASSETS: приоритет № 2 — иконки вместо emoji.
library;

import 'package:flutter/material.dart';

import '../icons/game_icons.dart';

/// Аватар: иконка (для известного id) или текст-emoji (фолбэк).
class AvatarView extends StatelessWidget {
  /// Значение аватара (id из [avatarIds] или старый emoji).
  final String value;

  /// Размер стороны/иконки в логических пикселях.
  final double size;

  /// Цвет иконки (для emoji-фолбэка игнорируется). По умолчанию — `ink` темы.
  final Color? color;

  /// Создаёт аватар.
  const AvatarView({
    super.key,
    required this.value,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final icon = avatarIcon(value);
    if (icon != null) {
      return Icon(
        icon,
        size: size,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      );
    }
    // Старый emoji / аватар соперника — как текст (≈0.92 от стороны иконки).
    return Text(value, style: TextStyle(fontSize: size * 0.92));
  }
}
