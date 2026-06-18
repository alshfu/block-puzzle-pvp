/// purchase_service.dart — абстракция покупки кристаллов (ViewModel-граница).
///
/// За что отвечает файл:
///   Единый интерфейс совершения IAP-покупки пакета кристаллов (ROADMAP § 10.1),
///   за которым прячется конкретный платёжный провайдер. Сейчас подключён
///   честный «незаглушённый» стаб [UnavailablePurchaseService]: магазин ещё не
///   связан с RuStore/App Store/Play/Stripe, а покупки ОБЯЗАНЫ проходить
///   серверную валидацию чека (анти-fraud) — это серверная надстройка (🔒).
///   Когда провайдер появится, его реализация подменяется в провайдере, а UI
///   магазина не меняется.
///
/// Соответствие ROADMAP: § 10.1 (IAP; реальная оплата + валидация чека — 🔒).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Итог попытки покупки.
enum PurchaseStatus {
  /// Успех (кристаллы начислены после валидации).
  success,

  /// Отменено пользователем.
  cancelled,

  /// Платёжный провайдер недоступен (стор не подключён).
  unavailable,

  /// Ошибка/неуспешная валидация.
  failed,
}

/// Результат покупки: статус + (для успеха) сколько кристаллов начислить.
class PurchaseResult {
  /// Статус.
  final PurchaseStatus status;

  /// Сколько кристаллов начислить при успехе (0 иначе).
  final int crystals;

  /// Создаёт результат.
  const PurchaseResult(this.status, {this.crystals = 0});
}

/// Интерфейс совершения покупки пакета по [packId].
abstract interface class PurchaseService {
  /// Доступна ли оплата (подключён ли платёжный провайдер).
  bool get available;

  /// Совершает покупку пакета [packId]. Реализация-провайдер запускает поток
  /// оплаты и (после серверной валидации чека) возвращает [PurchaseResult].
  Future<PurchaseResult> buy(String packId);
}

/// Честный стаб: оплата не подключена (стор/серверная валидация — 🔒).
class UnavailablePurchaseService implements PurchaseService {
  /// Создаёт стаб.
  const UnavailablePurchaseService();

  @override
  bool get available => false;

  @override
  Future<PurchaseResult> buy(String packId) async =>
      const PurchaseResult(PurchaseStatus.unavailable);
}

/// Провайдер платёжного сервиса. Подменяется на реального провайдера, когда
/// будет подключён стор + серверная валидация чека.
final purchaseServiceProvider = Provider<PurchaseService>(
  (ref) => const UnavailablePurchaseService(),
);
