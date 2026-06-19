/// notification_prefs.dart — настройки push-уведомлений (Model, pure).
///
/// За что отвечает файл:
///   Хранит opt-in пользователя по push-уведомлениям (ROADMAP § 11.2): мастер-
///   тумблер + категории (приглашение от друга, старт сезона, ход соперника,
///   напоминание о ежедневках). Это локальные предпочтения, которыми будет
///   управляться доставка, когда подключим FCM/APNs (серверная часть — 🔒).
///   Чистая модель: значения + (де)сериализация, без UI/IO.
///
/// Соответствие ROADMAP: § 11.2 (opt-in management в Settings).
library;

/// Категория уведомления.
enum NotificationKind {
  /// Приглашение в матч от друга.
  invite,

  /// Старт нового сезона / сезонного пропуска.
  season,

  /// Ход соперника в онлайн-матче.
  opponentMove,

  /// Напоминание о ежедневных заданиях.
  dailyReminder,
}

/// Предпочтения уведомлений: мастер-тумблер + набор включённых категорий.
class NotificationPrefs {
  /// Мастер-тумблер (если выключен — не слать ничего).
  final bool enabled;

  /// Включённые категории.
  final Set<NotificationKind> kinds;

  /// Создаёт предпочтения.
  const NotificationPrefs({required this.enabled, required this.kinds});

  /// По умолчанию: всё включено (пользователь сам отключает ненужное).
  static const NotificationPrefs initial = NotificationPrefs(
    enabled: true,
    kinds: {
      NotificationKind.invite,
      NotificationKind.season,
      NotificationKind.opponentMove,
      NotificationKind.dailyReminder,
    },
  );

  /// Реально ли доставлять уведомление категории [kind] (мастер + категория).
  bool allows(NotificationKind kind) => enabled && kinds.contains(kind);

  /// Копия с изменениями.
  NotificationPrefs copyWith({bool? enabled, Set<NotificationKind>? kinds}) =>
      NotificationPrefs(
        enabled: enabled ?? this.enabled,
        kinds: kinds ?? this.kinds,
      );

  /// Копия с переключённой категорией [kind].
  NotificationPrefs toggled(NotificationKind kind) {
    final next = {...kinds};
    if (!next.add(kind)) next.remove(kind);
    return copyWith(kinds: next);
  }

  /// JSON-представление.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'kinds': [for (final k in kinds) k.name],
  };

  /// Восстанавливает из JSON (отсутствующие поля — из [initial]).
  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    final list = (json['kinds'] as List?)?.cast<String>();
    return NotificationPrefs(
      enabled: json['enabled'] as bool? ?? initial.enabled,
      kinds: list == null
          ? initial.kinds
          : {
              for (final name in list)
                ...NotificationKind.values.where((k) => k.name == name),
            },
    );
  }
}
