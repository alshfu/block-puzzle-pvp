/// crystal_packs.dart — каталог пакетов кристаллов для IAP (Model, pure).
///
/// За что отвечает файл:
///   Описывает пакеты премиум-валюты (ROADMAP § 10.1): 100 / 500 / 1500 / 5000
///   кристаллов с растущим бонусом за объём. Чистые данные + расчёт итогового
///   количества ([crystalPackTotal]) и процента бонуса — без UI/IO/платежей.
///   Реальная оплата (RuStore/App Store/Play/Stripe) и серверная валидация чека
///   — отдельный слой [PurchaseService] и серверная надстройка (🔒).
///
/// Цены — НОМИНАЛЬНЫЕ для отображения; фактические задаёт стор по productId.
///
/// Соответствие ROADMAP: § 10.1 (IAP, пакеты кристаллов).
library;

/// Пакет кристаллов.
class CrystalPack {
  /// Стабильный id (он же productId для стора).
  final String id;

  /// Базовое число кристаллов (без бонуса).
  final int baseCrystals;

  /// Бонусные кристаллы за объём.
  final int bonusCrystals;

  /// Номинальная цена для показа (фактическую возвращает стор).
  final String priceLabel;

  /// Помечать ли пакет как «выгодный» (бейдж в UI).
  final bool bestValue;

  /// Создаёт пакет.
  const CrystalPack({
    required this.id,
    required this.baseCrystals,
    required this.bonusCrystals,
    required this.priceLabel,
    this.bestValue = false,
  });

  /// Итог к зачислению (база + бонус).
  int get total => baseCrystals + bonusCrystals;

  /// Процент бонуса (целое, для бейджа «+N%»).
  int get bonusPercent =>
      baseCrystals == 0 ? 0 : (bonusCrystals * 100 / baseCrystals).round();
}

/// Итог к зачислению по пакету (удобный свободный аксессор).
int crystalPackTotal(CrystalPack pack) => pack.total;

/// Каталог пакетов кристаллов (по возрастанию объёма; бонус растёт).
const List<CrystalPack> crystalPacks = [
  CrystalPack(
    id: 'crystals_100',
    baseCrystals: 100,
    bonusCrystals: 0,
    priceLabel: '₽149',
  ),
  CrystalPack(
    id: 'crystals_500',
    baseCrystals: 500,
    bonusCrystals: 50, // +10%
    priceLabel: '₽599',
  ),
  CrystalPack(
    id: 'crystals_1500',
    baseCrystals: 1500,
    bonusCrystals: 300, // +20%
    priceLabel: '₽1490',
  ),
  CrystalPack(
    id: 'crystals_5000',
    baseCrystals: 5000,
    bonusCrystals: 1750, // +35%
    priceLabel: '₽3990',
    bestValue: true,
  ),
];

/// Пакет по id (или `null`).
CrystalPack? crystalPackById(String id) {
  for (final p in crystalPacks) {
    if (p.id == id) return p;
  }
  return null;
}
