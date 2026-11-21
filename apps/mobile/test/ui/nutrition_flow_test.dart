import 'package:anfybio/app/appearance.dart';
import 'package:anfybio/app/providers.dart';
import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/repositories/nutrition_repository.dart';
import 'package:anfybio/data/repositories/training_repository.dart';
import 'package:anfybio/data/tables/sessions.dart';
import 'package:anfybio/domain/nutrition.dart';
import 'package:anfybio/ui/app.dart';
import 'package:anfybio/ui/widgets.dart';
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
  });

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) =>
      tester.enterText(find.byKey(Key(key)), text);

  /// Arranca la app y abre la pestaña de alimentación.
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

  /// Un plan con un alimento distinto en cada menú, para saber cuál se ve.
  Future<void> savePlan() => NutritionRepository(db).savePlan(
    userId,
    const NutritionPlanDraft(
      name: 'Plan de prueba',
      weighingNotes: 'Proteínas pesadas en crudo.',
      menus: [
        MenuDraft(
          dayType: DayType.training,
          title: 'Entrenamiento',
          meals: [
            MealDraft(
              name: 'Pre-entreno',
              timingNote: '30 min antes de entrenar',
              items: [
                ItemDraft(
                  name: 'Crema de arroz',
                  amount: 50,
                  unit: FoodUnit.gram,
                  state: FoodState.dry,
                ),
              ],
            ),
          ],
        ),
        MenuDraft(
          dayType: DayType.rest,
          title: 'Descanso',
          meals: [
            MealDraft(
              name: 'Desayuno',
              items: [
                ItemDraft(
                  name: 'Huevo entero',
                  amount: 3,
                  unit: FoodUnit.piece,
                ),
                ItemDraft(name: 'Ensalada verde', isFree: true),
              ],
            ),
          ],
        ),
      ],
      supplements: [
        SupplementDraft(
          name: 'Creatina',
          dose: '5 g al día',
          timing: 'Con el post-entreno',
        ),
      ],
    ),
  );

  testWidgets('sin plan, ofrece crearlo y lo deja listo para capturar', (
    tester,
  ) async {
    await openNutrition(tester);
    expect(find.text('Aún no tienes un plan'), findsOneWidget);

    await tap(tester, find.text('Crear plan a mano'));
    await type(tester, 'planName', 'Plan de noviembre');
    await tap(tester, find.text('Crear'));

    expect(find.text('Plan de noviembre'), findsOneWidget);
    expect(find.text('Agregar comida'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('sin sesiones hoy muestra el menú de descanso', (tester) async {
    await savePlan();
    await openNutrition(tester);

    expect(find.text('1. Desayuno'), findsOneWidget);
    expect(find.text('Huevo entero'), findsOneWidget);
    expect(find.text('3 piezas'), findsOneWidget);
    expect(find.text('Libre'), findsOneWidget);
    expect(find.text('Crema de arroz'), findsNothing);
    expect(find.textContaining('no has registrado sesiones'), findsOneWidget);
    expect(find.text('Proteínas pesadas en crudo.'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('con una sesión registrada hoy muestra el de entrenamiento', (
    tester,
  ) async {
    await savePlan();
    await TrainingRepository(db)
        .startSession(userId: userId, type: SessionType.strength);
    await openNutrition(tester);

    expect(find.text('1. Pre-entreno'), findsOneWidget);
    expect(find.text('30 min antes de entrenar'), findsOneWidget);
    expect(find.text('50 g'), findsOneWidget);
    expect(find.text('En seco'), findsOneWidget);
    expect(find.text('Huevo entero'), findsNothing);
    await shutDown(tester);
  });

  testWidgets('el tipo de día se puede cambiar a mano y se recuerda hoy', (
    tester,
  ) async {
    await savePlan();
    await openNutrition(tester);

    await tap(tester, find.text('Entrenamiento'));

    expect(find.text('Crema de arroz'), findsOneWidget);
    expect(find.text('Elegido por ti para hoy.'), findsOneWidget);
    expect(preferences.getString('dayTypeOverride'), endsWith(':training'));

    // Volver a elegir lo detectado quita la elección manual.
    await tap(tester, find.text('Descanso'));
    expect(find.text('Huevo entero'), findsOneWidget);
    expect(preferences.getString('dayTypeOverride'), isNull);
    await shutDown(tester);
  });

  testWidgets('con días altos y bajos, el usuario elige y se recuerda', (
    tester,
  ) async {
    await NutritionRepository(db).savePlan(
      userId,
      const NutritionPlanDraft(
        name: 'Plan alto y bajo',
        menus: [
          MenuDraft(
            dayType: DayType.high,
            title: 'Días altos',
            meals: [
              MealDraft(
                name: 'Comida',
                items: [
                  ItemDraft(name: 'Arroz', amount: 90, unit: FoodUnit.gram),
                ],
              ),
            ],
          ),
          MenuDraft(
            dayType: DayType.low,
            title: 'Días bajos',
            meals: [
              MealDraft(
                name: 'Comida',
                items: [
                  ItemDraft(name: 'Tostadas', amount: 3, unit: FoodUnit.piece),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    await openNutrition(tester);

    // Solo los menús de este plan, empezando por el primero.
    expect(find.text('Entrenamiento'), findsNothing);
    expect(find.text('Arroz'), findsOneWidget);
    expect(find.textContaining('Toca el menú que te toca hoy'), findsOneWidget);

    await tap(tester, find.text('Día bajo'));
    expect(find.text('Tostadas'), findsOneWidget);
    expect(preferences.getString('dayTypeOverride'), endsWith(':low'));

    // Elegir el primero también se recuerda: aquí no hay detección.
    await tap(tester, find.text('Día alto'));
    expect(find.text('Arroz'), findsOneWidget);
    expect(preferences.getString('dayTypeOverride'), endsWith(':high'));
    await shutDown(tester);
  });

  testWidgets('un plato muestra sus ingredientes y las alternativas', (
    tester,
  ) async {
    await NutritionRepository(db).savePlan(
      userId,
      const NutritionPlanDraft(
        name: 'Plan',
        menus: [
          MenuDraft(
            dayType: DayType.high,
            title: 'Altos',
            meals: [
              MealDraft(
                name: 'Desayuno',
                items: [
                  ItemDraft(
                    name: 'Sándwich',
                    ingredients: [
                      ItemDraft(
                        name: 'Pan integral',
                        amount: 2,
                        unit: FoodUnit.piece,
                      ),
                      ItemDraft(
                        name: 'Pechuga de pavo',
                        amount: 90,
                        unit: FoodUnit.gram,
                        alternatives: [
                          ItemDraft(
                            name: 'Queso panela',
                            amount: 80,
                            unit: FoodUnit.gram,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    await openNutrition(tester);

    expect(find.text('Sándwich', findRichText: true), findsOneWidget);
    expect(find.text('Pan integral', findRichText: true), findsOneWidget);
    expect(find.text('2 piezas'), findsOneWidget);
    expect(find.text('o Queso panela', findRichText: true), findsOneWidget);
    expect(find.text('80 g'), findsOneWidget);

    // Las filas del plato van con sangría bajo su nombre.
    final dishX = tester
        .getTopLeft(find.text('Sándwich', findRichText: true))
        .dx;
    final breadX = tester
        .getTopLeft(find.text('Pan integral', findRichText: true))
        .dx;
    expect(breadX, greaterThan(dishX));
    await shutDown(tester);
  });

  testWidgets('la guía de suplementos se ve en cualquier tipo de día', (
    tester,
  ) async {
    await savePlan();
    await openNutrition(tester);

    await tester.scrollUntilVisible(
      find.text('Creatina'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('5 g al día'), findsOneWidget);
    expect(find.text('Con el post-entreno'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('captura a mano una comida con un alimento', (tester) async {
    await NutritionRepository(db).createEmptyPlan(userId, name: 'Mi plan');
    await openNutrition(tester);

    await tap(tester, find.text('Agregar comida'));
    await type(tester, 'mealName', 'Cena');
    await type(tester, 'mealTiming', 'Antes de las 9');
    await tap(tester, find.text('Guardar comida'));
    expect(find.text('1. Cena'), findsOneWidget);
    expect(find.text('Sin alimentos.'), findsOneWidget);

    await tap(tester, find.text('Alimento'));
    await type(tester, 'itemName', 'Pescado blanco o atún');
    await type(tester, 'itemAmount', '140');
    await tap(tester, find.byKey(const Key('itemState')));
    await tap(tester, find.text('En crudo'));
    await tap(tester, find.text('Guardar alimento'));

    expect(find.text('Pescado blanco o atún'), findsOneWidget);
    expect(find.text('140 g'), findsOneWidget);
    expect(find.text('En crudo'), findsOneWidget);
    final item = await db.select(db.planItems).getSingle();
    expect(
      (item.amount, item.unit, item.state),
      (140, FoodUnit.gram, FoodState.raw),
    );
    await shutDown(tester);
  });

  testWidgets('tocar un alimento permite corregirlo o borrarlo', (
    tester,
  ) async {
    await savePlan();
    await openNutrition(tester);

    await tap(tester, find.text('Huevo entero'));
    expect(find.text('Editar alimento'), findsOneWidget);
    await type(tester, 'itemAmount', '2');
    await tap(tester, find.text('Guardar cambios'));
    expect(find.text('2 piezas'), findsOneWidget);

    await tap(tester, find.text('Huevo entero'));
    await tap(tester, find.byIcon(CupertinoIcons.trash));
    await tap(tester, find.text('Borrar'));
    expect(find.text('Huevo entero'), findsNothing);
    expect(find.text('Ensalada verde'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('marcar consumo libre quita la cantidad', (tester) async {
    await savePlan();
    await openNutrition(tester);

    await tap(tester, find.text('Huevo entero'));
    await tap(tester, find.byType(CupertinoSwitch));
    expect(find.byKey(const Key('itemAmount')), findsNothing);
    await tap(tester, find.text('Guardar cambios'));

    expect(find.text('Libre'), findsNWidgets(2));
    await shutDown(tester);
  });

  testWidgets('tocar el título de una comida permite renombrarla o borrarla', (
    tester,
  ) async {
    await savePlan();
    await openNutrition(tester);

    await tap(tester, find.text('1. Desayuno'));
    await type(tester, 'mealName', 'Almuerzo');
    await tap(tester, find.text('Guardar cambios'));
    expect(find.text('1. Almuerzo'), findsOneWidget);

    await tap(tester, find.text('1. Almuerzo'));
    await tap(tester, find.byIcon(CupertinoIcons.trash));
    await tap(tester, find.text('Borrar'));
    expect(find.text('1. Almuerzo'), findsNothing);
    expect(find.text('Huevo entero'), findsNothing);
    await shutDown(tester);
  });

  testWidgets('agrega y edita un suplemento', (tester) async {
    await NutritionRepository(db).createEmptyPlan(userId, name: 'Mi plan');
    await openNutrition(tester);

    await tap(tester, find.text('Suplemento'));
    await type(tester, 'supplementName', 'Zinc');
    await type(tester, 'supplementDose', '25 mg');
    await tap(tester, find.text('Guardar suplemento'));
    expect(find.text('Zinc'), findsOneWidget);
    expect(find.text('25 mg'), findsOneWidget);

    await tap(tester, find.text('Zinc'));
    await type(tester, 'supplementDose', '30 mg');
    await tap(tester, find.text('Guardar cambios'));
    expect(find.text('30 mg'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('cada suplemento lleva un icono según su nombre', (tester) async {
    expect(
      SupplementIcon.iconFor('Creatina Monohidratada'),
      CupertinoIcons.bolt_fill,
    );
    expect(
      SupplementIcon.iconFor('Citrato de Magnesio'),
      CupertinoIcons.moon_fill,
    );
    expect(
      SupplementIcon.iconFor('Omega 3 (EPA / DHA)'),
      CupertinoIcons.drop_fill,
    );
    expect(SupplementIcon.iconFor('Vitamina D3'), CupertinoIcons.sun_max_fill);
    expect(SupplementIcon.iconFor('Zinc'), CupertinoIcons.shield_fill);
    // Uno que no reconoce usa la cápsula.
    expect(SupplementIcon.iconFor('Ashwagandha'), CupertinoIcons.capsule_fill);
  });

  testWidgets('borrar el plan vuelve a la pantalla sin plan', (tester) async {
    await savePlan();
    await openNutrition(tester);

    await tap(tester, find.byIcon(CupertinoIcons.ellipsis_circle));
    await tap(tester, find.text('Borrar plan'));
    await tap(tester, find.text('Borrar'));

    expect(find.text('Aún no tienes un plan'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('un alimento sin nombre no se guarda', (tester) async {
    await savePlan();
    await openNutrition(tester);

    await tap(tester, find.text('Alimento'));
    await tap(tester, find.text('Guardar alimento'));

    expect(find.text('Escribe el nombre del alimento.'), findsOneWidget);
    expect(await db.select(db.planItems).get(), hasLength(3));
    await shutDown(tester);
  });
}
