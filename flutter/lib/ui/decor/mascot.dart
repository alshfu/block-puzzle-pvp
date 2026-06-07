/// mascot.dart — маскот темы (View, декоративный слой).
///
/// За что отвечает файл:
///   Порт `src/ui/components/Mascot.tsx`: под каждую тему свой персонаж —
///     • candy   — мультяшный пони ([CartoonPony]);
///     • night   — тень в капюшоне с горящими янтарными глазами;
///     • neutral — киберробот с янтарным сканером.
///   Робот и тень — те же inline-SVG (viewBox 0 0 120 120), что в TSX,
///   нарисованные через `flutter_svg` для точного совпадения силуэта.
///
/// Соответствие TS: `components/Mascot.tsx` (`NeutralRobot`/`NightShade`).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design_tokens.dart';
import 'cartoon_pony.dart';

/// Маскот, выбираемый по теме [themeId].
class Mascot extends StatelessWidget {
  /// Текущая тема.
  final ThemeId themeId;

  /// Размер стороны, px.
  final double size;

  /// Создаёт маскот темы.
  const Mascot({super.key, required this.themeId, this.size = 140});

  @override
  Widget build(BuildContext context) {
    switch (themeId) {
      case ThemeId.candy:
        return CartoonPony(
          body: '#ff9ecb',
          mane: const ['#ff6b8a', '#ffd166', '#7fe7df'],
          accent: '#b89cff',
          size: size,
        );
      case ThemeId.night:
        return SvgPicture.string(_nightShadeSvg, width: size, height: size);
      case ThemeId.neutral:
        return SvgPicture.string(_neutralRobotSvg, width: size, height: size);
    }
  }
}

/// Киберробот с янтарным сканером (порт `NeutralRobot`).
const String _neutralRobotSvg = '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <line x1="60" y1="14" x2="60" y2="4" stroke="#36d6e7" stroke-width="2" />
  <circle cx="60" cy="3" r="3" fill="#ff9d42" />
  <rect x="38" y="14" width="44" height="38" rx="6" fill="#1c232d" stroke="#36d6e7" stroke-width="2" />
  <rect x="44" y="26" width="32" height="10" rx="2" fill="#0e1116" />
  <rect x="46" y="29" width="28" height="4" rx="1" fill="#ff9d42" />
  <rect x="34" y="24" width="4" height="18" fill="#36d6e7" />
  <rect x="82" y="24" width="4" height="18" fill="#36d6e7" />
  <rect x="50" y="42" width="20" height="3" rx="1" fill="#36d6e7" />
  <rect x="54" y="52" width="12" height="6" fill="#1c232d" />
  <rect x="34" y="58" width="52" height="44" rx="6" fill="#1c232d" stroke="#36d6e7" stroke-width="2" />
  <circle cx="60" cy="80" r="7" fill="#ff9d42" opacity="0.85" />
  <circle cx="60" cy="80" r="3" fill="#fff" />
  <circle cx="44" cy="68" r="2" fill="#36d6e7" />
  <circle cx="76" cy="68" r="2" fill="#36d6e7" />
  <circle cx="44" cy="92" r="2" fill="#37d67a" />
  <circle cx="76" cy="92" r="2" fill="#ef5e6b" />
  <rect x="22" y="62" width="10" height="30" rx="3" fill="#1c232d" stroke="#36d6e7" />
  <rect x="88" y="62" width="10" height="30" rx="3" fill="#1c232d" stroke="#36d6e7" />
</svg>''';

/// Тень в капюшоне с горящими глазами (порт `NightShade`).
const String _nightShadeSvg = '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="nightBeam" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffd23f" stop-opacity="0.7" />
      <stop offset="1" stop-color="#ffd23f" stop-opacity="0" />
    </linearGradient>
  </defs>
  <path d="M 30 110 L 60 8 L 90 110 Z" fill="url(#nightBeam)" opacity="0.35" />
  <path d="M 22 110 Q 22 60 60 20 Q 98 60 98 110 Z" fill="#04060b" stroke="#3aa6ff" stroke-width="2" />
  <path d="M 32 100 Q 40 56 60 30 Q 80 56 88 100 Z" fill="#070a12" />
  <ellipse cx="48" cy="62" rx="4" ry="5" fill="#ffd23f" />
  <ellipse cx="72" cy="62" rx="4" ry="5" fill="#ffd23f" />
  <ellipse cx="48" cy="62" rx="8" ry="9" fill="#ffd23f" opacity="0.25" />
  <ellipse cx="72" cy="62" rx="8" ry="9" fill="#ffd23f" opacity="0.25" />
  <ellipse cx="48" cy="62" rx="1.5" ry="2" fill="#04060b" />
  <ellipse cx="72" cy="62" rx="1.5" ry="2" fill="#04060b" />
  <polygon points="22,110 30,98 38,110" fill="#04060b" />
  <polygon points="40,110 48,100 56,110" fill="#04060b" />
  <polygon points="58,110 66,102 74,110" fill="#04060b" />
  <polygon points="78,110 86,98 94,110" fill="#04060b" />
</svg>''';
