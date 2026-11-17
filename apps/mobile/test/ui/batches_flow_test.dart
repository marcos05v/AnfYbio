import 'package:anfybio/app/appearance.dart';
import 'package:anfybio/app/providers.dart';
import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/repositories/cooking_repository.dart';
import 'package:anfybio/data/repositories/nutrition_repository.dart';
import 'package:anfybio/domain/nutrition.dart';
import 'package:anfybio/ui/app.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences preferences;
  late String userId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Ana'));
    userId = user.id;
    // Plan de descanso (el que se ve sin sesiones) con un alimento en crudo,
    // uno cocido y uno sin especificar.
    await NutritionRepository(db).savePlan(
      userId,
      const NutritionPlanDraft(
        name: 'Plan',
        menus: [
          MenuDraft(
            dayType: DayType.rest,
            title: 'Descanso',
            meals: [
              MealDraft(
                name: 'Comida',
                items: [
                  ItemDraft(
                    name: 'Pechuga de pollo o filete de res magro',
                    amount: 130,
                    unit: FoodUnit.gram,
                    state: FoodState.raw,
                  ),
                  ItemDraft(
                    name: 'Arroz blanco',
                    amount: 110,
                    unit: FoodUnit.gram,
                    state: FoodState.cooked,
                  ),
                  ItemDraft(name: 'Atún', amount: 140, unit: FoodUnit.gram),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  });

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(Key(key)), text);
    await tester.pumpAndSettle();
  }

  Future<void> openNutrition(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const AnfybioApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Alimentación'));
  }

  Future<void> shutDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  /// Elige "Otro" en la lista de alimentos y escribe el nombre a mano.
  Future<void> typeOtherFood(WidgetTester tester, String name) async {
    await tap(tester, find.byKey(const Key('batchFoodPicker')));
    await tap(tester, find.text('Otro…'));
    await type(tester, 'batchFood', name);
  }

  String factorText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('batchFactor'))).data!;

  testWidgets('sin lotes, el plan no muestra conversiones', (tester) async {
    await openNutrition(tester);

    expect(find.textContaining('g cocido'), findsNothing);
    expect(
      find.text('Pesa lo que cocinas y sabrás cuánto servir'),
      findsOneWidget,
    );
    await shutDown(tester);
  });

  testWidgets('registrar un lote muestra en el plan cuánto servir cocido', (
    tester,
  ) async {
    await openNutrition(tester);
    await tap(tester, find.text('Lotes de cocción'));
    expect(find.text('Sin lotes todavía'), findsOneWidget);

    await tap(tester, find.text('Agregar lote'));
    // El alimento se elige entre los del plan: primero los que pide en
    // crudo, luego los demás y al final "Otro".
    await tap(tester, find.byKey(const Key('batchFoodPicker')));
    expect(find.text('Tu plan los pide en crudo'), findsOneWidget);
    expect(find.text('Filete de res magro'), findsOneWidget);
    expect(find.text('Otros alimentos de tu plan'), findsOneWidget);
    expect(find.text('Arroz blanco'), findsOneWidget);
    expect(find.text('Otro…'), findsOneWidget);
    await tap(tester, find.text('Pechuga de pollo'));
    // Elegido de la lista: no hace falta escribir nada.
    expect(find.byKey(const Key('batchFood')), findsNothing);
    await type(tester, 'batchRaw', '1000');
    await type(tester, 'batchCooked', '720');
    expect(factorText(tester), contains('× 0.72'));
    expect(factorText(tester), contains('100 g en crudo quedan en 72 g'));
    await tap(tester, find.text('Guardar lote'));

    expect(find.text('Crudo 1000 g · cocido 720 g'), findsOneWidget);
    expect(find.text('× 0.72'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    // 130 g en crudo × 0.72 = 93.6 → 94 g cocido.
    expect(find.text('Sirve 94 g cocido'), findsOneWidget);
    expect(find.text('1 lote registrado'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('solo convierte lo que el plan pide en crudo', (tester) async {
    final cooking = CookingRepository(db);
    for (final food in ['Arroz blanco', 'Atún']) {
      await cooking.addBatch(
        userId: userId,
        foodName: food,
        rawWeightG: 100,
        cookedWeightG: 250,
      );
    }
    await openNutrition(tester);

    // Ni el arroz (ya cocido) ni el atún (sin especificar) se convierten.
    expect(find.textContaining('g cocido'), findsNothing);
    await shutDown(tester);
  });

  testWidgets('un lote con otros ingredientes da un dato aproximado', (
    tester,
  ) async {
    await openNutrition(tester);
    await tap(tester, find.text('Lotes de cocción'));
    await tap(tester, find.text('Agregar lote'));
    await typeOtherFood(tester, 'Pollo');
    await type(tester, 'batchRaw', '500');
    await type(tester, 'batchCooked', '450');
    await tap(tester, find.byType(CupertinoSwitch));
    expect(factorText(tester), contains('aproximado'));
    await tap(tester, find.text('Guardar lote'));
    expect(find.textContaining('con otros ingredientes'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Sirve aprox. 117 g cocido'), findsOneWidget); // 130 × 0.9
    await shutDown(tester);
  });

  testWidgets('el plan usa el lote más reciente del alimento', (tester) async {
    final cooking = CookingRepository(db);
    await cooking.addBatch(
      userId: userId,
      foodName: 'Pechuga de pollo',
      rawWeightG: 1000,
      cookedWeightG: 700,
      cookedAt: DateTime.utc(2026, 11, 1),
    );
    await cooking.addBatch(
      userId: userId,
      foodName: 'Pechuga de pollo',
      rawWeightG: 1000,
      cookedWeightG: 800,
      cookedAt: DateTime.utc(2026, 11, 10),
    );
    await openNutrition(tester);

    expect(find.text('Sirve 104 g cocido'), findsOneWidget); // 130 × 0.8
    expect(find.text('2 lotes registrados'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('tocar un lote permite corregirlo o borrarlo', (tester) async {
    await CookingRepository(db).addBatch(
      userId: userId,
      foodName: 'Pechuga de pollo',
      rawWeightG: 1000,
      cookedWeightG: 720,
    );
    await openNutrition(tester);
    await tap(tester, find.text('Lotes de cocción'));

    await tap(tester, find.text('Pechuga de pollo'));
    expect(find.text('Editar lote'), findsOneWidget);
    await type(tester, 'batchCooked', '750');
    await tap(tester, find.text('Guardar cambios'));
    expect(find.text('× 0.75'), findsOneWidget);

    await tap(tester, find.text('Pechuga de pollo'));
    await tap(tester, find.byIcon(CupertinoIcons.trash));
    await tap(tester, find.text('Borrar'));
    expect(find.text('Sin lotes todavía'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('sin elegir alimento, el lote no se guarda', (tester) async {
    await openNutrition(tester);
    await tap(tester, find.text('Lotes de cocción'));
    await tap(tester, find.text('Agregar lote'));
    await type(tester, 'batchRaw', '500');
    await type(tester, 'batchCooked', '400');
    await tap(tester, find.text('Guardar lote'));

    expect(find.text('Elige el alimento del lote.'), findsOneWidget);
    expect(await db.select(db.cookingBatches).get(), isEmpty);
    await shutDown(tester);
  });

  testWidgets('un lote de un alimento fuera del plan se edita como "Otro"', (
    tester,
  ) async {
    await CookingRepository(db).addBatch(
      userId: userId,
      foodName: 'Lentejas',
      rawWeightG: 200,
      cookedWeightG: 480,
    );
    await openNutrition(tester);
    await tap(tester, find.text('Lotes de cocción'));

    await tap(tester, find.text('Lentejas'));

    expect(find.text('Otro'), findsOneWidget);
    expect(find.byKey(const Key('batchFood')), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('un lote sin pesos válidos no se guarda', (tester) async {
    await openNutrition(tester);
    await tap(tester, find.text('Lotes de cocción'));
    await tap(tester, find.text('Agregar lote'));
    await typeOtherFood(tester, 'Pollo');
    await type(tester, 'batchRaw', '0');
    await tap(tester, find.text('Guardar lote'));

    expect(find.text('Escribe el peso en crudo, en gramos.'), findsOneWidget);
    expect(await db.select(db.cookingBatches).get(), isEmpty);
    await shutDown(tester);
  });
}
