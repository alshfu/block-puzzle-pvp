/// game_mode_descriptor.dart — реестр игровых режимов платформы (Model-слой).
///
/// За что отвечает файл:
///   Превращает BlockDuel из одной игры в платформу с несколькими режимами
///   поверх общего ядра (ROADMAP Фаза 5). Описывает каждый режим как
///   неизменяемый дескриптор [GameModeDescriptor] (id, заголовок, подпись,
///   иконка-emoji, маршрут go_router, категория, статус готовности) и собирает
///   их в единый каталог [gameModes]. Меню и роутер читают этот каталог, а не
///   хардкодят список режимов в нескольких местах.
///
/// Почему отдельный слой:
///   9×9-дуэль (bot/hotseat/online/arcade) и новые жанры (Memory, Co-op…) живут
///   поверх одного pure-ядра `lib/core/`. Реестр — точка расширения: добавить
///   режим = добавить дескриптор + его модуль в `lib/modes/<id>/`, не трогая
///   работающий код 9×9 и онлайна. Сам файл pure: без UI/IO/BuildContext.
///
/// Соответствие ROADMAP: § 5.1 (архитектурный задел под мультирежимность).
library;

/// Категория режима — для группировки в UI и будущих ladder-листов.
enum GameModeCategory {
  /// Классическая 9×9-дуэль (ядро BlockDuel): бот, hot-seat, онлайн, аркада.
  duel,

  /// Память: воспроизведение раскладки по памяти (solo/duel).
  memory,

  /// Кооперативные/прочие жанры поверх ядра (Co-op Tetris и т.д.).
  coop,

  /// Обучение и сервисные экраны.
  learn,
}

/// Статус готовности режима — чтобы каталог честно отражал, что играбельно.
enum GameModeStatus {
  /// Доступен и стабилен.
  live,

  /// В разработке/бета (показывается, но помечается).
  beta,

  /// Зарезервирован планом, пока недоступен (в UI скрыт или disabled).
  planned,
}

/// Неизменяемое описание одного режима платформы.
class GameModeDescriptor {
  /// Стабильный идентификатор режима (kebab/camel, совпадает с сегментом
  /// маршрута где применимо: `bot`, `memorySolo`, `coop`…).
  final String id;

  /// Иконка-emoji для карточки меню.
  final String icon;

  /// Короткий заголовок («С ботом», «Память: соло»).
  final String title;

  /// Подпись-пояснение под заголовком.
  final String subtitle;

  /// Маршрут go_router для запуска (`/setup/bot`, `/memory`…).
  final String route;

  /// Категория для группировки.
  final GameModeCategory category;

  /// Статус готовности.
  final GameModeStatus status;

  /// Создаёт дескриптор режима.
  const GameModeDescriptor({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.category,
    this.status = GameModeStatus.live,
  });

  /// Доступен ли режим для запуска прямо сейчас.
  bool get isPlayable => status != GameModeStatus.planned;
}

/// Каталог всех режимов платформы (источник правды для меню/роутера).
///
/// Порядок задаёт порядок показа. Существующие 9×9-режимы перечислены первыми
/// (паритет с прежним меню), далее — новые жанры Фазы 5.
const List<GameModeDescriptor> gameModes = [
  GameModeDescriptor(
    id: 'bot',
    icon: '🤖',
    title: 'С ботом',
    subtitle: 'быстрая партия против ИИ',
    route: '/setup/bot',
    category: GameModeCategory.duel,
  ),
  GameModeDescriptor(
    id: 'hotseat',
    icon: '👥',
    title: 'Вдвоём',
    subtitle: 'hot-seat на одном устройстве',
    route: '/setup/hotseat',
    category: GameModeCategory.duel,
  ),
  GameModeDescriptor(
    id: 'arcade',
    icon: '🎯',
    title: 'Аркада',
    subtitle: 'один на доске — на рекорд',
    route: '/game/arcade',
    category: GameModeCategory.duel,
  ),
  GameModeDescriptor(
    id: 'botvbot',
    icon: '🎬',
    title: 'Бот × бот',
    subtitle: 'смотри как ИИ играет с ИИ',
    route: '/setup/botvbot',
    category: GameModeCategory.duel,
  ),
  GameModeDescriptor(
    id: 'memorySolo',
    icon: '🧠',
    title: 'Память: соло',
    subtitle: 'запомни раскладку и собери её',
    route: '/memory',
    category: GameModeCategory.memory,
    status: GameModeStatus.beta,
  ),
  GameModeDescriptor(
    id: 'memoryDuel',
    icon: '🃏',
    title: 'Memory Duel',
    subtitle: 'расставь · запомни · повтори',
    route: '/memory-duel',
    category: GameModeCategory.memory,
    status: GameModeStatus.beta,
  ),
  GameModeDescriptor(
    id: 'coop',
    icon: '🧱',
    title: 'Co-op Tetris',
    subtitle: 'поле 10×20, ходы по очереди',
    route: '/coop',
    category: GameModeCategory.coop,
    status: GameModeStatus.beta,
  ),
  GameModeDescriptor(
    id: 'tutorial',
    icon: '🎓',
    title: 'Обучение',
    subtitle: '5 шагов · награда +50 🪙',
    route: '/tutorial',
    category: GameModeCategory.learn,
  ),
];

/// Находит дескриптор по [id] или возвращает `null`.
GameModeDescriptor? gameModeById(String id) {
  for (final m in gameModes) {
    if (m.id == id) return m;
  }
  return null;
}
