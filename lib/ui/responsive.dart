/// responsive.dart — адаптивная вёрстка: breakpoints и порт CSS `clamp()`.
///
/// За что отвечает файл:
///   Хелперы для воспроизведения отзывчивой типографики и раскладки из
///   `styles.css`: fluid-размеры через [clampVw] (аналог CSS
///   `clamp(min, Nvw, max)`) и пороги ширины [bpPhone]/[bpTablet]/[bpDesktop]
///   (CSS `@media`). Значения подобраны 1:1 с CSS для pixel-parity
///   (MIGRATION_FLUTTER §6.4–6.5).
library;

import 'package:flutter/widgets.dart';

/// Порог «телефон» (CSS `@media (min-width: 480px)`).
const double bpPhone = 480;

/// Порог «планшет» (CSS `@media (min-width: 900px)`).
const double bpTablet = 900;

/// Порог «десктоп» (CSS `@media (min-width: 1200px)`).
const double bpDesktop = 1200;

/// Аналог CSS `clamp(min, prefVw·vw, max)`: вычисляет размер как долю ширины
/// вьюпорта [prefVw] (в процентах), ограниченную диапазоном [min]…[max].
///
/// Пример: `clampVw(context, min: 36, prefVw: 6.5, max: 58)` ≡ CSS
/// `clamp(36px, 6.5vw, 58px)` для логотипа.
double clampVw(
  BuildContext context, {
  required double min,
  required double prefVw,
  required double max,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final preferred = width * prefVw / 100;
  return preferred.clamp(min, max);
}
