/// settings.dart — модель пользовательских настроек (Model-слой).
///
/// За что отвечает файл:
///   Неизменяемые настройки приложения и их (де)сериализация в JSON: звук/
///   музыка (вкл + громкость), вибрация, тогглы анимаций (конфетти/маскоты/
///   уменьшение движения), подсветка-призрак, задержка бота и параметры матча
///   по умолчанию (для SetupScreen). Тема хранится отдельно (ThemeController).
///
/// Все поля имеют дефолты в [fromJson] — старый JSON читается без потерь.
///
/// Соответствие TS: `src/ui/storage/settings.ts`.
library;

/// Интенсивность вибрации (тач-устройства; на web — no-op).
enum VibrationMode { off, light, strong }

/// Неизменяемые пользовательские настройки.
class Settings {
  /// Включены ли звуковые эффекты.
  final bool soundOn;

  /// Громкость эффектов (0..1).
  final double soundVolume;

  /// Включена ли фоновая музыка.
  final bool musicOn;

  /// Громкость музыки (0..1).
  final double musicVolume;

  /// Уменьшать ли анимации (доступность).
  final bool reduceMotion;

  /// Показывать конфетти на perfect clear.
  final bool confettiEnabled;

  /// Показывать декоративных маскотов/пони.
  final bool mascotsEnabled;

  /// Подсвечивать цель постановки (призрак фигуры).
  final bool ghostEnabled;

  /// Вибрация.
  final VibrationMode vibration;

  /// Задержка хода бота, мс (читаемость хода).
  final int botDelayMs;

  /// Уровень бота по умолчанию (SetupScreen): easy/medium/hard.
  final String defaultBotLevel;

  /// Повороты по умолчанию.
  final bool defaultRotation;

  /// Отражения по умолчанию.
  final bool defaultFlip;

  /// Размер руки по умолчанию (1..3).
  final int defaultHandSize;

  /// Блиц-таймер по умолчанию.
  final bool defaultBlitz;

  /// Пресет блица по умолчанию (hardcore/normal/casual).
  final String defaultBlitzPreset;

  /// Создаёт настройки. Базовые тумблеры обязательны; расширенные поля имеют
  /// дефолты (обратная совместимость с местами, где задаются лишь базовые).
  const Settings({
    required this.soundOn,
    required this.musicOn,
    required this.reduceMotion,
    this.soundVolume = 0.7,
    this.musicVolume = 0.5,
    this.confettiEnabled = true,
    this.mascotsEnabled = true,
    this.ghostEnabled = true,
    this.vibration = VibrationMode.light,
    this.botDelayMs = 350,
    this.defaultBotLevel = 'medium',
    this.defaultRotation = true,
    this.defaultFlip = true,
    this.defaultHandSize = 3,
    this.defaultBlitz = true,
    this.defaultBlitzPreset = 'normal',
  });

  /// Настройки по умолчанию.
  static const Settings initial = Settings(
    soundOn: true,
    soundVolume: 0.7,
    musicOn: true,
    musicVolume: 0.5,
    reduceMotion: false,
    confettiEnabled: true,
    mascotsEnabled: true,
    ghostEnabled: true,
    vibration: VibrationMode.light,
    botDelayMs: 350,
    defaultBotLevel: 'medium',
    defaultRotation: true,
    defaultFlip: true,
    defaultHandSize: 3,
    defaultBlitz: true,
    defaultBlitzPreset: 'normal',
  );

  /// Копия с изменёнными полями.
  Settings copyWith({
    bool? soundOn,
    double? soundVolume,
    bool? musicOn,
    double? musicVolume,
    bool? reduceMotion,
    bool? confettiEnabled,
    bool? mascotsEnabled,
    bool? ghostEnabled,
    VibrationMode? vibration,
    int? botDelayMs,
    String? defaultBotLevel,
    bool? defaultRotation,
    bool? defaultFlip,
    int? defaultHandSize,
    bool? defaultBlitz,
    String? defaultBlitzPreset,
  }) => Settings(
    soundOn: soundOn ?? this.soundOn,
    soundVolume: soundVolume ?? this.soundVolume,
    musicOn: musicOn ?? this.musicOn,
    musicVolume: musicVolume ?? this.musicVolume,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    confettiEnabled: confettiEnabled ?? this.confettiEnabled,
    mascotsEnabled: mascotsEnabled ?? this.mascotsEnabled,
    ghostEnabled: ghostEnabled ?? this.ghostEnabled,
    vibration: vibration ?? this.vibration,
    botDelayMs: botDelayMs ?? this.botDelayMs,
    defaultBotLevel: defaultBotLevel ?? this.defaultBotLevel,
    defaultRotation: defaultRotation ?? this.defaultRotation,
    defaultFlip: defaultFlip ?? this.defaultFlip,
    defaultHandSize: defaultHandSize ?? this.defaultHandSize,
    defaultBlitz: defaultBlitz ?? this.defaultBlitz,
    defaultBlitzPreset: defaultBlitzPreset ?? this.defaultBlitzPreset,
  );

  /// JSON-представление.
  Map<String, dynamic> toJson() => {
    'soundOn': soundOn,
    'soundVolume': soundVolume,
    'musicOn': musicOn,
    'musicVolume': musicVolume,
    'reduceMotion': reduceMotion,
    'confettiEnabled': confettiEnabled,
    'mascotsEnabled': mascotsEnabled,
    'ghostEnabled': ghostEnabled,
    'vibration': vibration.name,
    'botDelayMs': botDelayMs,
    'defaultBotLevel': defaultBotLevel,
    'defaultRotation': defaultRotation,
    'defaultFlip': defaultFlip,
    'defaultHandSize': defaultHandSize,
    'defaultBlitz': defaultBlitz,
    'defaultBlitzPreset': defaultBlitzPreset,
  };

  /// Восстанавливает настройки из JSON; отсутствующие поля — из [initial].
  factory Settings.fromJson(Map<String, dynamic> json) {
    const d = Settings.initial;
    return Settings(
      soundOn: json['soundOn'] as bool? ?? d.soundOn,
      soundVolume: (json['soundVolume'] as num?)?.toDouble() ?? d.soundVolume,
      musicOn: json['musicOn'] as bool? ?? d.musicOn,
      musicVolume: (json['musicVolume'] as num?)?.toDouble() ?? d.musicVolume,
      reduceMotion: json['reduceMotion'] as bool? ?? d.reduceMotion,
      confettiEnabled: json['confettiEnabled'] as bool? ?? d.confettiEnabled,
      mascotsEnabled: json['mascotsEnabled'] as bool? ?? d.mascotsEnabled,
      ghostEnabled: json['ghostEnabled'] as bool? ?? d.ghostEnabled,
      vibration:
          VibrationMode.values
              .where((v) => v.name == json['vibration'])
              .firstOrNull ??
          d.vibration,
      botDelayMs: (json['botDelayMs'] as num?)?.toInt() ?? d.botDelayMs,
      defaultBotLevel: json['defaultBotLevel'] as String? ?? d.defaultBotLevel,
      defaultRotation: json['defaultRotation'] as bool? ?? d.defaultRotation,
      defaultFlip: json['defaultFlip'] as bool? ?? d.defaultFlip,
      defaultHandSize:
          (json['defaultHandSize'] as num?)?.toInt() ?? d.defaultHandSize,
      defaultBlitz: json['defaultBlitz'] as bool? ?? d.defaultBlitz,
      defaultBlitzPreset:
          json['defaultBlitzPreset'] as String? ?? d.defaultBlitzPreset,
    );
  }
}
