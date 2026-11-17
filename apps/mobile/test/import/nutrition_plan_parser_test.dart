import 'dart:io';

import 'package:anfybio/domain/nutrition.dart';
import 'package:anfybio/import/nutrition_plan_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// El archivo de ejemplo imita el formato de un plan real (viñetas,
/// renglones partidos y errores de captura incluidos) con datos inventados.
void main() {
  late ParsedNutritionPlan parsed;
  late NutritionPlanDraft draft;

  setUp(() {
    final text = File('test/fixtures/plan_alimentacion_ejemplo.txt')
        .readAsStringSync();
    parsed = parseNutritionPlan(text, fileName: 'plan.pdf');
    draft = parsed.draft;
  });

  MealDraft meal(DayType dayType, String name) => draft.menus
      .singleWhere((m) => m.dayType == dayType)
      .meals
      .singleWhere((m) => m.name == name);

  ItemDraft item(DayType dayType, String mealName, String itemName) =>
      meal(dayType, mealName).items.singleWhere((i) => i.name == itemName);

  group('estructura', () {
    test('toma el título y el nombre del archivo', () {
      expect(draft.name, 'Plan de alimentación Ejemplo');
      expect(draft.sourceFileName, 'plan.pdf');
    });

    test('reconoce un menú de entrenamiento y otro de descanso', () {
      expect(draft.menus.map((m) => m.dayType), [
        DayType.training,
        DayType.rest,
      ]);
      // "Descanso / Sin Entrenamiento" contiene ambas palabras: es descanso.
      expect(draft.menus.last.title, startsWith('Días de Descanso'));
    });

    test('une las indicaciones de pesaje partidas en dos renglones', () {
      expect(
        draft.weighingNotes,
        'Indicaciones de pesaje: Proteínas pesadas en crudo, carbohidratos '
        '(pasta, arroz) pesados cocidos, avena pesada en seco.',
      );
    });

    test('lee las comidas en orden y sin su número', () {
      expect(draft.menus.first.meals.map((m) => m.name), [
        'Desayuno',
        'Pre-Entreno',
        'Post-Entreno',
        'Comida',
      ]);
      expect(draft.menus.last.meals.map((m) => m.name), [
        'Colación / Comida 1',
        'Comida 2',
        'Cena',
      ]);
    });

    test('separa el horario de una comida aunque venga en tres renglones', () {
      expect(
        meal(DayType.training, 'Pre-Entreno').timingNote,
        '45 min – 1 hora antes de entrenar',
      );
      expect(meal(DayType.training, 'Desayuno').timingNote, isNull);
    });

    test('cada alimento queda en su comida', () {
      expect(meal(DayType.training, 'Desayuno').items, hasLength(5));
      expect(meal(DayType.training, 'Post-Entreno').items, hasLength(2));
      expect(meal(DayType.rest, 'Cena').items, hasLength(5));
    });
  });

  group('cantidades', () {
    test('gramos, piezas y scoops', () {
      final egg = item(DayType.training, 'Desayuno', 'Huevo entero');
      final whites = item(DayType.training, 'Desayuno', 'Claras de huevo');
      expect((egg.amount, egg.unit), (2, FoodUnit.piece));
      expect((whites.amount, whites.unit), (150, FoodUnit.gram));
    });

    test('lo que sigue a la unidad queda como nota', () {
      final apple = item(DayType.training, 'Pre-Entreno', 'Manzana');
      final whey = item(
        DayType.training,
        'Pre-Entreno',
        'Proteína en polvo (Whey)',
      );
      final tortilla = item(DayType.rest, 'Cena', 'Tortilla de maíz');
      expect(
        (apple.amount, apple.unit, apple.note),
        (1, FoodUnit.piece, 'chica'),
      );
      expect((whey.amount, whey.unit, whey.note), (1, FoodUnit.scoop, '30 g'));
      expect(tortilla.note, 'aprox 30 g');
    });

    test('una fracción se convierte en decimal', () {
      final whey = item(
        DayType.rest,
        'Colación / Comida 1',
        'Proteína en polvo (Whey)',
      );
      expect((whey.amount, whey.unit), (0.5, FoodUnit.scoop));
      expect(whey.note, 'mezclada en el yogurt');
    });

    test('la cantidad puede venir antes del nombre', () {
      final whey = item(DayType.training, 'Post-Entreno', 'Proteína en polvo');
      expect((whey.amount, whey.unit), (1, FoodUnit.scoop));
    });

    test('"Libre" marca consumo libre, con su nota si la trae', () {
      final salad = item(DayType.training, 'Comida', 'Ensalada verde');
      final jelly = item(DayType.rest, 'Cena', 'Gelatina sin azúcar (light)');
      final greens = item(
        DayType.rest,
        'Comida 2',
        'Verduras al vapor (brócoli / ejotes)',
      );
      expect((salad.isFree, salad.amount), (true, null));
      expect((jelly.isFree, jelly.note), (true, 'opcional'));
      expect(greens.isFree, isTrue); // "libres", en plural
    });

    test('un alimento sin cantidad no es un error', () {
      final sauce = item(
        DayType.training,
        'Comida',
        'Salsa casera o verduras al gusto',
      );
      expect((sauce.amount, sauce.isFree, sauce.warning), (null, false, null));
    });

    test('"…verdura libre" sin cantidad también es consumo libre', () {
      final greens = item(
        DayType.training,
        'Desayuno',
        'Nopales o alguna otra verdura libre',
      );
      expect(greens.isFree, isTrue);
    });

    test('limpia el resto de fórmula "\\text{ g}"', () {
      final papaya = item(DayType.training, 'Desayuno', 'Papaya');
      expect(
        (papaya.amount, papaya.unit, papaya.warning),
        (90, FoodUnit.gram, null),
      );
    });
  });

  group('estado de pesaje', () {
    test('lo toma del paréntesis y lo quita del nombre', () {
      final pasta = item(DayType.training, 'Comida', 'Pasta');
      final turkey = item(
        DayType.training,
        'Comida',
        'Pavo o filete de res magro',
      );
      expect(pasta.state, FoodState.cooked);
      expect(turkey.state, FoodState.raw);
    });

    test('lo reconoce también dentro del nombre', () {
      expect(
        item(DayType.rest, 'Comida 2', 'arroz integral cocido').state,
        FoodState.cooked,
      );
      expect(
        item(DayType.training, 'Pre-Entreno', 'Avena (en seco/hojuela)').state,
        FoodState.dry,
      );
    });

    test('si el plan no lo dice, queda sin especificar', () {
      final yogurt = item(
        DayType.rest,
        'Colación / Comida 1',
        'Yogurt natural',
      );
      expect(yogurt.state, FoodState.unspecified);
      expect(yogurt.warning, isNull);
    });

    test('dos alternativas con estados distintos se marcan para revisar', () {
      final mixed = item(DayType.rest, 'Cena', 'Camote o pavo');
      expect(mixed.state, FoodState.unspecified);
      expect(mixed.warning, contains('se pesan de forma distinta'));
    });
  });

  group('lo que no entiende', () {
    test('una unidad desconocida conserva el número y avisa', () {
      final mango = item(DayType.training, 'Desayuno', 'Mango');
      expect((mango.amount, mango.unit), (60, null));
      expect(mango.warning, 'No se reconoció la unidad "h".');
    });

    test('un número sin unidad avisa', () {
      final pork = item(DayType.rest, 'Comida 2', 'Lomo de cerdo');
      expect((pork.amount, pork.unit), (140, null));
      expect(pork.warning, contains('no trae unidad'));
    });

    test('una cantidad sin número se guarda como nota y avisa', () {
      final tea = item(DayType.rest, 'Cena', 'Té verde');
      expect((tea.amount, tea.note), (null, 'una taza'));
      expect(tea.warning, 'No se entendió la cantidad "una taza".');
    });

    test('cuenta todo lo que hay que revisar', () {
      // Mango, lomo de cerdo, camote o pavo y té verde.
      expect(parsed.warningCount, 4);
      expect(parsed.warnings, isEmpty);
    });
  });

  group('suplementos', () {
    test('lee nombre, dosis, momento y beneficio', () {
      final creatine = draft.supplements.first;
      expect(
        creatine.name,
        'Creatina Monohidratada (de preferencia micronizada)',
      );
      expect(creatine.dose, '3 g al día');
      expect(
        creatine.timing,
        'Todos los días, preferentemente junto a la comida post-entreno.',
      );
      expect(
        creatine.benefit,
        'Mejora la fuerza explosiva, la potencia y la hidratación muscular.',
      );
    });

    test('funciona con y sin viñetas', () {
      expect(draft.supplements.map((s) => s.name), [
        'Creatina Monohidratada (de preferencia micronizada)',
        'Citrato de Magnesio',
        'Vitamina C',
      ]);
      final vitamin = draft.supplements.last;
      expect(vitamin.dose, '500 mg');
      expect(
        vitamin.timing,
        'Junto al desayuno (o la comida con más fruta), una vez al día.',
      );
      expect(vitamin.benefit, 'Apoya el sistema inmune.');
    });
  });

  group('documentos inesperados', () {
    test('un texto que no es un plan avisa que no encontró comidas', () {
      final result = parseNutritionPlan('Factura 123\nTotal: 500 pesos');

      expect(result.draft.menus, isEmpty);
      expect(result.warnings.single, contains('No se encontró ninguna comida'));
    });

    test('un plan sin encabezado de menú se guarda como entrenamiento', () {
      final result = parseNutritionPlan('Mi plan\n• Desayuno\n◦Avena: 40 g');

      expect(result.draft.menus.single.dayType, DayType.training);
      expect(result.draft.menus.single.meals.single.items.single.name, 'Avena');
      expect(result.warnings.single, contains('no indica si es para días'));
    });

    test('un menú de tipo desconocido avisa y se asigna por su orden', () {
      final result = parseNutritionPlan(
        'Plan\nMenú 1: Lunes\n• Cena\n◦Atún: 100 g\n'
        'Menú 2: Martes\n• Cena\n◦Atún: 100 g',
      );

      expect(result.draft.menus.map((m) => m.dayType), [
        DayType.training,
        DayType.rest,
      ]);
      expect(result.warnings, hasLength(2));
    });

    test('un texto vacío no falla', () {
      final result = parseNutritionPlan('');

      expect(result.draft.name, 'Plan de alimentación');
      expect(result.draft.supplements, isEmpty);
    });
  });
}
