import 'package:anfybio/domain/one_rep_max.dart';
import 'package:anfybio/domain/one_rep_max_history.dart';
import 'package:anfybio/domain/weight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SetSample set(
    String sessionId,
    int day, {
    double weight = 100,
    int reps = 5,
    WeightUnit unit = WeightUnit.kg,
    bool isWarmup = false,
  }) => SetSample(
    sessionId: sessionId,
    date: DateTime(2026, 11, day),
    weight: weight,
    unit: unit,
    reps: reps,
    isWarmup: isWarmup,
  );

  test('sin series no hay puntos', () {
    expect(oneRepMaxHistory([]), isEmpty);
  });

  test('cada sesión aporta un punto con su mejor estimación', () {
    final points = oneRepMaxHistory([
      set('a', 1, weight: 100, reps: 5), // 116.67
      set('a', 1, weight: 110, reps: 3), // 121.00 ← mejor de la sesión a
      set('b', 8, weight: 105, reps: 5), // 122.50
    ]);

    expect(points, hasLength(2));
    expect(points[0].kg, closeTo(121, 0.001));
    expect(points[1].kg, closeTo(122.5, 0.001));
  });

  test('los puntos salen en orden cronológico', () {
    final points = oneRepMaxHistory([set('b', 20), set('a', 3), set('c', 11)]);

    expect(points.map((p) => p.date.day), [3, 11, 20]);
  });

  test('el calentamiento no cuenta', () {
    final points = oneRepMaxHistory([
      set('a', 1, weight: 200, reps: 1, isWarmup: true),
      set('a', 1, weight: 100, reps: 5),
    ]);

    expect(points.single.kg, closeTo(116.667, 0.001));
  });

  test('las series de más de 10 repeticiones no cuentan', () {
    final points = oneRepMaxHistory([
      set('a', 1, weight: 100, reps: 20), // daría 166.7: poco confiable
      set('a', 1, weight: 100, reps: 5),
    ]);

    expect(points.single.kg, closeTo(116.667, 0.001));
  });

  test('una sesión sin series válidas no aporta punto', () {
    final points = oneRepMaxHistory([
      set('a', 1, isWarmup: true),
      set('b', 2, reps: 15),
      set('c', 3, weight: 0, reps: 8), // peso corporal
      set('d', 4, reps: 0), // serie fallida
    ]);

    expect(points, isEmpty);
  });

  test('compara en kg aunque las series estén en libras', () {
    final points = oneRepMaxHistory([
      set('a', 1, weight: 225, reps: 5, unit: WeightUnit.lb), // 119.07 kg
      set('a', 1, weight: 100, reps: 5), // 116.67 kg
    ]);

    expect(points.single.kg, closeTo(119.068, 0.001));
  });

  test('la fórmula elegida cambia la estimación', () {
    final sets = [set('a', 1, weight: 100, reps: 5)];

    expect(oneRepMaxHistory(sets).single.kg, closeTo(116.667, 0.001));
    expect(
      oneRepMaxHistory(sets, formula: OneRepMaxFormula.brzycki).single.kg,
      closeTo(112.5, 0.001),
    );
  });
}
