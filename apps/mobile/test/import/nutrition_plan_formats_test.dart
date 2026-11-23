import 'dart:io';

import 'package:anfybio/domain/nutrition.dart';
import 'package:anfybio/import/nutrition_plan_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Formatos de plan menos comunes, con datos inventados: encabezados con
/// emoji, fracciones, alternativas que cruzan renglones, recomendaciones al
/// final y comidas con sus alimentos en el mismo renglón.
void main() {
  ParsedNutritionPlan read(String fixture) =>
      parseNutritionPlan(File('test/fixtures/$fixture').readAsStringSync());

  group('varios formatos', () {
    late ParsedNutritionPlan parsed;
    setUp(() => parsed = read('plan_alimentacion_formatos_varios.txt'));

    List<ItemDraft> items(DayType type, String meal) => parsed.draft.menus
        .singleWhere((m) => m.dayType == type)
        .meals
        .singleWhere((m) => m.name == meal)
        .items;

    test('"mayor" y "menor demanda" son días alto y bajo', () {
      expect(parsed.draft.menus.map((m) => m.dayType), [
        DayType.high,
        DayType.low,
      ]);
      expect(parsed.warnings, isEmpty);
    });

    test('las recomendaciones del final no son comidas', () {
      expect(parsed.draft.menus.last.meals.map((m) => m.name), [
        'Desayuno',
        'Cena',
      ]);
      expect(
        parsed.draft.weighingNotes,
        'Claves para el mes\n\n'
        'Pesarse en ayunas: cada lunes, antes de desayunar.\n\n'
        'Dormir bien.',
      );
    });

    test('fracciones, medidas y paréntesis cortados', () {
      final breakfast = items(DayType.high, 'Desayuno');
      expect(breakfast[1].name, 'claras de huevo');
      expect((breakfast[2].name, breakfast[2].amount), ('aguacate', 0.25));
      expect(breakfast[2].unit, FoodUnit.piece);
      final shake = breakfast[3];
      expect(
        (shake.name, shake.unit, shake.note),
        ('proteína en agua', FoodUnit.scoop, null),
      );
    });

    test('un renglón que termina en "o" tiene su alternativa abajo', () {
      final yogurt = items(DayType.high, 'Desayuno')[4];
      expect(yogurt.name, 'yogur natural');
      expect(yogurt.alternatives.single.name, 'nueces');
    });

    test('la alternativa entre paréntesis lleva su condición', () {
      final apple = items(DayType.high, 'Desayuno')[5];
      expect((apple.name, apple.amount), ('manzana', 0.5));
      final oats = apple.alternatives.single;
      expect((oats.name, oats.amount, oats.note), ('avena', 20, 'Si entrenas'));
    });

    test('"al gusto" es libre', () {
      expect(items(DayType.high, 'Desayuno').last.isFree, isTrue);
    });

    test('cantidad al final, platos y estado entre paréntesis', () {
      final [chicken, omelet, hotCakes, oats] = items(DayType.high, 'Comida');
      expect(
        (chicken.name, chicken.amount, chicken.state),
        ('Pollo cocido', 150, FoodState.cooked),
      );
      expect(omelet.name, 'Omelet');
      expect(omelet.ingredients.map((i) => i.name), [
        'huevo entero',
        'claras con champiñones',
      ]);
      expect(hotCakes.name, 'Hot cakes');
      expect(hotCakes.ingredients.map((i) => i.name), [
        'huevo',
        'avena y canela',
      ]);
      expect((oats.state, oats.warning), (FoodState.dry, null));
    });

    test('nada queda por revisar', () {
      expect(parsed.warningCount, 0);
    });
  });

  group('comidas en un renglón', () {
    late ParsedNutritionPlan parsed;
    setUp(() => parsed = read('plan_alimentacion_en_linea.txt'));

    test('más y menos carbohidratos, con el paréntesis en el título', () {
      expect(parsed.draft.menus.map((m) => (m.dayType, m.title)), [
        (DayType.high, 'Días de Más Carbohidratos (Pierna y Espalda)'),
        (DayType.low, 'Días de Menos Carbohidratos (Descanso)'),
      ]);
    });

    test('el nombre de la comida y sus alimentos', () {
      final [breakfast, lunch, dinner] = parsed.draft.menus.first.meals;
      expect(breakfast.name, 'Desayuno');
      expect(breakfast.items.map((i) => i.name), [
        'huevos enteros',
        'avena',
        'canela',
      ]);
      expect(lunch.items.map((i) => i.name), ['pollo', 'Ensalada', 'arroz']);
      expect(lunch.items.first.state, FoodState.raw);
      expect(lunch.items.last.alternatives.single.name, 'papa');
      // "a las 8: 30 g": los dos puntos después de una hora no separan.
      expect(dinner.name, 'Cena a las 8');
    });

    test('suplementos numerados con "Cuándo", sin el título de sección', () {
      final supplements = parsed.draft.supplements;
      expect(supplements.map((s) => s.name), ['Creatina', 'Omega 3']);
      expect(
        supplements.first.timing,
        '5g a cualquier hora, después de entrenar.',
      );
    });
  });
}
