import 'package:anfybio/domain/weight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('los kilogramos no se modifican', () {
    expect(toKg(100, WeightUnit.kg), 100);
  });

  test('convierte libras con el factor exacto', () {
    expect(toKg(1, WeightUnit.lb), 0.45359237);
    expect(toKg(225, WeightUnit.lb), closeTo(102.058, 0.001));
  });

  test('cero sigue siendo cero en cualquier unidad', () {
    expect(toKg(0, WeightUnit.lb), 0);
  });
}
