import 'package:anfybio/domain/load_mode.dart';
import 'package:anfybio/domain/weight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String text(double w, WeightUnit u, LoadMode m) =>
      formatLoad(w, u, m, number: (v) => v.toStringAsFixed(0));

  test('cada forma de medir se lee distinto', () {
    expect(text(60, WeightUnit.kg, LoadMode.total), '60 kg');
    expect(text(20, WeightUnit.kg, LoadMode.perHand), '20 kg c/u');
    expect(text(45, WeightUnit.lb, LoadMode.perSide), '45 lb por lado');
    expect(text(10, WeightUnit.kg, LoadMode.bodyweight), '+10 kg');
    expect(text(0, WeightUnit.kg, LoadMode.bodyweight), 'Peso corporal');
  });

  test('el total cuenta las dos mancuernas y los dos lados', () {
    expect(totalLoadKg(60, WeightUnit.kg, LoadMode.total), 60);
    expect(totalLoadKg(20, WeightUnit.kg, LoadMode.perHand), 40);
    expect(totalLoadKg(50, WeightUnit.kg, LoadMode.perSide), 100);
    expect(
      totalLoadKg(45, WeightUnit.lb, LoadMode.perSide),
      closeTo(40.82, 0.01),
    );
  });

  test('con peso corporal, el total necesita conocerlo', () {
    expect(totalLoadKg(10, WeightUnit.kg, LoadMode.bodyweight), isNull);
    expect(
      totalLoadKg(10, WeightUnit.kg, LoadMode.bodyweight, bodyweightKg: 70),
      80,
    );
  });

  test('sin elegir, se deduce del equipo del catálogo', () {
    expect(loadModeForEquipment('dumbbell'), LoadMode.perHand);
    expect(loadModeForEquipment('kettlebells'), LoadMode.perHand);
    expect(loadModeForEquipment('body only'), LoadMode.bodyweight);
    expect(loadModeForEquipment('barbell'), LoadMode.total);
    expect(loadModeForEquipment('machine'), LoadMode.total);
    expect(loadModeForEquipment(null), LoadMode.total);
  });

  test('la cifra del 1RM conserva su significado', () {
    expect(loadModeSuffix(LoadMode.total), '');
    expect(loadModeSuffix(LoadMode.perHand), ' c/u');
    expect(loadModeSuffix(LoadMode.bodyweight), ' de lastre');
  });
}
