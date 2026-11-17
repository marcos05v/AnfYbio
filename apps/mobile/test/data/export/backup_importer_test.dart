import 'dart:convert';

import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/export/backup_exporter.dart';
import 'package:anfybio/data/export/backup_importer.dart';
import 'package:anfybio/data/repositories/cooking_repository.dart';
import 'package:anfybio/data/repositories/nutrition_repository.dart';
import 'package:anfybio/data/repositories/routine_repository.dart';
import 'package:anfybio/data/repositories/supplement_repository.dart';
import 'package:anfybio/data/repositories/training_repository.dart';
import 'package:anfybio/data/tables/apnea_attempts.dart';
import 'package:anfybio/data/tables/sessions.dart';
import 'package:anfybio/data/tables/swim.dart';
import 'package:anfybio/domain/nutrition.dart';
import 'package:anfybio/domain/routine.dart';
import 'package:anfybio/domain/weight.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;
  final exportedAt = DateTime.utc(2026, 11, 16, 20, 30);

  setUp(() {
    source = AppDatabase(NativeDatabase.memory());
    target = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });

  /// Llena la base de origen con los cuatro tipos de sesión y un borrado,
  /// y devuelve su respaldo.
  Future<String> fullBackup() async {
    final user = await source
        .into(source.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Marcos'));
    final bench = await source
        .into(source.exercises)
        .insertReturning(
          ExercisesCompanion.insert(
            userId: user.id,
            name: 'Press de banca',
            defaultUnit: WeightUnit.lb,
          ),
        );
    final repo = TrainingRepository(source);
    final strength = await repo.startSession(
      userId: user.id,
      type: SessionType.strength,
      startedAt: DateTime.utc(2026, 11, 10, 18, 5),
    );
    await repo.addStrengthSet(
      sessionId: strength.id,
      exerciseId: bench.id,
      weight: 225,
      weightUnit: WeightUnit.lb,
      reps: 5,
      rpe: 8.5,
    );
    await repo.finishSession(strength.id, durationS: 3600, sessionRpe: 7);
    final swim = await repo.startSwimSession(userId: user.id, poolLengthM: 25);
    await repo.addSwimInterval(
      sessionId: swim.id,
      stroke: SwimStroke.backstroke,
      distanceM: 50,
      durationMs: 47200,
      lapSplitsMs: [23000, 24200],
    );
    final run = await repo.startSession(userId: user.id, type: SessionType.run);
    await repo.setRunDistance(run.id, distanceM: 5200);
    final apnea = await repo.startSession(
      userId: user.id,
      type: SessionType.apnea,
    );
    await repo.addApneaAttempt(
      sessionId: apnea.id,
      kind: ApneaKind.dynamic,
      distanceM: 50,
    );
    final removed = await repo.startSession(
      userId: user.id,
      type: SessionType.strength,
    );
    await repo.deleteSession(removed.id);
    // Una rutina, y una sesión que siguió su primer día.
    final routines = RoutineRepository(source);
    await routines.saveRoutine(
      user.id,
      const RoutineDraft(
        name: 'Rutina',
        days: [
          RoutineDayDraft(
            name: 'Pecho',
            exercises: [
              RoutineExerciseDraft(
                name: 'Press de banca',
                warmupSets: 2,
                workSets: 4,
                repsMin: 8,
                repsMax: 12,
              ),
            ],
          ),
        ],
      ),
    );
    final routineDay = (await routines.activeRoutine(user.id))!.days.single.day;
    await repo.startSession(
      userId: user.id,
      type: SessionType.strength,
      routineDayId: routineDay.id,
    );
    final supplements = SupplementRepository(source);
    final creatine = await supplements.addSupplement(
      userId: user.id,
      name: 'Creatina',
      unitLabel: 'g',
      dailyDose: 5,
      timing: 'Con el post-entreno',
      restockLeadDays: 10,
      initialQuantity: 300,
    );
    await supplements.logIntake(
      creatine.id,
      takenAt: DateTime.utc(2026, 11, 15, 14),
    );
    await supplements.adjustStock(
      creatine.id,
      actualStock: 280,
      now: DateTime(2026, 11, 16),
    );
    await CookingRepository(source).addBatch(
      userId: user.id,
      foodName: 'Pechuga de pollo',
      rawWeightG: 1000,
      cookedWeightG: 720,
      withOtherIngredients: true,
      note: 'Con salsa',
      cookedAt: DateTime.utc(2026, 11, 14, 13),
    );
    await NutritionRepository(source).savePlan(
      user.id,
      const NutritionPlanDraft(
        name: 'Plan',
        weighingNotes: 'Proteínas en crudo.',
        menus: [
          MenuDraft(
            dayType: DayType.training,
            title: 'Entrenamiento',
            meals: [
              MealDraft(
                name: 'Desayuno',
                timingNote: 'Al despertar',
                items: [
                  ItemDraft(
                    name: 'Claras de huevo',
                    amount: 100,
                    unit: FoodUnit.gram,
                    state: FoodState.raw,
                  ),
                  ItemDraft(name: 'Verdura', isFree: true),
                ],
              ),
            ],
          ),
        ],
        supplements: [SupplementDraft(name: 'Creatina', dose: '5 g')],
      ),
    );

    return (await BackupExporter(source, now: () => exportedAt).export(user.id))
        .json;
  }

  Matcher rejectsWith(String fragment) => throwsA(
    isA<BackupImportException>().having(
      (e) => e.message,
      'message',
      contains(fragment),
    ),
  );

  test('importar un respaldo reproduce exactamente los mismos datos', () async {
    final backup = await fullBackup();

    await BackupImporter(target).import(backup);

    // La prueba más fuerte: volver a exportar da el mismo archivo.
    final user = await target.select(target.users).getSingle();
    final again = await BackupExporter(
      target,
      now: () => exportedAt,
    ).export(user.id);
    expect(again.json, backup);
  });

  test('los datos importados funcionan con el resto de la app', () async {
    await BackupImporter(target).import(await fullBackup());

    final user = await target.select(target.users).getSingle();
    final repo = TrainingRepository(target);
    final sessions = await repo.sessionsOf(user.id);

    expect(user.displayName, 'Marcos');
    expect(sessions, hasLength(5)); // la sesión borrada sigue oculta
    final strength = sessions.singleWhere(
      (s) => s.type == SessionType.strength && s.routineDayId == null,
    );
    expect(strength.startedAt, DateTime.utc(2026, 11, 10, 18, 5));
    expect(strength.startedAt.isUtc, isTrue);
    final set = (await repo.strengthSetsOf(strength.id)).single;
    expect((set.weight, set.weightUnit, set.rpe), (225, WeightUnit.lb, 8.5));
  });

  test('el plan de alimentación importado se lee completo', () async {
    await BackupImporter(target).import(await fullBackup());

    final user = await target.select(target.users).getSingle();
    final view = (await NutritionRepository(target).activePlan(user.id))!;
    final meal = view.menuFor(DayType.training)!.meals.single;
    expect(view.plan.weighingNotes, 'Proteínas en crudo.');
    expect(meal.meal.timingNote, 'Al despertar');
    expect(meal.items.map((i) => (i.name, i.state, i.isFree)), [
      ('Claras de huevo', FoodState.raw, false),
      ('Verdura', FoodState.unspecified, true),
    ]);
    expect(view.supplements.single.dose, '5 g');
  });

  test('acepta un respaldo anterior al plan de alimentación', () async {
    // Un respaldo de la versión 1 del esquema no trae las tablas nuevas.
    final document = jsonDecode(await fullBackup()) as Map<String, dynamic>;
    document['schemaVersion'] = 1;
    final tables = document['tables'] as Map<String, dynamic>;
    for (final name in [
      'nutritionPlans',
      'planMenus',
      'planMeals',
      'planItems',
      'supplementGuidelines',
      'routines',
      'routineDays',
      'routineExercises',
      'cookingBatches',
      'supplements',
      'supplementPurchases',
      'supplementIntakes',
    ]) {
      tables.remove(name);
    }
    for (final session in tables['sessions'] as List) {
      (session as Map).remove('routineDayId');
    }

    await BackupImporter(target).import(jsonEncode(document));

    expect(await target.select(target.sessions).get(), hasLength(6));
    expect(await target.select(target.nutritionPlans).get(), isEmpty);
  });

  test('la rutina importada conserva su enlace con la sesión', () async {
    await BackupImporter(target).import(await fullBackup());

    final user = await target.select(target.users).getSingle();
    final view = (await RoutineRepository(target).activeRoutine(user.id))!;
    final exercise = view.days.single.exercises.single;
    expect((exercise.warmupSets, exercise.workSets), (2, 4));
    expect((exercise.repsMin, exercise.repsMax), (8, 12));

    final linked = (await target.select(target.sessions).get()).where(
      (s) => s.routineDayId != null,
    );
    expect(linked.single.routineDayId, view.days.single.day.id);
  });

  test(
    'los lotes de cocción importados conservan sus pesos y su fecha',
    () async {
      await BackupImporter(target).import(await fullBackup());

      final batch = await target.select(target.cookingBatches).getSingle();
      expect(
        (batch.foodName, batch.rawWeightG, batch.cookedWeightG),
        ('Pechuga de pollo', 1000, 720),
      );
      expect(batch.cookedAt, DateTime.utc(2026, 11, 14, 13));
      expect((batch.withOtherIngredients, batch.note), (true, 'Con salsa'));
    },
  );

  test(
    'el inventario de suplementos importado da las mismas existencias',
    () async {
      await BackupImporter(target).import(await fullBackup());

      final user = await target.select(target.users).getSingle();
      final view = (await SupplementRepository(target).supplementsOf(user.id))
          .single;
      expect(
        (view.supplement.dailyDose, view.supplement.restockLeadDays),
        (5, 10),
      );
      expect(view.purchases.single.quantity, 300);
      // Una toma de 5 y un ajuste de 15: 300 − 5 − 15 = 280.
      expect(view.intakes, hasLength(2));
      expect(view.statusAt(DateTime(2026, 11, 16)).stock, 280);
    },
  );

  test('a un respaldo actual no le puede faltar una tabla nueva', () async {
    final document = jsonDecode(await fullBackup()) as Map<String, dynamic>;
    (document['tables'] as Map).remove('planItems');

    await expectLater(
      BackupImporter(target).import(jsonEncode(document)),
      rejectsWith('dañado'),
    );
    expect(await target.select(target.users).get(), isEmpty);
  });

  test('no importa si la app ya tiene un usuario', () async {
    final backup = await fullBackup();
    await target
        .into(target.users)
        .insert(UsersCompanion.insert(displayName: 'Ya existo'));

    await expectLater(
      BackupImporter(target).import(backup),
      rejectsWith('ya tiene datos'),
    );
    expect(await target.select(target.sessions).get(), isEmpty);
  });

  test('rechaza archivos que no son un respaldo', () async {
    final importer = BackupImporter(target);

    await expectLater(
      importer.import('hola'),
      rejectsWith('no es un respaldo'),
    );
    await expectLater(
      importer.import('[1, 2]'),
      rejectsWith('no es un respaldo'),
    );
    await expectLater(
      importer.import('{"format": "otra-cosa"}'),
      rejectsWith('no es un respaldo'),
    );
  });

  test('rechaza un respaldo de una versión más nueva', () async {
    final document = jsonDecode(await fullBackup()) as Map<String, dynamic>;
    document['formatVersion'] = backupFormatVersion + 1;

    await expectLater(
      BackupImporter(target).import(jsonEncode(document)),
      rejectsWith('versión más nueva'),
    );
  });

  test('un respaldo dañado no deja nada a medias', () async {
    final document = jsonDecode(await fullBackup()) as Map<String, dynamic>;
    // Una serie que apunta a una sesión inexistente: falla al final.
    final sets = (document['tables'] as Map)['strengthSets'] as List;
    (sets.first as Map)['sessionId'] = 'no-existe';

    await expectLater(
      BackupImporter(target).import(jsonEncode(document)),
      rejectsWith('dañado'),
    );
    // Ni el usuario ni las sesiones, que se insertaron antes del fallo.
    expect(await target.select(target.users).get(), isEmpty);
    expect(await target.select(target.sessions).get(), isEmpty);
  });

  test('un respaldo al que le falta una tabla se rechaza completo', () async {
    final document = jsonDecode(await fullBackup()) as Map<String, dynamic>;
    (document['tables'] as Map).remove('swimLaps');

    await expectLater(
      BackupImporter(target).import(jsonEncode(document)),
      rejectsWith('dañado'),
    );
    expect(await target.select(target.users).get(), isEmpty);
  });
}
