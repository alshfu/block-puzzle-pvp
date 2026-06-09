/// skins.dart — каталог скинов клеток доски (Model-данные).
///
/// За что отвечает файл:
///   Описывает косметические скины доски (id/название/описание/иконка/цена в
///   монетах/стиль) — порт `src/ui/shop/skins.ts`. Стиль применяется при
///   отрисовке клеток ([board_game.dart]).
///
/// Соответствие TS: `src/ui/shop/skins.ts`.
library;

/// Визуальный стиль клетки.
enum SkinStyle { plain, gem, bullet, neon, pixel, candy }

/// Описание скина.
class SkinDef {
  /// Идентификатор (`default`/`gem`/…).
  final String id;

  /// Название.
  final String name;

  /// Описание.
  final String description;

  /// Эмодзи для превью.
  final String icon;

  /// Цена в монетах (0 — бесплатно, по умолчанию разблокирован).
  final int price;

  /// Стиль отрисовки клеток.
  final SkinStyle style;

  const SkinDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.price,
    required this.style,
  });
}

/// Каталог скинов (порт TS `SKINS`).
const List<SkinDef> skinDefs = [
  SkinDef(
    id: 'default',
    name: 'Базовый',
    description: 'Глянцевый градиент в фирменных цветах темы',
    icon: '🧱',
    price: 0,
    style: SkinStyle.plain,
  ),
  SkinDef(
    id: 'gem',
    name: 'Самоцветы',
    description: 'Гранёные камни с бликом',
    icon: '💎',
    price: 80,
    style: SkinStyle.gem,
  ),
  SkinDef(
    id: 'candy',
    name: 'Карамель',
    description: 'Глянцевые конфеты-леденцы',
    icon: '🍬',
    price: 90,
    style: SkinStyle.candy,
  ),
  SkinDef(
    id: 'pixel',
    name: 'Пиксели',
    description: 'Угловатые ретро-блоки с пиксельной обводкой',
    icon: '🟧',
    price: 100,
    style: SkinStyle.pixel,
  ),
  SkinDef(
    id: 'bullet',
    name: 'Пули',
    description: 'Холодный металл, лёгкая текстура',
    icon: '🔫',
    price: 120,
    style: SkinStyle.bullet,
  ),
  SkinDef(
    id: 'neon',
    name: 'Неон',
    description: 'Подсвеченные неоновые блоки с послесвечением',
    icon: '💡',
    price: 150,
    style: SkinStyle.neon,
  ),
];

/// Скины по id.
final Map<String, SkinDef> skinsById = {for (final s in skinDefs) s.id: s};

/// Стиль скина по id (или [SkinStyle.plain]).
SkinStyle skinStyleOf(String id) => skinsById[id]?.style ?? SkinStyle.plain;
