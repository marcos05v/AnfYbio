import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/repositories/nutrition_repository.dart';
import 'package:anfybio/data/repositories/training_repository.dart'
    show RecordNotFound;
import 'package:anfybio/domain/nutrition.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late NutritionRepository repo;
  late String userId;
  var clock = DateTime.utc(2026, 11, 16, 12);

  setUp(() async {
    clock = DateTime.utc(2026, 11, 16, 12);
    db = AppDatabase(NativeDatabase.memory());
    repo = NutritionRepository(db, now: () => clock);
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Prueba'));
    userId = user.id;
  });
  tearDown(() => db.close());

  const draft = NutritionPlanDraft(
    name: 'Plan de prueba',
    sourceFileName: 'plan.pdf',
    weighingNotes: 'Proteínas en crudo.',
    menus: [
      MenuDraft(
        dayType: DayType.training,
        title: 'Días de entrenamiento',
        meals: [
          MealDraft(
            name: 'Desayuno',
            items: [
              ItemDraft(name: 'Huevo entero', amount: 2, unit: FoodUnit.piece),
              ItemDraft(name: 'Verdura', isFree: true),
            ],
          ),
          MealDraft(
            name: 'Pre-entreno',
            timingNote: '30 min antes',
            items: [
              ItemDraft(
                name: 'Crema de arroz',
                amount: 50,
                unit: FoodUnit.gram,
                state: FoodState.dry,
                note: 'en polvo',
              ),
            ],
          ),
        ],
      ),
      MenuDraft(
        dayType: DayType.rest,
        title: 'Días de descanso',
        meals: [
          MealDraft(
            name: 'Cena',
            items: [
              ItemDraft(
                name: 'Pescado blanco o pollo',
                amount: 160,
                unit: FoodUnit.gram,
                state: FoodState.raw,
              ),
            ],
          ),
        ],
      ),
    ],
    supplements: [
      SupplementDraft(name: 'Creatina', dose: '5 g al día', timing: 'Diario'),
      SupplementDraft(name: 'Zinc', dose: '25 mg'),
    ],
  );

  group('guardar y leer un plan', () {
    test('guarda el plan completo en el orden del borrador', () async {
      await repo.savePlan(userId, draft);

      final view = (await repo.activePlan(userId))!;
      expect(view.plan.name, 'Plan de prueba');
      expect(view.plan.sourceFileName, 'plan.pdf');
      expect(view.plan.weighingNotes, 'Proteínas en crudo.');

      final training = view.menuFor(DayType.training)!;
      expect(training.meals.map((m) => m.meal.name), [
        'Desayuno',
        'Pre-entreno',
      ]);
      expect(training.meals.map((m) => m.meal.position), [1, 2]);
      expect(training.meals[1].meal.timingNote, '30 min antes');
      expect(training.meals[0].items.map((i) => i.name), [
        'Huevo entero',
        'Verdura',
      ]);

      final cream = training.meals[1].items.single;
      expect(
        (cream.amount, cream.unit, cream.state, cream.note),
        (50, FoodUnit.gram, FoodState.dry, 'en polvo'),
      );

      final rest = view.menuFor(DayType.rest)!;
      expect(rest.meals.single.items.single.state, FoodState.raw);
      expect(view.supplements.map((s) => s.name), ['Creatina', 'Zinc']);
      expect(view.supplements.last.timing, isNull);
    });

    test('un alimento libre se guarda sin cantidad ni unidad', () async {
      await repo.savePlan(
        userId,
        const NutritionPlanDraft(
          name: 'P',
          menus: [
            MenuDraft(
              dayType: DayType.training,
              title: 'T',
              meals: [
                MealDraft(
                  name: 'Cena',
                  items: [
                    // El borrador trae cantidad por error: se descarta.
                    ItemDraft(
                      name: 'Ensalada',
                      isFree: true,
                      amount: 100,
                      unit: FoodUnit.gram,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      final view = (await repo.activePlan(userId))!;
      final item = view.menus.single.meals.single.items.single;
      expect((item.isFree, item.amount, item.unit), (true, null, null));
    });

    test('sin plan, el plan activo es nulo', () async {
      expect(await repo.activePlan(userId), isNull);
    });

    test(
      'guardar un plan nuevo desactiva el anterior pero lo conserva',
      () async {
        final first = await repo.savePlan(userId, draft);
        final second = await repo.savePlan(
          userId,
          const NutritionPlanDraft(name: 'Plan nuevo'),
        );

        expect((await repo.activePlan(userId))!.plan.id, second);
        final plans = await db.select(db.nutritionPlans).get();
        expect(plans, hasLength(2));
        final old = plans.singleWhere((p) => p.id == first);
        expect((old.isActive, old.deletedAt), (false, null));
      },
    );

    test('el plan de un usuario no afecta al de otro', () async {
      final other = await db
          .into(db.users)
          .insertReturning(UsersCompanion.insert(displayName: 'Hermana'));
      await repo.savePlan(userId, draft);
      await repo.savePlan(other.id, const NutritionPlanDraft(name: 'De ella'));

      expect((await repo.activePlan(userId))!.plan.name, 'Plan de prueba');
      expect((await repo.activePlan(other.id))!.plan.name, 'De ella');
    });

    test('un plan vacío nace con sus dos menús', () async {
      await repo.createEmptyPlan(userId, name: 'A mano');

      final view = (await repo.activePlan(userId))!;
      expect(view.menus.map((m) => m.menu.dayType), [
        DayType.training,
        DayType.rest,
      ]);
      expect(view.menus.every((m) => m.meals.isEmpty), isTrue);
    });
  });

  group('editar', () {
    late NutritionPlanView view;
    setUp(() async {
      await repo.savePlan(userId, draft);
      view = (await repo.activePlan(userId))!;
    });

    Future<NutritionPlanView> reload() async =>
        (await repo.activePlan(userId))!;

    test('agregar una comida la pone al final del menú', () async {
      final menu = view.menuFor(DayType.training)!;
      final meal = await repo.addMeal(menu.menu.id, name: ' Cena ');

      expect(meal.position, 3);
      expect(meal.name, 'Cena'); // sin espacios sobrantes
      expect(meal.userId, userId);
    });

    test('editar una comida cambia nombre y horario', () async {
      final meal = view.menuFor(DayType.training)!.meals.first.meal;
      clock = clock.add(const Duration(minutes: 5));

      await repo.updateMeal(meal.id, name: 'Almuerzo', timingNote: '');

      final edited = (await reload())
          .menuFor(DayType.training)!
          .meals
          .first
          .meal;
      expect((edited.name, edited.timingNote), ('Almuerzo', null));
      expect(edited.updatedAt, clock);
    });

    test('borrar una comida borra también sus alimentos', () async {
      final meal = view.menuFor(DayType.training)!.meals.first.meal;

      await repo.deleteMeal(meal.id);

      final meals = (await reload()).menuFor(DayType.training)!.meals;
      expect(meals.map((m) => m.meal.name), ['Pre-entreno']);
      final items = await db.select(db.planItems).get();
      expect(
        items.where((i) => i.mealId == meal.id && i.deletedAt == null),
        isEmpty,
      );
    });

    test('agregar, editar y borrar un alimento', () async {
      final meal = view.menuFor(DayType.rest)!.meals.single.meal;

      final added = await repo.addItem(
        meal.id,
        const ItemDraft(name: 'Aguacate', amount: 40, unit: FoodUnit.gram),
      );
      expect(added.position, 2);

      await repo.updateItem(
        added.id,
        const ItemDraft(
          name: 'Aguacate',
          amount: 50,
          unit: FoodUnit.gram,
          state: FoodState.raw,
          note: 'maduro',
        ),
      );
      var items = (await reload()).menuFor(DayType.rest)!.meals.single.items;
      expect(
        (items.last.amount, items.last.state, items.last.note),
        (50, FoodState.raw, 'maduro'),
      );

      await repo.deleteItem(added.id);
      items = (await reload()).menuFor(DayType.rest)!.meals.single.items;
      expect(items.map((i) => i.name), ['Pescado blanco o pollo']);
    });

    test('agregar, editar y borrar un suplemento', () async {
      final added = await repo.addSupplement(
        view.plan.id,
        const SupplementDraft(name: 'Omega 3', dose: '1 g'),
      );
      expect(added.position, 3);

      await repo.updateSupplement(
        added.id,
        const SupplementDraft(name: 'Omega 3', dose: '2 g', timing: 'Cena'),
      );
      expect((await reload()).supplements.last.dose, '2 g');

      await repo.deleteSupplement(added.id);
      expect((await reload()).supplements.map((s) => s.name), [
        'Creatina',
        'Zinc',
      ]);
    });

    test('no se puede editar lo que no existe o ya se borró', () async {
      final item = view.menuFor(DayType.rest)!.meals.single.items.single;
      await repo.deleteItem(item.id);

      await expectLater(
        repo.deleteItem(item.id),
        throwsA(isA<RecordNotFound>()),
      );
      await expectLater(
        repo.updateItem(item.id, const ItemDraft(name: 'X')),
        throwsA(isA<RecordNotFound>()),
      );
      await expectLater(
        repo.addItem('no-existe', const ItemDraft(name: 'X')),
        throwsA(isA<RecordNotFound>()),
      );
    });

    test(
      'borrar el plan marca todo su contenido y deja al usuario sin plan',
      () async {
        await repo.deletePlan(view.plan.id);

        expect(await repo.activePlan(userId), isNull);
        expect(
          (await db.select(db.planMenus).get()).every(
            (m) => m.deletedAt != null,
          ),
          isTrue,
        );
        expect(
          (await db.select(db.planMeals).get()).every(
            (m) => m.deletedAt != null,
          ),
          isTrue,
        );
        expect(
          (await db.select(db.planItems).get()).every(
            (i) => i.deletedAt != null,
          ),
          isTrue,
        );
        expect(
          (await db.select(db.supplementGuidelines).get()).every(
            (s) => s.deletedAt != null,
          ),
          isTrue,
        );
      },
    );
  });

  test('watchActivePlan vuelve a emitir cuando cambia un alimento', () async {
    await repo.savePlan(userId, draft);
    final emitted = <int>[];
    final subscription = repo.watchActivePlan(userId).listen((view) {
      emitted.add(
        view!.menus.expand((m) => m.meals).expand((m) => m.items).length,
      );
    });
    await pumpEventQueue();
    expect(emitted, [4]);

    final meal = (await repo.activePlan(userId))!
        .menuFor(DayType.rest)!
        .meals
        .single
        .meal;
    await repo.addItem(meal.id, const ItemDraft(name: 'Aguacate'));
    await pumpEventQueue();

    expect(emitted.last, 5);
    await subscription.cancel();
  });

  group('platos y alternativas', () {
    const sandwich = ItemDraft(
      name: 'Sándwich',
      ingredients: [
        ItemDraft(name: 'Pan integral', amount: 2, unit: FoodUnit.piece),
        ItemDraft(
          name: 'Pechuga de pavo',
          amount: 90,
          unit: FoodUnit.gram,
          alternatives: [
            ItemDraft(name: 'Queso panela', amount: 80, unit: FoodUnit.gram),
          ],
        ),
      ],
    );
    const apple = ItemDraft(
      name: 'Manzana',
      amount: 1,
      unit: FoodUnit.piece,
      alternatives: [ItemDraft(name: 'Fresas', amount: 1, unit: FoodUnit.cup)],
    );

    Future<MealView> saveMeal() async {
      await repo.savePlan(
        userId,
        const NutritionPlanDraft(
          name: 'Plan',
          menus: [
            MenuDraft(
              dayType: DayType.high,
              title: 'Días altos',
              meals: [
                MealDraft(name: 'Desayuno', items: [sandwich, apple]),
              ],
            ),
          ],
        ),
      );
      return (await repo.activePlan(userId))!.menus.single.meals.single;
    }

    test('se guardan y se leen con su estructura', () async {
      final meal = await saveMeal();

      expect(meal.items, hasLength(6)); // todas las filas
      final [dish, fruit] = meal.entries;
      expect(dish.item.name, 'Sándwich');
      expect(dish.ingredients.map((i) => i.item.name), [
        'Pan integral',
        'Pechuga de pavo',
      ]);
      final turkey = dish.ingredients.last;
      expect(turkey.alternatives.single.name, 'Queso panela');
      expect(turkey.alternatives.single.amount, 80);
      expect(fruit.item.name, 'Manzana');
      expect(fruit.alternatives.single.unit, FoodUnit.cup);
      expect(fruit.ingredients, isEmpty);
    });

    test('borrar un plato borra lo que lleva dentro', () async {
      final meal = await saveMeal();
      final dish = meal.entries.first.item;

      await repo.deleteItem(dish.id);

      final after = (await repo.activePlan(userId))!.menus.single.meals.single;
      expect(after.items.map((i) => i.name), ['Manzana', 'Fresas']);
      // Borrado lógico: las filas siguen ahí, marcadas.
      final deleted = await (db.select(
        db.planItems,
      )..where((i) => i.deletedAt.isNotNull())).get();
      expect(deleted, hasLength(4));
    });
  });
}
