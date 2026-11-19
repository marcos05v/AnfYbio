import 'package:anfybio/domain/cooking.dart';
import 'package:anfybio/domain/nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('factor de rendimiento', () {
    test('cocido ÷ crudo', () {
      expect(yieldFactor(rawG: 1000, cookedG: 720), 0.72);
    });

    test('puede ser mayor que 1 cuando el alimento absorbe agua', () {
      expect(yieldFactor(rawG: 200, cookedG: 520), 2.6);
    });

    test('sin pesos positivos no hay factor', () {
      expect(yieldFactor(rawG: 0, cookedG: 500), isNull);
      expect(yieldFactor(rawG: 500, cookedG: 0), isNull);
      expect(yieldFactor(rawG: -1, cookedG: 500), isNull);
    });
  });

  test('porción cocida = porción en crudo × factor', () {
    expect(
      cookedPortionG(rawPortionG: 130, factor: 0.72),
      closeTo(93.6, 0.001),
    );
    expect(cookedPortionG(rawPortionG: 50, factor: 2.6), closeTo(130, 0.001));
  });

  group('normalizar nombres', () {
    test('quita mayúsculas, acentos y espacios de sobra', () {
      expect(normalizeFood('  Pechuga   de POLLO '), 'pechuga de pollo');
      expect(normalizeFood('Atún'), 'atun');
      expect(normalizeFood('Jalapeño'), 'jalapeno');
    });

    test('quita las aclaraciones entre paréntesis y la puntuación', () {
      expect(normalizeFood('Atún en agua (drenado)'), 'atun en agua');
      expect(normalizeFood('Papa horneada/cocida'), 'papa horneada cocida');
    });
  });

  group('a qué renglones del plan sirve un lote', () {
    bool matches(String batch, String item) =>
        batchMatchesItem(batchFood: batch, itemName: item);

    test('mismo alimento, aunque cambien acentos o mayúsculas', () {
      expect(matches('pechuga de pollo', 'Pechuga de Pollo'), isTrue);
      expect(matches('Atun', 'Atún'), isTrue);
    });

    test('sirve para cualquiera de las alternativas del renglón', () {
      const item = 'Pechuga de pollo o filete de res magro';
      expect(matches('Pechuga de pollo', item), isTrue);
      expect(matches('Filete de res magro', item), isTrue);
      expect(matches('Lomo de cerdo', item), isFalse);
    });

    test('un nombre más corto sirve si son palabras completas', () {
      expect(matches('Pollo', 'Pechuga de pollo'), isTrue);
      expect(matches('Pechuga de pollo', 'Pollo'), isTrue);
    });

    test('no confunde una palabra con parte de otra', () {
      expect(matches('Res', 'Fresas o frutos rojos'), isFalse);
      expect(matches('Pavo', 'Pavorreal'), isFalse);
    });

    test('ignora las aclaraciones entre paréntesis del plan', () {
      expect(matches('Atún en agua', 'Atún en agua (drenado) o pollo'), isTrue);
    });

    test('un nombre vacío no coincide con nada', () {
      expect(matches('', 'Pollo'), isFalse);
      expect(matches('  ', 'Pollo'), isFalse);
    });
  });

  group('porción cocida de un renglón del plan', () {
    const chicken = (
      foodName: 'Pechuga de pollo',
      rawG: 1000.0,
      cookedG: 720.0,
      withOtherIngredients: false,
    );

    CookedServing? serving({
      String itemName = 'Pechuga de pollo o filete de res magro',
      double? amount = 130,
      FoodUnit? unit = FoodUnit.gram,
      FoodState state = FoodState.raw,
      List<BatchInfo> batches = const [chicken],
    }) => cookedServingFor(
      itemName: itemName,
      amount: amount,
      unit: unit,
      state: state,
      batches: batches,
    );

    test('convierte la porción en crudo con el factor del lote', () {
      final result = serving()!;
      expect(result.cookedG, closeTo(93.6, 0.001)); // 130 × 0.72
      expect(result.isApproximate, isFalse);
    });

    test('usa el lote más reciente que corresponda', () {
      final result = serving(
        batches: [
          (
            foodName: 'Arroz',
            rawG: 200.0,
            cookedG: 520.0,
            withOtherIngredients: false,
          ),
          (
            foodName: 'Pollo',
            rawG: 500.0,
            cookedG: 400.0, // el más reciente de pollo: factor 0.8
            withOtherIngredients: false,
          ),
          chicken,
        ],
      )!;
      expect(result.cookedG, closeTo(104, 0.001));
    });

    test('un lote con otros ingredientes da un dato aproximado', () {
      final result = serving(
        batches: [
          (
            foodName: 'Pechuga de pollo',
            rawG: 1000.0,
            cookedG: 900.0,
            withOtherIngredients: true,
          ),
        ],
      )!;
      expect(result.isApproximate, isTrue);
    });

    test('no convierte lo que el plan ya pide cocido o en seco', () {
      expect(serving(state: FoodState.cooked), isNull);
      expect(serving(state: FoodState.dry), isNull);
    });

    test('no convierte a ciegas un alimento sin especificar', () {
      expect(serving(state: FoodState.unspecified), isNull);
    });

    test('solo aplica a cantidades en gramos', () {
      expect(serving(unit: FoodUnit.piece), isNull);
      expect(serving(amount: null), isNull);
      expect(serving(unit: null), isNull);
    });

    test('sin un lote de ese alimento no hay conversión', () {
      expect(serving(itemName: 'Lomo de cerdo'), isNull);
      expect(serving(batches: const []), isNull);
    });
  });

  group('qué servir de un lote según el plan', () {
    const chicken = (
      foodName: 'Pechuga de pollo',
      rawG: 1000.0,
      cookedG: 720.0,
      withOtherIngredients: false,
    );

    PlanPortion portion(
      String mealName,
      String itemName, {
      DayType dayType = DayType.training,
      double? amount = 130,
      FoodUnit? unit = FoodUnit.gram,
      FoodState state = FoodState.raw,
    }) => (
      dayType: dayType,
      mealName: mealName,
      itemName: itemName,
      amount: amount,
      unit: unit,
      state: state,
    );

    test('una fila por cada comida del plan que usa ese alimento', () {
      final servings = batchServings(
        batch: chicken,
        portions: [
          portion('Comida 1', 'Pechuga de pollo o filete de res magro'),
          portion('Comida 2', 'Pechuga de pollo', amount: 120),
          portion('Cena', 'Filete de pescado blanco', amount: 140),
          portion(
            'Cena',
            'Pescado blanco o pechuga de pollo',
            dayType: DayType.rest,
            amount: 160,
          ),
        ],
      );

      expect(
        servings.map((s) => (s.dayType, s.mealName, s.rawG, s.cookedG.round())),
        [
          (DayType.training, 'Comida 1', 130, 94),
          (DayType.training, 'Comida 2', 120, 86),
          (DayType.rest, 'Cena', 160, 115),
        ],
      );
    });

    test('no incluye lo que el plan no pide en crudo o no está en gramos', () {
      final servings = batchServings(
        batch: chicken,
        portions: [
          portion('A', 'Pechuga de pollo', state: FoodState.cooked),
          portion('B', 'Pechuga de pollo', state: FoodState.unspecified),
          portion('C', 'Pechuga de pollo', unit: FoodUnit.piece),
          portion('D', 'Pechuga de pollo', amount: null),
        ],
      );
      expect(servings, isEmpty);
    });

    test('un alimento que el plan no usa no tiene porciones', () {
      expect(
        batchServings(
          batch: chicken,
          portions: [portion('Comida', 'Lomo de cerdo')],
        ),
        isEmpty,
      );
    });
  });
}
