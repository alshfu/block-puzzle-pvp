/// opening_hand.dart — гарантия валидного стартового hand'а (ROADMAP § 8.3).
///
/// За что отвечает файл:
///   Раздаёт стартовую руку так, чтобы у игрока заведомо был хотя бы один
///   легальный ход (особенно важно для новичков ≤ 10 уровня — никаких «мёртвых»
///   стартов). На пустой доске любая одиночная фигура помещается, поэтому это
///   прежде всего защитная проверка: если по какой-то причине рука без ходов —
///   перераздаём из того же мешка до [maxRerolls] раз. Использует примитивы
///   ядра, но живёт в game-слое (не в parity-связанном `lib/core/`), чтобы не
///   трогать bit-for-bit паритет с TS.
///
/// Соответствие ROADMAP: § 8.3 (валидный hand новичкам ≤ 10).
library;

import 'package:block_duel/core/core.dart';

/// Максимум попыток перераздачи, если рука без ходов.
const int openingHandMaxRerolls = 3;

/// Раздаёт из [bag] руку из [k] фигур (анти-дубль типов в руке), гарантируя на
/// доске [board] хотя бы один легальный ход при правилах [cfg]. Если рука dead —
/// перераздаёт до [maxRerolls] раз (мешок stateful: каждая попытка тянет дальше).
/// Возвращает последнюю руку даже если все попытки исчерпаны (контракт «вернуть
/// что-то играбельное по возможности»).
List<PieceInstance> dealOpeningHand(
  Bag bag,
  int k,
  Board board,
  RuleConfig cfg, {
  int maxRerolls = openingHandMaxRerolls,
}) {
  List<PieceInstance> hand = _dealOnce(bag, k);
  var attempts = 0;
  while (!hasAnyMove(board, hand, cfg) && attempts < maxRerolls) {
    hand = _dealOnce(bag, k);
    attempts++;
  }
  return hand;
}

/// Одна раздача [k] фигур с анти-дублированием типов в руке.
List<PieceInstance> _dealOnce(Bag bag, int k) {
  final hand = <PieceInstance>[];
  for (int i = 0; i < k; i++) {
    hand.add(bag.drawAvoiding(hand.map((p) => p.type).toSet()));
  }
  return hand;
}
