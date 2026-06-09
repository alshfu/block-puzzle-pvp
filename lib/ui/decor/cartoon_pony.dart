/// cartoon_pony.dart — мультяшный chibi-пони (View, декоративный слой).
///
/// За что отвечает файл:
///   Порт `src/ui/components/CartoonPony.tsx` ОДИН-В-ОДИН: строит ту же
///   SVG-разметку (viewBox 0 0 160 160) с параметризацией цветами (тело +
///   3 пряди гривы + акцент) и рисует её через `flutter_svg` — так силуэт
///   точно совпадает с веб-версией (важно для гейта pixel-parity), без
///   ручного переноса безье в `CustomPaint`.
///
/// Полностью оригинальный силуэт — никаких имён/cutie marks/цветов конкретных
/// персонажей. Используется как маскот темы candy и как парящий декор фона.
///
/// Соответствие TS: `components/CartoonPony.tsx` (+ хелпер `darken`).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Мультяшный пони заданных цветов.
class CartoonPony extends StatelessWidget {
  /// Основной цвет тела (`#rrggbb`).
  final String body;

  /// Цвет тела чуть темнее — для теней; если null, затемняется [body].
  final String? bodyShade;

  /// Три пряди гривы/хвоста (основная + две акцентные).
  final List<String> mane;

  /// Цвет рога / звезды.
  final String accent;

  /// Размер стороны, px.
  final double size;

  /// Создаёт пони.
  const CartoonPony({
    super.key,
    required this.body,
    required this.mane,
    this.bodyShade,
    this.accent = '#ffd166',
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      cartoonPonySvg(
        body: body,
        bodyShade: bodyShade,
        mane: mane,
        accent: accent,
      ),
      width: size,
      height: size,
    );
  }
}

/// Собирает SVG-разметку пони (1:1 с `CartoonPony.tsx`). [mane] — ровно 3 цвета.
String cartoonPonySvg({
  required String body,
  required List<String> mane,
  String? bodyShade,
  String accent = '#ffd166',
}) {
  final shade = bodyShade ?? darken(body, 0.1);
  // Цвет радужки: для золотого акцента — тёмно-фиолетовый, иначе сам акцент
  // (как тернарник в TSX).
  final iris = accent == '#ffd166' ? '#3a1858' : accent;
  return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <path d="M 36 96 Q 12 90 14 116 Q 18 132 30 128 Q 24 118 30 108 Q 36 102 36 96 Z" fill="${mane[0]}" />
  <path d="M 34 110 Q 18 122 26 138 Q 36 138 40 122 Q 36 116 34 110 Z" fill="${mane[1]}" />
  <path d="M 36 122 Q 28 134 38 144 Q 44 138 42 126 Z" fill="${mane[2]}" />

  <ellipse cx="78" cy="100" rx="38" ry="26" fill="$body" />
  <ellipse cx="78" cy="106" rx="38" ry="20" fill="$shade" opacity="0.35" />

  <g>
    <rect x="50" y="118" width="10" height="22" rx="4" fill="$body" />
    <ellipse cx="55" cy="138" rx="6" ry="2.5" fill="#7f5b9c" />
    <rect x="68" y="118" width="10" height="22" rx="4" fill="$shade" />
    <ellipse cx="73" cy="138" rx="6" ry="2.5" fill="#7f5b9c" />
    <rect x="86" y="118" width="10" height="22" rx="4" fill="$body" />
    <ellipse cx="91" cy="138" rx="6" ry="2.5" fill="#7f5b9c" />
    <rect x="104" y="118" width="10" height="22" rx="4" fill="$shade" />
    <ellipse cx="109" cy="138" rx="6" ry="2.5" fill="#7f5b9c" />
  </g>

  <path d="M 96 88 Q 104 76 112 70 L 122 82 L 110 102 Z" fill="$body" />

  <ellipse cx="118" cy="60" rx="26" ry="24" fill="$body" />
  <ellipse cx="132" cy="68" rx="14" ry="10" fill="$body" />
  <ellipse cx="132" cy="71" rx="12" ry="7" fill="$shade" opacity="0.4" />

  <path d="M 102 42 Q 108 30 116 44 Z" fill="$body" />
  <path d="M 104 42 Q 108 36 113 44 Z" fill="$shade" opacity="0.5" />

  <path d="M 116 18 L 121 42 L 109 42 Z" fill="$accent" stroke="#fff" stroke-width="0.5" />

  <path d="M 108 38 Q 96 24 106 16 Q 116 22 118 36 Q 122 28 132 24 Q 134 38 124 46 Q 116 44 108 50 Z" fill="${mane[0]}" />
  <path d="M 110 46 Q 100 38 104 28 Q 112 32 116 44 Z" fill="${mane[1]}" />
  <path d="M 124 30 Q 132 22 138 32 Q 136 42 128 46 Z" fill="${mane[2]}" />
  <path d="M 100 60 Q 86 70 94 90 Q 104 86 108 72 Z" fill="${mane[0]}" />
  <path d="M 96 70 Q 84 80 90 92 Q 98 90 102 80 Z" fill="${mane[1]}" />
  <path d="M 96 84 Q 88 92 92 100 Q 100 96 100 88 Z" fill="${mane[2]}" />

  <ellipse cx="125" cy="60" rx="7" ry="9" fill="#fff" />
  <ellipse cx="125" cy="60" rx="6" ry="8" fill="#5a2a78" />
  <ellipse cx="125" cy="62" rx="4" ry="6" fill="$iris" />
  <ellipse cx="123" cy="56" rx="2" ry="2.5" fill="#fff" />
  <ellipse cx="127" cy="64" rx="1" ry="1.2" fill="#fff" opacity="0.85" />

  <path d="M 119 53 q -2 -2 -4 -1" stroke="#3a1858" stroke-width="1.2" fill="none" stroke-linecap="round" />
  <path d="M 119 56 q -3 -1 -5 1" stroke="#3a1858" stroke-width="1.2" fill="none" stroke-linecap="round" />
  <path d="M 119 60 q -3 0 -5 2" stroke="#3a1858" stroke-width="1.2" fill="none" stroke-linecap="round" />

  <ellipse cx="138" cy="72" rx="4" ry="2.5" fill="#ff8fb8" opacity="0.65" />

  <ellipse cx="138" cy="65" rx="1" ry="1.4" fill="#7a3464" opacity="0.6" />
  <path d="M 134 74 q 4 4 9 0" stroke="#5a2a78" stroke-width="1.5" fill="none" stroke-linecap="round" />

  <g transform="translate(76 96)" opacity="0.75">
    <polygon points="0,-7 2,-2 7,-2 3,1 5,6 0,3 -5,6 -3,1 -7,-2 -2,-2" fill="$accent" stroke="#fff" stroke-width="0.5" />
  </g>

  <g transform="translate(135 18)" opacity="0.9">
    <polygon points="0,-4 1,-1 4,0 1,1 0,4 -1,1 -4,0 -1,-1" fill="#fff" />
  </g>
</svg>''';
}

/// Затемняет hex-цвет `#rrggbb` на долю [amount] (0..1) к чёрному (порт `darken`
/// из TSX — простая RGB-интерполяция, не цветово-точная).
String darken(String hex, double amount) {
  final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex);
  if (m == null) return hex;
  final rgb = int.parse(m.group(1)!, radix: 16);
  final r = (rgb >> 16) & 0xff;
  final g = (rgb >> 8) & 0xff;
  final b = rgb & 0xff;
  final k = 1 - amount;
  String h(int v) {
    final d = (v * k).round().clamp(0, 255);
    return d.toRadixString(16).padLeft(2, '0');
  }

  return '#${h(r)}${h(g)}${h(b)}';
}
