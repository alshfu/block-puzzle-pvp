/// logo.dart — логотип игры (View).
///
/// За что отвечает файл:
///   Рисует текстовый логотип «BlockDuel» + акцент «9×9» заголовочным шрифтом
///   темы с её начертанием и трекингом. Размер — fluid (CSS `clamp`) через
///   [clampVw]. Чистый View, без логики.
///
/// Соответствие TS: `components/Logo.tsx` (size 'big' | 'mini').
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../responsive.dart';

/// Размер логотипа: крупный (на меню) или компактный (в HUD).
enum LogoSize { big, mini }

/// Логотип «BlockDuel 9×9». Цвет основной части — `ink`, акцент «9×9» — `p0`.
class Logo extends StatelessWidget {
  /// Размер логотипа.
  final LogoSize size;

  /// Создаёт логотип.
  const Logo({super.key, this.size = LogoSize.big});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    final fontSize = size == LogoSize.big
        ? clampVw(context, min: 34, prefVw: 7, max: 58)
        : clampVw(context, min: 18, prefVw: 4, max: 26);

    final base = TextStyle(
      fontFamily: tokens.fontDisplay,
      fontWeight: tokens.displayWeight,
      fontSize: fontSize,
      letterSpacing: tokens.displaySpacingEm * fontSize,
      height: 1.0,
    );

    return RichText(
      text: TextSpan(
        style: base.copyWith(color: tokens.ink),
        children: [
          const TextSpan(text: 'Block'),
          TextSpan(
            text: 'Duel',
            style: TextStyle(color: tokens.p0),
          ),
          TextSpan(
            text: '  9×9',
            style: TextStyle(color: tokens.p1, fontSize: fontSize * 0.6),
          ),
        ],
      ),
    );
  }
}
