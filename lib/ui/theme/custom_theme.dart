/// custom_theme.dart — пользовательская тема конструктора (Model, pure).
///
/// За что отвечает файл:
///   Модель кастомной темы (ROADMAP § 10.2): берёт базовый пресет (шрифты,
///   радиусы, режим, имена игроков) и переопределяет палитру (фон/панель/текст/
///   цвета игроков/акценты). [toTokens] собирает полноценный [BlockDuelTheme]
///   через `copyWith` базы, поэтому кастомная тема совместима со всем UI.
///   (Де)сериализуется в JSON (цвета — int ARGB). Чистая: без UI/IO. Сетевая
///   публикация в маркетплейс с модерацией — серверная надстройка (🔒).
///
/// Соответствие ROADMAP: § 10.2 (конструктор тем).
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Затемнение цвета [c] на долю [t] (для производных p0d/p1d).
Color _darken(Color c, [double t = 0.32]) => Color.lerp(c, Colors.black, t)!;

/// Пользовательская тема: id, имя, базовый пресет и переопределённая палитра.
class CustomTheme {
  /// Стабильный id (`custom_<n>`).
  final String id;

  /// Отображаемое имя.
  final String label;

  /// Базовый пресет (шрифты/радиусы/режим/имена наследуются от него).
  final ThemeId base;

  // Палитра (ARGB int) — редактируется в конструкторе.
  final int bg;
  final int bg2;
  final int panel;
  final int ink;
  final int p0;
  final int p1;
  final int good;

  /// Создаёт кастомную тему.
  const CustomTheme({
    required this.id,
    required this.label,
    required this.base,
    required this.bg,
    required this.bg2,
    required this.panel,
    required this.ink,
    required this.p0,
    required this.p1,
    required this.good,
  });

  /// Стартовая кастомная тема от базового пресета [base] (палитра = пресет).
  factory CustomTheme.fromBase(String id, String label, ThemeId base) {
    final t = blockDuelThemes[base]!;
    return CustomTheme(
      id: id,
      label: label,
      base: base,
      bg: t.bg.toARGB32(),
      bg2: t.bg2.toARGB32(),
      panel: t.panel.toARGB32(),
      ink: t.ink.toARGB32(),
      p0: t.p0.toARGB32(),
      p1: t.p1.toARGB32(),
      good: t.good.toARGB32(),
    );
  }

  /// Копия с изменёнными полями.
  CustomTheme copyWith({
    String? label,
    ThemeId? base,
    int? bg,
    int? bg2,
    int? panel,
    int? ink,
    int? p0,
    int? p1,
    int? good,
  }) => CustomTheme(
    id: id,
    label: label ?? this.label,
    base: base ?? this.base,
    bg: bg ?? this.bg,
    bg2: bg2 ?? this.bg2,
    panel: panel ?? this.panel,
    ink: ink ?? this.ink,
    p0: p0 ?? this.p0,
    p1: p1 ?? this.p1,
    good: good ?? this.good,
  );

  /// Собирает полноценные токены темы: база + переопределённая палитра. Часть
  /// цветов выводится из выбранных (panel2/line/muted/cell — для связности).
  BlockDuelTheme toTokens() {
    final b = blockDuelThemes[base]!;
    final bgC = Color(bg);
    final panelC = Color(panel);
    final inkC = Color(ink);
    return b.copyWith(
      id: base,
      label: label,
      bg: bgC,
      bg2: Color(bg2),
      panel: panelC,
      panel2: Color.lerp(panelC, inkC, 0.10),
      line: Color.lerp(panelC, inkC, 0.28),
      ink: inkC,
      muted: Color.lerp(inkC, bgC, 0.45),
      p0: Color(p0),
      p0d: _darken(Color(p0)),
      p1: Color(p1),
      p1d: _darken(Color(p1)),
      good: Color(good),
      cell: Color.lerp(bgC, panelC, 0.5),
      cellLine: Color.lerp(panelC, inkC, 0.20),
    );
  }

  /// JSON-представление (цвета — int ARGB).
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'base': base.name,
    'bg': bg,
    'bg2': bg2,
    'panel': panel,
    'ink': ink,
    'p0': p0,
    'p1': p1,
    'good': good,
  };

  /// Восстанавливает из JSON.
  factory CustomTheme.fromJson(Map<String, dynamic> json) => CustomTheme(
    id: json['id'] as String,
    label: json['label'] as String,
    base: ThemeId.values.byName(json['base'] as String? ?? 'neutral'),
    bg: json['bg'] as int,
    bg2: json['bg2'] as int,
    panel: json['panel'] as int,
    ink: json['ink'] as int,
    p0: json['p0'] as int,
    p1: json['p1'] as int,
    good: json['good'] as int,
  );
}
