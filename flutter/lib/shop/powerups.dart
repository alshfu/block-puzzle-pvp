/// powerups.dart — каталог power-ups (Model-данные).
///
/// За что отвечает файл:
///   Описывает расходуемые power-ups для одиночных режимов (vs Bot/hot-seat/
///   arcade): id/название/описание/иконка/цена в кристаллах/подсказка. Порт
///   `src/ui/shop/powerups.ts`. В онлайне не используются (server-authoritative).
///
/// Соответствие TS: `src/ui/shop/powerups.ts`.
library;

/// Описание power-up.
class PowerupDef {
  /// Идентификатор (`hint`/`swap_hand`/`stick_row`/…).
  final String id;

  /// Название.
  final String name;

  /// Описание.
  final String description;

  /// Эмодзи-иконка.
  final String icon;

  /// Цена 1 штуки в кристаллах.
  final int price;

  /// Краткая инструкция.
  final String hint;

  const PowerupDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.price,
    required this.hint,
  });
}

/// Каталог power-ups (порт TS `POWERUPS`).
const List<PowerupDef> powerupDefs = [
  PowerupDef(
    id: 'hint',
    name: 'Подсказка',
    description: 'Подсветит лучший ход на 3 секунды',
    icon: '💡',
    price: 1,
    hint: 'тапни и посмотри подсветку',
  ),
  PowerupDef(
    id: 'swap_hand',
    name: 'Обмен руки',
    description: 'Заменит все фигуры в руке на новые',
    icon: '🔄',
    price: 2,
    hint: 'одно нажатие — новая рука',
  ),
  PowerupDef(
    id: 'stick_row',
    name: 'Палочка-молния (строка)',
    description: 'Очищает выбранную строку. Очки идут тебе.',
    icon: '↔️',
    price: 3,
    hint: 'тапни → клетка → строка чистится',
  ),
  PowerupDef(
    id: 'stick_col',
    name: 'Палочка-молния (столбец)',
    description: 'Очищает выбранный столбец. Очки идут тебе.',
    icon: '↕️',
    price: 3,
    hint: 'тапни → клетка → столбец чистится',
  ),
  PowerupDef(
    id: 'bomb_3x3',
    name: 'Бомба 3×3',
    description: 'Очищает квадрат 3×3 вокруг выбранной клетки',
    icon: '💣',
    price: 4,
    hint: 'тапни → центр взрыва → бах',
  ),
  PowerupDef(
    id: 'auto_play',
    name: 'Умный ход',
    description: 'ИИ сам поставит фигуру в лучшее место',
    icon: '🧠',
    price: 5,
    hint: 'одно нажатие — ход за тебя',
  ),
];

/// Power-ups по id.
final Map<String, PowerupDef> powerupsById = {
  for (final p in powerupDefs) p.id: p,
};
