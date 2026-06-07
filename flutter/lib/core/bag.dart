/// bag.dart — генератор фигур «7-bag» (порт класса `Bag` из `src/core`).
///
/// За что отвечает файл:
///   Детерминированная выдача фигур: каждый полный цикл из 7 содержит каждую
///   фигуру ровно один раз (fairness), порядок внутри цикла задаётся
///   перетасовкой [Mulberry32]. [Bag.draw] выдаёт фигуру по порядку,
///   [Bag.drawAvoiding] локально приоритизирует разнообразие в руке, сохраняя
///   7-bag fairness. Порядок выдачи обязан совпадать с TS бит-в-бит.
///
/// Соответствие TS:
///   shuffle / class Bag (next/draw/drawAvoiding/makePiece) → этот файл.
library;

import 'pieces.dart';
import 'rng.dart';
import 'types.dart';

/// Перетасовка Фишера–Йетса с использованием [rng]. Возвращает НОВЫЙ список,
/// не мутируя исходный. Формула индекса (`floor(rng()*(i+1))`) идентична TS —
/// от неё зависит детерминизм всей выдачи.
List<PieceType> _shuffle(List<PieceType> source, RandomSource rng) {
  final a = List<PieceType>.from(source);
  for (int i = a.length - 1; i > 0; i--) {
    final j = (rng() * (i + 1)).floor();
    final tmp = a[i];
    a[i] = a[j];
    a[j] = tmp;
  }
  return a;
}

/// Мешок фигур «7-bag». Хранит очередь текущего мешка, источник случайности и
/// счётчик для уникальных id экземпляров. Состояние сериализуемо ([queueSnapshot]
/// / [counter] / [rngState]) для детерминистичного resume сохранёнок.
class Bag {
  /// Очередь текущего (недовыданного) мешка.
  final List<PieceType> _queue = [];

  /// Генератор случайности (mulberry32 от seed) — хранится как объект, чтобы
  /// можно было снять/восстановить его внутреннее состояние.
  final Mulberry32 _rng;

  /// Счётчик выданных фигур — основа уникального id (`p0`, `p1`, …).
  int _counter = 0;

  /// Создаёт мешок от целочисленного [seed].
  Bag(int seed) : _rng = Mulberry32(seed);

  /// Восстанавливает мешок из снятого состояния (resume сохранёнки): очередь
  /// [queue], счётчик [counter] и состояние PRNG [rngState].
  Bag.fromState({
    required List<PieceType> queue,
    required int counter,
    required int rngState,
  }) : _rng = Mulberry32.fromState(rngState) {
    _counter = counter;
    _queue.addAll(queue);
  }

  /// Снимок очереди текущего мешка (для сериализации).
  List<PieceType> get queueSnapshot => List.unmodifiable(_queue);

  /// Текущее значение счётчика id (для сериализации).
  int get counter => _counter;

  /// Внутреннее состояние PRNG (для сериализации).
  int get rngState => _rng.state;

  /// Возвращает следующий тип фигуры; при опустошении очереди перетасовывает
  /// новый полный мешок из всех 7 типов. TS: `Bag.next`.
  PieceType _next() {
    if (_queue.isEmpty) {
      _queue.addAll(_shuffle(allTypes, _rng.next));
    }
    return _queue.removeAt(0);
  }

  /// Выдаёт очередной экземпляр фигуры. TS: `Bag.draw`.
  PieceInstance draw() => _makePiece(_next());

  /// Выдаёт фигуру, по возможности не входящую в [avoidTypes]: ищет в очереди
  /// первый не-конфликтующий тип и берёт его; если таких нет — берёт верх
  /// очереди как есть. Сохраняет 7-bag fairness. TS: `Bag.drawAvoiding`.
  PieceInstance drawAvoiding(Set<PieceType> avoidTypes) {
    if (_queue.isEmpty) {
      _queue.addAll(_shuffle(allTypes, _rng.next));
    }
    final idx = _queue.indexWhere((t) => !avoidTypes.contains(t));
    if (idx == -1) {
      // Вся очередь — конфликтующие типы (или avoidTypes покрыл все 7).
      return draw();
    }
    final type = _queue.removeAt(idx);
    return _makePiece(type);
  }

  /// Создаёт экземпляр фигуры заданного типа с уникальным id и нормализованными
  /// клетками. TS: `Bag.makePiece`.
  PieceInstance _makePiece(PieceType type) => PieceInstance(
    id: 'p${_counter++}',
    type: type,
    cells: normalize(baseShapes[type]!),
  );
}
