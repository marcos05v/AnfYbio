import 'dart:convert';

import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/export/backup_exporter.dart';
import 'package:anfybio/data/repositories/training_repository.dart';
import 'package:anfybio/data/tables/apnea_attempts.dart';
import 'package:anfybio/data/tables/sessions.dart';
import 'package:anfybio/data/tables/swim.dart';
import 'package:anfybio/domain/weight.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TrainingRepository repo;
  late BackupExporter exporter;
  late String userId;
  final exportedAt = DateTime.utc(2026, 11, 16, 20, 30);

  Future<String> createUser(String name) async {
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: name));
    return user.id;
  }

  Future<String> createExercise(String ownerId, String name) async {
    final exercise = await db
        .into(db.exercises)
        .insertReturning(
          ExercisesCompanion.insert(
            userId: ownerId,
            name: name,
            defaultUnit: WeightUnit.lb,
          ),
        );
    return exercise.id;
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrainingRepository(db);
    exporter = BackupExporter(db, now: () => exportedAt);
    userId = await createUser('Marcos');
  });
  tearDown(() => db.close());

  /// Exporta y vuelve a leer el archivo, como lo haría una importación.
  Future<Map<String, dynamic>> exportAndDecode() async {
    final backup = await exporter.export(userId);
    return jsonDecode(backup.json) as Map<String, dynamic>;
  }

  List<dynamic> table(Map<String, dynamic> document, String name) =>
      (document['tables'] as Map<String, dynamic>)[name] as List<dynamic>;

  test(
    'el archivo lleva la fecha en el nombre y los datos de versión',
    () async {
      final backup = await exporter.export(userId);
      final document = jsonDecode(backup.json) as Map<String, dynamic>;

      expect(backup.fileName, 'anfybio-respaldo-2026-11-16.json');
      expect(document['format'], 'anfybio-backup');
      expect(document['formatVersion'], backupFormatVersion);
      expect(document['schemaVersion'], db.schemaVersion);
      expect(document['exportedAt'], '2026-11-16T20:30:00.000Z');
      expect((document['user'] as Map)['displayName'], 'Marcos');
    },
  );

  test('un usuario sin datos exporta todas las tablas vacías', () async {
    final document = await exportAndDecode();

    expect((document['tables'] as Map).keys, [
      'exercises',
      'sessions',
      'strengthSets',
      'swimDetails',
      'swimIntervals',
      'swimLaps',
      'runDetails',
      'apneaAttempts',
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
    ]);
    expect(
      (document['tables'] as Map).values.every((t) => (t as List).isEmpty),
      isTrue,
    );
  });

  test('incluye los registros de los cuatro tipos de sesión', () async {
    final bench = await createExercise(userId, 'Press de banca');
    final strength = await repo.startSession(
      userId: userId,
      type: SessionType.strength,
    );
    await repo.addStrengthSet(
      sessionId: strength.id,
      exerciseId: bench,
      weight: 225,
      weightUnit: WeightUnit.lb,
      reps: 5,
      rpe: 8.5,
    );
    final swim = await repo.startSwimSession(userId: userId, poolLengthM: 25);
    await repo.addSwimInterval(
      sessionId: swim.id,
      stroke: SwimStroke.backstroke,
      distanceM: 50,
      durationMs: 47000,
      lapSplitsMs: [23000, 24000],
    );
    final run = await repo.startSession(userId: userId, type: SessionType.run);
    await repo.setRunDistance(run.id, distanceM: 5000);
    final apnea = await repo.startSession(
      userId: userId,
      type: SessionType.apnea,
    );
    await repo.addApneaAttempt(
      sessionId: apnea.id,
      kind: ApneaKind.static,
      durationMs: 150000,
    );

    final document = await exportAndDecode();

    expect(table(document, 'exercises'), hasLength(1));
    expect(table(document, 'sessions'), hasLength(4));
    expect(table(document, 'swimDetails'), hasLength(1));
    expect(table(document, 'swimIntervals'), hasLength(1));
    expect(table(document, 'swimLaps'), hasLength(2));
    expect(table(document, 'runDetails'), hasLength(1));
    expect(table(document, 'apneaAttempts'), hasLength(1));

    final set = table(document, 'strengthSets').single as Map<String, dynamic>;
    expect(set['weight'], 225);
    expect(set['weightUnit'], 'lb'); // la unidad original, como texto
    expect(set['reps'], 5);
    expect(set['rpe'], 8.5);
    expect(set['sessionId'], strength.id);
    expect(set['exerciseId'], bench);
  });

  test('las fechas van en texto ISO 8601 y en UTC', () async {
    await repo.startSession(
      userId: userId,
      type: SessionType.run,
      startedAt: DateTime.utc(2026, 11, 10, 18, 5),
    );

    final session =
        table(await exportAndDecode(), 'sessions').single
            as Map<String, dynamic>;

    expect(session['startedAt'], '2026-11-10T18:05:00.000Z');
    expect(session['type'], 'run');
    expect(session['durationS'], isNull);
    expect(DateTime.parse(session['createdAt'] as String).isUtc, isTrue);
  });

  test('conserva las filas borradas, marcadas con deletedAt', () async {
    final exerciseId = await createExercise(userId, 'Sentadilla');
    final session = await repo.startSession(
      userId: userId,
      type: SessionType.strength,
    );
    await repo.addStrengthSet(
      sessionId: session.id,
      exerciseId: exerciseId,
      weight: 100,
      weightUnit: WeightUnit.kg,
      reps: 5,
    );
    await repo.deleteSession(session.id);

    final document = await exportAndDecode();

    final exported = table(document, 'sessions').single as Map<String, dynamic>;
    expect(exported['deletedAt'], isNotNull);
    expect(
      (table(document, 'strengthSets').single as Map)['deletedAt'],
      isNotNull,
    );
  });

  test('no incluye datos de otro usuario', () async {
    final other = await createUser('Hermana');
    await createExercise(other, 'Peso muerto');
    await repo.startSession(userId: other, type: SessionType.run);
    await createExercise(userId, 'Press de banca');

    final document = await exportAndDecode();

    expect((document['user'] as Map)['id'], userId);
    expect(table(document, 'sessions'), isEmpty);
    final exercise =
        table(document, 'exercises').single as Map<String, dynamic>;
    expect(exercise['name'], 'Press de banca');
  });
}
