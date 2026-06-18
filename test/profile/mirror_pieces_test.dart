/// mirror_pieces_test.dart — тесты зеркального набора фигур (ROADMAP § 8.5).
///
/// Проверяют отображение типов (S↔Z, J↔L; I/O/T самосимметричны), его
/// инволютивность (двойное зеркало = исходник) и совпадение зеркальной формы с
/// базовой формой соответствующего «зеркального» типа.
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/profile/mirror_pieces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('отображение типов: S↔Z, J↔L, I/O/T в себя', () {
    expect(mirrorOf(PieceType.s), PieceType.z);
    expect(mirrorOf(PieceType.z), PieceType.s);
    expect(mirrorOf(PieceType.j), PieceType.l);
    expect(mirrorOf(PieceType.l), PieceType.j);
    expect(mirrorOf(PieceType.i), PieceType.i);
    expect(mirrorOf(PieceType.o), PieceType.o);
    expect(mirrorOf(PieceType.t), PieceType.t);
  });

  test('зеркало — инволюция (двойное применение = исходник)', () {
    for (final t in allTypes) {
      expect(mirrorOf(mirrorOf(t)), t);
    }
  });

  test('самосимметричны ровно I/O/T', () {
    expect(isSelfMirror(PieceType.i), isTrue);
    expect(isSelfMirror(PieceType.o), isTrue);
    expect(isSelfMirror(PieceType.t), isTrue);
    expect(isSelfMirror(PieceType.s), isFalse);
    expect(isSelfMirror(PieceType.z), isFalse);
    expect(isSelfMirror(PieceType.j), isFalse);
    expect(isSelfMirror(PieceType.l), isFalse);
  });

  test('зеркальная форма S совпадает с базовой формой Z', () {
    expect(
      mirrorShape(PieceType.s).toString(),
      normalize(baseShapes[PieceType.z]!).toString(),
    );
  });

  test('зеркальная форма J совпадает с базовой формой L', () {
    expect(
      mirrorShape(PieceType.j).toString(),
      normalize(baseShapes[PieceType.l]!).toString(),
    );
  });
}
