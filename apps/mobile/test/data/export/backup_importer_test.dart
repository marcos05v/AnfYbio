import 'dart:convert';

import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/export/backup_exporter.dart';
import 'package:anfybio/data/export/backup_importer.dart';
import 'package:anfybio/data/repositories/nutrition_repository.dart';
import 'package:anfybio/data/repositories/training_repository.dart';
import 'package:anfybio/data/tables/apnea_attempts.dart';
import 'package:anfybio/data/tables/sessions.dart';
import 'package:anfybio/data/tables/swim.dart';
import 'package:anfybio/domain/nutrition.dart';
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
    expect(sessions, hasLength(4)); // la sesión borrada sigue oculta
    final strength = sessions.singleWhere(
      (s) => s.type == SessionType.strength,
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
    ]) {
      tables.remove(name);
    }

    await BackupImporter(target).import(jsonEncode(document));

    expect(await target.select(target.sessions).get(), hasLength(5));
    expect(await target.select(target.nutritionPlans).get(), isEmpty);
  });

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
