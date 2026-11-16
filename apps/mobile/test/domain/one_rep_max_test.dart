import 'package:anfybio/domain/one_rep_max.dart';
import 'package:anfybio/domain/weight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double? estimate(
    double weight,
    int reps, {
    WeightUnit unit = WeightUnit.kg,
    OneRepMaxFormula formula = OneRepMaxFormula.epley,
  }) => estimateOneRepMaxKg(
    weight: weight,
    unit: unit,
    reps: reps,
    formula: formula,
  );

  group('Epley', () {
    test('100 kg × 5 ≈ 116.67 kg', () {
      expect(estimate(100, 5), closeTo(116.667, 0.001));
    });

    test('100 kg × 10 ≈ 133.33 kg', () {
      expect(estimate(100, 10), closeTo(133.333, 0.001));
    });
  });

  group('Brzycki', () {
    test('100 kg × 5 = 112.5 kg', () {
      expect(
        estimate(100, 5, formula: OneRepMaxFormula.brzycki),
        closeTo(112.5, 0.001),
      );
    });

    test('100 kg × 10 ≈ 133.33 kg: coincide con Epley en 10 repeticiones', () {
      expect(
        estimate(100, 10, formula: OneRepMaxFormula.brzycki),
        closeTo(estimate(100, 10)!, 0.001),
      );
    });

    test('no estima a partir de 37 repeticiones', () {
      expect(estimate(20, 36, formula: OneRepMaxFormula.brzycki), isNotNull);
      expect(estimate(20, 37, formula: OneRepMaxFormula.brzycki), isNull);
      expect(estimate(20, 40, formula: OneRepMaxFormula.brzycki), isNull);
    });
  });

  test('una repetición devuelve el propio peso en ambas fórmulas', () {
    for (final formula in OneRepMaxFormula.values) {
      expect(estimate(140, 1, formula: formula), 140);
    }
  });

  test('convierte libras a kg antes de estimar', () {
    // 225 lb = 102.058 kg; × (1 + 5/30) = 119.068 kg
    expect(estimate(225, 5, unit: WeightUnit.lb), closeTo(119.068, 0.001));
  });

  test('no estima sin repeticiones o sin peso', () {
    expect(estimate(100, 0), isNull);
    expect(estimate(100, -1), isNull);
    expect(estimate(0, 8), isNull);
  });

  test('marca como poco confiables las series de más de 10 repeticiones', () {
    expect(isReliableForOneRepMax(1), isTrue);
    expect(isReliableForOneRepMax(10), isTrue);
    expect(isReliableForOneRepMax(11), isFalse);
    expect(isReliableForOneRepMax(0), isFalse);
  });
}
