import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/tables/exercises.dart';
import 'package:anfybio/data/tables/sessions.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late String userId;
  late String exerciseId;
  late String sessionId;

  // Cada prueba arranca con un usuario, un ejercicio y una sesión de fuerza.
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Prueba'));
    userId = user.id;
    final exercise = await db
        .into(db.exercises)
        .insertReturning(
          ExercisesCompanion.insert(
            userId: userId,
            name: 'Press de banca',
            defaultUnit: WeightUnit.lb,
          ),
        );
    exerciseId = exercise.id;
    final session = await db
        .into(db.sessions)
        .insertReturning(
          SessionsCompanion.insert(
            userId: userId,
            type: SessionType.strength,
            startedAt: DateTime.utc(2026, 11, 16, 18),
          ),
        );
    sessionId = session.id;
  });
  tearDown(() => db.close());

  StrengthSetsCompanion aSet({
    int position = 1,
    double weight = 225,
    int reps = 5,
    double? rpe,
    bool? isWarmup,
  }) => StrengthSetsCompanion.insert(
    userId: userId,
    sessionId: sessionId,
    exerciseId: exerciseId,
    position: position,
    weight: weight,
    weightUnit: WeightUnit.lb,
    reps: reps,
    rpe: Value(rpe),
    isWarmup: isWarmup == null ? const Value.absent() : Value(isWarmup),
  );

  test('una sesión en curso no tiene duración ni RPE', () async {
    final session = await db.select(db.sessions).getSingle();
    expect(session.durationS, isNull);
    expect(session.sessionRpe, isNull);
  });

  test('guarda el peso en la unidad capturada, sin convertir', () async {
    await db.into(db.strengthSets).insert(aSet(weight: 225, rpe: 8.5));

    final set = await db.select(db.strengthSets).getSingle();
    expect(set.weight, 225);
    expect(set.weightUnit, WeightUnit.lb);
    expect(set.rpe, 8.5);
  });

  test(
    'una serie es efectiva salvo que se marque como calentamiento',
    () async {
      await db
          .into(db.strengthSets)
          .insert(aSet(position: 1, weight: 135, isWarmup: true));
      await db.into(db.strengthSets).insert(aSet(position: 2, weight: 225));

      final sets = await (db.select(
        db.strengthSets,
      )..orderBy([(s) => OrderingTerm.asc(s.position)])).get();
      expect(sets.map((s) => s.isWarmup), [true, false]);
    },
  );

  test(
    'acepta peso cero (peso corporal) y cero repeticiones (fallo)',
    () async {
      await db.into(db.strengthSets).insert(aSet(weight: 0, reps: 0));
      expect(await db.select(db.strengthSets).get(), hasLength(1));
    },
  );

  test('rechaza valores fuera de rango', () async {
    Future<void> rejects(StrengthSetsCompanion set) => expectLater(
      db.into(db.strengthSets).insert(set),
      throwsA(isA<SqliteException>()),
    );

    await rejects(aSet(weight: -5));
    await rejects(aSet(reps: -1));
    await rejects(aSet(rpe: 11));
    await rejects(aSet(rpe: 0.5));
    await rejects(aSet(position: 0));
  });

  test('rechaza un RPE de sesión fuera de 1–10', () async {
    final update = db
        .update(db.sessions)
        .write(const SessionsCompanion(sessionRpe: Value(11)));
    await expectLater(update, throwsA(isA<SqliteException>()));
  });

  test('rechaza una serie de una sesión que no existe', () async {
    final insert = db
        .into(db.strengthSets)
        .insert(aSet().copyWith(sessionId: const Value('no-existe')));
    await expectLater(insert, throwsA(isA<SqliteException>()));
  });
}
