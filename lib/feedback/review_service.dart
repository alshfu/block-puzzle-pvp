/// review_service.dart — абстракция похода в стор за оценкой (§ 11.5).
///
/// За что отвечает файл:
///   Прячет платформенный вызов нативного диалога оценки (App Store / Google
///   Play / RuStore in-app review). Сейчас подключён честный no-op-стаб
///   [NoopReviewService]: сторы и их review-API ещё не подключены (🔒). Когда
///   появятся — реализация-провайдер подменяется, а UI запроса оценки не
///   меняется.
///
/// Соответствие ROADMAP: § 11.5 (in-app rating prompt; submission — 🔒).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Интерфейс запроса нативной оценки приложения.
abstract interface class ReviewService {
  /// Доступен ли нативный review-API (подключён ли стор).
  bool get available;

  /// Запрашивает нативный диалог оценки (если доступен).
  Future<void> requestReview();
}

/// Честный стаб: нативный review-API не подключён.
class NoopReviewService implements ReviewService {
  /// Создаёт стаб.
  const NoopReviewService();

  @override
  bool get available => false;

  @override
  Future<void> requestReview() async {/* стор не подключён — § 11.5 (🔒) */}
}

/// Провайдер review-сервиса. Подменяется на реальный при подключении сторов.
final reviewServiceProvider = Provider<ReviewService>(
  (ref) => const NoopReviewService(),
);
