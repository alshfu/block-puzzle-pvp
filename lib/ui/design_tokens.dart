/// design_tokens.dart — дизайн-токены трёх тем (порт `src/ui/themes.ts`).
///
/// За что отвечает файл:
///   Единый источник правды по визуальным константам (цвета, радиусы, шрифты,
///   начертания) для тем `neutral` / `candy` / `night`. Значения скопированы
///   hex-в-hex и px-в-px из `themes.ts` — это требование pixel-parity
///   (MIGRATION_FLUTTER §6.1): расхождение даже на единицу = регресс дизайна.
///
/// Как используется:
///   [BlockDuelTheme] — `ThemeExtension`, который кладётся в `ThemeData` и
///   читается во View через `Theme.of(context).extension<BlockDuelTheme>()`.
///   [blockDuelThemes] — карта id→тема; [buildThemeData] собирает `ThemeData`.
///
/// Шрифты: имена семейств соответствуют будущим bundled TTF
/// (Фаза 0/5). Пока файлы шрифтов не подключены — рендер идёт фолбэком.
library;

import 'package:flutter/material.dart';

/// Идентификаторы тем (порядок как в `THEME_ORDER`). TS: `ThemeId`.
enum ThemeId { neutral, candy, night }

/// Дизайн-токены одной темы. Поля 1:1 с CSS-переменными из `themes.ts`.
///
/// Цвета (`--bg`…`--cellline`), радиусы (`--*-r`), шрифты (`--font-*`) и
/// начертание заголовков (`--display-weight`/`--display-spacing`) плюс мета
/// (id/label/sub/имена игроков) для переключателя тем.
@immutable
class BlockDuelTheme extends ThemeExtension<BlockDuelTheme> {
  /// Идентификатор темы.
  final ThemeId id;

  /// Человекочитаемое название (для переключателя).
  final String label;

  /// Подпись-описание темы.
  final String sub;

  /// Светлая/тёмная база (CSS `kind`).
  final Brightness kind;

  /// Имя игрока 0 в этой теме.
  final String p0name;

  /// Имя игрока 1 в этой теме.
  final String p1name;

  // ── Цвета (`--*`) ──────────────────────────────────────────────────────
  /// Фон 1.
  final Color bg;

  /// Фон 2 (градиентная пара).
  final Color bg2;

  /// Цвет панели.
  final Color panel;

  /// Цвет панели 2.
  final Color panel2;

  /// Линии/границы.
  final Color line;

  /// Основной текст.
  final Color ink;

  /// Приглушённый текст.
  final Color muted;

  /// Цвет игрока 0.
  final Color p0;

  /// Тёмный оттенок игрока 0.
  final Color p0d;

  /// Цвет игрока 1.
  final Color p1;

  /// Тёмный оттенок игрока 1.
  final Color p1d;

  /// Позитивный акцент.
  final Color good;

  /// Негативный акцент.
  final Color bad;

  /// Фон пустой клетки доски.
  final Color cell;

  /// Линии сетки клеток.
  final Color cellLine;

  // ── Радиусы (`--*-r`, в логических пикселях) ───────────────────────────
  /// Радиус скругления доски.
  final double boardRadius;

  /// Радиус карточек.
  final double cardRadius;

  /// Радиус кнопок.
  final double btnRadius;

  /// Радиус клетки.
  final double cellRadius;

  /// Радиус мини-фигур.
  final double miniRadius;

  // ── Типографика ────────────────────────────────────────────────────────
  /// Семейство заголовочного шрифта.
  final String fontDisplay;

  /// Семейство моноширинного шрифта.
  final String fontMono;

  /// Начертание заголовков.
  final FontWeight displayWeight;

  /// Межбуквенный интервал заголовков (em → логические пиксели при размере 1em
  /// учитываются на месте применения; здесь храним коэффициент в em).
  final double displaySpacingEm;

  /// Создаёт набор токенов темы.
  const BlockDuelTheme({
    required this.id,
    required this.label,
    required this.sub,
    required this.kind,
    required this.p0name,
    required this.p1name,
    required this.bg,
    required this.bg2,
    required this.panel,
    required this.panel2,
    required this.line,
    required this.ink,
    required this.muted,
    required this.p0,
    required this.p0d,
    required this.p1,
    required this.p1d,
    required this.good,
    required this.bad,
    required this.cell,
    required this.cellLine,
    required this.boardRadius,
    required this.cardRadius,
    required this.btnRadius,
    required this.cellRadius,
    required this.miniRadius,
    required this.fontDisplay,
    required this.fontMono,
    required this.displayWeight,
    required this.displaySpacingEm,
  });

  /// Цвет игрока по индексу (0/1) — удобный доступ для доски и карточек.
  Color playerColor(int player) => player == 0 ? p0 : p1;

  /// Тёмный оттенок игрока по индексу.
  Color playerColorDark(int player) => player == 0 ? p0d : p1d;

  @override
  BlockDuelTheme copyWith({
    ThemeId? id,
    String? label,
    String? sub,
    Brightness? kind,
    String? p0name,
    String? p1name,
    Color? bg,
    Color? bg2,
    Color? panel,
    Color? panel2,
    Color? line,
    Color? ink,
    Color? muted,
    Color? p0,
    Color? p0d,
    Color? p1,
    Color? p1d,
    Color? good,
    Color? bad,
    Color? cell,
    Color? cellLine,
    double? boardRadius,
    double? cardRadius,
    double? btnRadius,
    double? cellRadius,
    double? miniRadius,
    String? fontDisplay,
    String? fontMono,
    FontWeight? displayWeight,
    double? displaySpacingEm,
  }) {
    return BlockDuelTheme(
      id: id ?? this.id,
      label: label ?? this.label,
      sub: sub ?? this.sub,
      kind: kind ?? this.kind,
      p0name: p0name ?? this.p0name,
      p1name: p1name ?? this.p1name,
      bg: bg ?? this.bg,
      bg2: bg2 ?? this.bg2,
      panel: panel ?? this.panel,
      panel2: panel2 ?? this.panel2,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      p0: p0 ?? this.p0,
      p0d: p0d ?? this.p0d,
      p1: p1 ?? this.p1,
      p1d: p1d ?? this.p1d,
      good: good ?? this.good,
      bad: bad ?? this.bad,
      cell: cell ?? this.cell,
      cellLine: cellLine ?? this.cellLine,
      boardRadius: boardRadius ?? this.boardRadius,
      cardRadius: cardRadius ?? this.cardRadius,
      btnRadius: btnRadius ?? this.btnRadius,
      cellRadius: cellRadius ?? this.cellRadius,
      miniRadius: miniRadius ?? this.miniRadius,
      fontDisplay: fontDisplay ?? this.fontDisplay,
      fontMono: fontMono ?? this.fontMono,
      displayWeight: displayWeight ?? this.displayWeight,
      displaySpacingEm: displaySpacingEm ?? this.displaySpacingEm,
    );
  }

  @override
  BlockDuelTheme lerp(ThemeExtension<BlockDuelTheme>? other, double t) {
    if (other is! BlockDuelTheme) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => a + (b - a) * t;
    // Дискретные поля (строки/enum/начертание) переключаются на половине.
    final pick = t < 0.5;
    return BlockDuelTheme(
      id: pick ? id : other.id,
      label: pick ? label : other.label,
      sub: pick ? sub : other.sub,
      kind: pick ? kind : other.kind,
      p0name: pick ? p0name : other.p0name,
      p1name: pick ? p1name : other.p1name,
      bg: c(bg, other.bg),
      bg2: c(bg2, other.bg2),
      panel: c(panel, other.panel),
      panel2: c(panel2, other.panel2),
      line: c(line, other.line),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      p0: c(p0, other.p0),
      p0d: c(p0d, other.p0d),
      p1: c(p1, other.p1),
      p1d: c(p1d, other.p1d),
      good: c(good, other.good),
      bad: c(bad, other.bad),
      cell: c(cell, other.cell),
      cellLine: c(cellLine, other.cellLine),
      boardRadius: d(boardRadius, other.boardRadius),
      cardRadius: d(cardRadius, other.cardRadius),
      btnRadius: d(btnRadius, other.btnRadius),
      cellRadius: d(cellRadius, other.cellRadius),
      miniRadius: d(miniRadius, other.miniRadius),
      fontDisplay: pick ? fontDisplay : other.fontDisplay,
      fontMono: pick ? fontMono : other.fontMono,
      displayWeight: pick ? displayWeight : other.displayWeight,
      displaySpacingEm: d(displaySpacingEm, other.displaySpacingEm),
    );
  }
}

/// Тема `neutral` — тёмная база, янтарь/циан. 1:1 с `THEMES.neutral`.
const BlockDuelTheme neutralTheme = BlockDuelTheme(
  id: ThemeId.neutral,
  label: 'Нейтральная',
  sub: 'тёмная база · янтарь / циан',
  kind: Brightness.dark,
  p0name: 'Ты',
  p1name: 'Бот',
  bg: Color(0xFF0E1116),
  bg2: Color(0xFF0B0E13),
  panel: Color(0xFF161B22),
  panel2: Color(0xFF1C232D),
  line: Color(0xFF2A323D),
  ink: Color(0xFFE7EDF3),
  muted: Color(0xFF8B97A6),
  p0: Color(0xFFFF9D42),
  p0d: Color(0xFFB3661F),
  p1: Color(0xFF36D6E7),
  p1d: Color(0xFF1C8794),
  good: Color(0xFF37D67A),
  bad: Color(0xFFEF5E6B),
  cell: Color(0xFF10151C),
  cellLine: Color(0xFF222C37),
  boardRadius: 18,
  cardRadius: 14,
  btnRadius: 10,
  cellRadius: 5,
  miniRadius: 4,
  fontDisplay: 'BricolageGrotesque',
  fontMono: 'DMMono',
  displayWeight: FontWeight.w800,
  displaySpacingEm: -0.01,
);

/// Тема `candy` — пастель, блёстки. 1:1 с `THEMES.candy`.
/// `panel` — полупрозрачный белый `rgba(255,255,255,0.92)`.
const BlockDuelTheme candyTheme = BlockDuelTheme(
  id: ThemeId.candy,
  label: 'Магия & Карамель',
  sub: 'для самых волшебных · пастель, блёстки',
  kind: Brightness.light,
  p0name: 'Ты',
  p1name: 'Пони-бот',
  bg: Color(0xFFFFEAF6),
  bg2: Color(0xFFF4E6FF),
  panel: Color.fromRGBO(255, 255, 255, 0.92),
  panel2: Color(0xFFFFE1F1),
  line: Color(0xFFE9A3CB),
  ink: Color(0xFF4A235A),
  muted: Color(0xFF7A4A8E),
  p0: Color(0xFFFF4D97),
  p0d: Color(0xFFD8266F),
  p1: Color(0xFF2BBDB8),
  p1d: Color(0xFF0D8E89),
  good: Color(0xFF2DA664),
  bad: Color(0xFFD83258),
  cell: Color(0xFFFFF6FB),
  cellLine: Color(0xFFFFC6E0),
  boardRadius: 26,
  cardRadius: 22,
  btnRadius: 18,
  cellRadius: 9,
  miniRadius: 6,
  fontDisplay: 'Fredoka',
  fontMono: 'Baloo2',
  displayWeight: FontWeight.w700,
  displaySpacingEm: 0,
);

/// Тема `night` — неон-нуар, готика. 1:1 с `THEMES.night`.
const BlockDuelTheme nightTheme = BlockDuelTheme(
  id: ThemeId.night,
  label: 'Ночной Страж',
  sub: 'для отважных · неон-нуар, готика',
  kind: Brightness.dark,
  p0name: 'Ты',
  p1name: 'Тень',
  bg: Color(0xFF070A12),
  bg2: Color(0xFF04060B),
  panel: Color(0xFF0E1422),
  panel2: Color(0xFF141C2E),
  line: Color(0xFF243049),
  ink: Color(0xFFEAF0FF),
  muted: Color(0xFF6F80A3),
  p0: Color(0xFFFFD23F),
  p0d: Color(0xFFC79410),
  p1: Color(0xFF3AA6FF),
  p1d: Color(0xFF1C6FD0),
  good: Color(0xFF39E88A),
  bad: Color(0xFFFF3B5C),
  cell: Color(0xFF0B1120),
  cellLine: Color(0xFF1C2840),
  boardRadius: 6,
  cardRadius: 6,
  btnRadius: 4,
  cellRadius: 2,
  miniRadius: 2,
  fontDisplay: 'Oswald',
  fontMono: 'ShareTechMono',
  displayWeight: FontWeight.w700,
  displaySpacingEm: 0.02,
);

/// Все темы по id (порядок как `THEME_ORDER`: neutral → candy → night).
const Map<ThemeId, BlockDuelTheme> blockDuelThemes = {
  ThemeId.neutral: neutralTheme,
  ThemeId.candy: candyTheme,
  ThemeId.night: nightTheme,
};

/// Порядок перебора тем в переключателе. TS: `THEME_ORDER`.
const List<ThemeId> themeOrder = [
  ThemeId.neutral,
  ThemeId.candy,
  ThemeId.night,
];

/// Собирает `ThemeData` для заданной темы: кладёт [tokens] как расширение и
/// настраивает базовые цвета Material под палитру темы.
ThemeData buildThemeData(BlockDuelTheme tokens) {
  final scheme = ColorScheme.fromSeed(
    seedColor: tokens.p0,
    brightness: tokens.kind,
  ).copyWith(surface: tokens.panel, onSurface: tokens.ink);
  return ThemeData(
    useMaterial3: true,
    brightness: tokens.kind,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.bg,
    fontFamily: tokens.fontDisplay,
    extensions: [tokens],
  );
}
