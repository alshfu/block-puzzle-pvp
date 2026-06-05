/// settings.dart — модель пользовательских настроек (Model-слой).
///
/// За что отвечает файл:
///   Неизменяемые флаги настроек (звук, музыка, уменьшение анимаций) и их
///   (де)сериализация в JSON. Тема хранится отдельно (ThemeController).
///
/// Соответствие TS: `src/ui/storage/settings.ts`.
library;

/// Неизменяемые пользовательские настройки.
class Settings {
  /// Включены ли звуковые эффекты.
  final bool soundOn;

  /// Включена ли фоновая музыка.
  final bool musicOn;

  /// Уменьшать ли анимации (доступность).
  final bool reduceMotion;

  /// Создаёт настройки.
  const Settings({
    required this.soundOn,
    required this.musicOn,
    required this.reduceMotion,
  });

  /// Настройки по умолчанию.
  static const Settings initial = Settings(
    soundOn: true,
    musicOn: true,
    reduceMotion: false,
  );

  /// Копия с изменёнными полями.
  Settings copyWith({bool? soundOn, bool? musicOn, bool? reduceMotion}) =>
      Settings(
        soundOn: soundOn ?? this.soundOn,
        musicOn: musicOn ?? this.musicOn,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );

  /// JSON-представление.
  Map<String, dynamic> toJson() => {
    'soundOn': soundOn,
    'musicOn': musicOn,
    'reduceMotion': reduceMotion,
  };

  /// Восстанавливает настройки из JSON.
  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
    soundOn: json['soundOn'] as bool? ?? true,
    musicOn: json['musicOn'] as bool? ?? true,
    reduceMotion: json['reduceMotion'] as bool? ?? false,
  );
}
