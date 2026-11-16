import 'package:anfybio/data/database.dart';
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
  late String userId;
  late String exerciseId;

  // Reloj falso: las pruebas controlan qué hora "es".
  var clock = DateTime.utc(2026, 11, 16, 12);

  Future<String> createUser(String name) async {
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: name));
    return user.id;
  }

  Future<String> createExercise(String ownerId) async {
    final exercise = await db
        .into(db.exercises)
        .insertReturning(
          ExercisesCompanion.insert(
            userId: ownerId,
            name: 'Sentadilla',
            defaultUnit: WeightUnit.kg,
          ),
        );
    return exercise.id;
  }

  setUp(() async {
    clock = DateTime.utc(2026, 11, 16, 12);
    db = AppDatabase(NativeDatabase.memory());
    repo = TrainingRepository(
      db,
      now: () => clock,
      // Zona fija UTC−6 (centro de México), sin depender de la computadora.
      toLocal: (utc) => utc.subtract(const Duration(hours: 6)),
    );
    userId = await createUser('Prueba');
    exerciseId = await createExercise(userId);
  });
  tearDown(() => db.close());

  Future<String> start(SessionType type) async =>
      (await repo.startSession(userId: userId, type: type)).id;

  Future<StrengthSet> addSet(String sessionId, {bool isWarmup = false}) =>
      repo.addStrengthSet(
        sessionId: sessionId,
        exerciseId: exerciseId,
        weight: 100,
        weightUnit: WeightUnit.kg,
        reps: 5,
        isWarmup: isWarmup,
      );

  group('sesiones', () {
    test('una sesión nueva empieza ahora y queda en curso', () async {
      final session = await repo.startSession(
        userId: userId,
        type: SessionType.strength,
      );

      expect(session.startedAt, clock);
      expect(session.durationS, isNull);
      expect(session.sessionRpe, isNull);
    });

    test(
      'terminar la sesión guarda duración y RPE y actualiza updatedAt',
      () async {
        final id = await start(SessionType.strength);
        clock = clock.add(const Duration(hours: 1));

        await repo.finishSession(id, durationS: 3600, sessionRpe: 7);

        final session = (await repo.sessionsOf(userId)).single;
        expect(session.durationS, 3600);
        expect(session.sessionRpe, 7);
        expect(session.updatedAt, clock);
      },
    );

    test('lista las sesiones de la más reciente a la más antigua', () async {
      final old = await repo.startSession(
        userId: userId,
        type: SessionType.run,
        startedAt: DateTime.utc(2026, 11, 1),
      );
      final recent = await repo.startSession(
        userId: userId,
        type: SessionType.strength,
        startedAt: DateTime.utc(2026, 11, 15),
      );

      final sessions = await repo.sessionsOf(userId);
      expect(sessions.map((s) => s.id), [recent.id, old.id]);
    });

    test('no muestra las sesiones de otro usuario', () async {
      await start(SessionType.strength);
      final other = await createUser('Hermana');

      expect(await repo.sessionsOf(other), isEmpty);
    });

    test('no se puede terminar una sesión que no existe', () async {
      await expectLater(
        repo.finishSession('no-existe', durationS: 60, sessionRpe: 5),
        throwsA(isA<SessionNotFound>()),
      );
    });
  });

  group('fuerza', () {
    test('las series se numeran solas en el orden en que se agregan', () async {
      final id = await start(SessionType.strength);
      await addSet(id, isWarmup: true);
      await addSet(id);
      await addSet(id);

      final sets = await repo.strengthSetsOf(id);
      expect(sets.map((s) => s.position), [1, 2, 3]);
      expect(sets.map((s) => s.isWarmup), [true, false, false]);
    });

    test('la serie hereda el usuario de la sesión', () async {
      final id = await start(SessionType.strength);
      final set = await addSet(id);
      expect(set.userId, userId);
    });

    test('rechaza una serie de fuerza en una sesión de carrera', () async {
      final id = await start(SessionType.run);
      await expectLater(addSet(id), throwsA(isA<WrongSessionType>()));
    });

    test('rechaza un ejercicio que pertenece a otro usuario', () async {
      final id = await start(SessionType.strength);
      final other = await createUser('Hermana');
      final foreignExercise = await createExercise(other);

      await expectLater(
        repo.addStrengthSet(
          sessionId: id,
          exerciseId: foreignExercise,
          weight: 50,
          weightUnit: WeightUnit.kg,
          reps: 8,
        ),
        throwsA(isA<ExerciseNotFound>()),
      );
    });
  });

  group('natación', () {
    test('la sesión nace con su tamaño de alberca', () async {
      final session = await repo.startSwimSession(
        userId: userId,
        poolLengthM: 25,
      );

      final detail = await db.select(db.swimDetails).getSingle();
      expect(detail.sessionId, session.id);
      expect(detail.poolLengthM, 25);
    });

    test('startSession no acepta natación: exige el tamaño de alberca', () {
      expect(
        () => repo.startSession(userId: userId, type: SessionType.swim),
        throwsArgumentError,
      );
    });

    test('un bloque guarda sus parciales numerados desde 1', () async {
      final session = await repo.startSwimSession(
        userId: userId,
        poolLengthM: 25,
      );

      final interval = await repo.addSwimInterval(
        sessionId: session.id,
        stroke: SwimStroke.freestyle,
        distanceM: 100,
        durationMs: 95000,
        lapSplitsMs: [23000, 24000, 24000, 24000],
      );

      final laps = await db.select(db.swimLaps).get();
      expect(interval.position, 1);
      expect(laps.map((l) => l.lapNumber), [1, 2, 3, 4]);
      expect(laps.every((l) => l.intervalId == interval.id), isTrue);
    });

    test('rechaza un bloque de natación en una sesión de fuerza', () async {
      final id = await start(SessionType.strength);
      await expectLater(
        repo.addSwimInterval(
          sessionId: id,
          stroke: SwimStroke.freestyle,
          distanceM: 100,
          durationMs: 95000,
        ),
        throwsA(isA<WrongSessionType>()),
      );
    });
  });

  group('carrera', () {
    test('guardar la distancia dos veces la corrige, no la duplica', () async {
      final id = await start(SessionType.run);

      await repo.setRunDistance(id, distanceM: 5000);
      await repo.setRunDistance(id, distanceM: 5200);

      final details = await db.select(db.runDetails).get();
      expect(details.single.distanceM, 5200);
    });

    test('rechaza una distancia de carrera en una sesión de apnea', () async {
      final id = await start(SessionType.apnea);
      await expectLater(
        repo.setRunDistance(id, distanceM: 5000),
        throwsA(isA<WrongSessionType>()),
      );
    });
  });

  group('apnea', () {
    test('los intentos se numeran solos', () async {
      final id = await start(SessionType.apnea);
      final first = await repo.addApneaAttempt(
        sessionId: id,
        kind: ApneaKind.static,
        durationMs: 120000,
      );
      final second = await repo.addApneaAttempt(
        sessionId: id,
        kind: ApneaKind.dynamic,
        distanceM: 50,
      );

      expect([first.position, second.position], [1, 2]);
    });

    test('rechaza un intento de apnea en una sesión de natación', () async {
      final session = await repo.startSwimSession(
        userId: userId,
        poolLengthM: 25,
      );
      await expectLater(
        repo.addApneaAttempt(
          sessionId: session.id,
          kind: ApneaKind.static,
          durationMs: 120000,
        ),
        throwsA(isA<WrongSessionType>()),
      );
    });
  });

  group('borrado', () {
    test(
      'borrar una sesión de fuerza la oculta junto con sus series',
      () async {
        final id = await start(SessionType.strength);
        await addSet(id);
        await addSet(id);

        await repo.deleteSession(id);

        expect(await repo.sessionsOf(userId), isEmpty);
        expect(await repo.strengthSetsOf(id), isEmpty);
      },
    );

    test(
      'el borrado es lógico: las filas siguen en la base, marcadas',
      () async {
        final id = await start(SessionType.strength);
        await addSet(id);
        clock = clock.add(const Duration(minutes: 5));

        await repo.deleteSession(id);

        final session = await db.select(db.sessions).getSingle();
        final set = await db.select(db.strengthSets).getSingle();
        expect(session.deletedAt, clock);
        expect(set.deletedAt, clock);
        expect(set.updatedAt, clock);
      },
    );

    test(
      'borrar una sesión de natación marca detalle, bloques y vueltas',
      () async {
        final session = await repo.startSwimSession(
          userId: userId,
          poolLengthM: 25,
        );
        await repo.addSwimInterval(
          sessionId: session.id,
          stroke: SwimStroke.backstroke,
          distanceM: 50,
          durationMs: 50000,
          lapSplitsMs: [25000, 25000],
        );

        await repo.deleteSession(session.id);

        final detail = await db.select(db.swimDetails).getSingle();
        final intervals = await db.select(db.swimIntervals).get();
        final laps = await db.select(db.swimLaps).get();
        expect(detail.deletedAt, isNotNull);
        expect(intervals.every((i) => i.deletedAt != null), isTrue);
        expect(laps, hasLength(2));
        expect(laps.every((l) => l.deletedAt != null), isTrue);
      },
    );

    test('borrar una sesión no toca las demás', () async {
      final keep = await start(SessionType.strength);
      await addSet(keep);
      final remove = await start(SessionType.strength);
      await addSet(remove);

      await repo.deleteSession(remove);

      expect((await repo.sessionsOf(userId)).single.id, keep);
      expect(await repo.strengthSetsOf(keep), hasLength(1));
    });

    test('una sesión borrada ya no admite cambios', () async {
      final id = await start(SessionType.strength);
      await repo.deleteSession(id);

      await expectLater(addSet(id), throwsA(isA<SessionNotFound>()));
      await expectLater(
        repo.deleteSession(id),
        throwsA(isA<SessionNotFound>()),
      );
    });
  });

  group('carga', () {
    Future<void> finished(
      DateTime startedAt, {
      required int minutes,
      required int rpe,
      SessionType type = SessionType.strength,
    }) async {
      final session = await repo.startSession(
        userId: userId,
        type: type,
        startedAt: startedAt,
      );
      await repo.finishSession(
        session.id,
        durationS: minutes * 60,
        sessionRpe: rpe,
      );
    }

    test('calcula la carga sRPE de cada sesión terminada', () async {
      await finished(DateTime.utc(2026, 11, 10, 18), minutes: 60, rpe: 7);
      await finished(
        DateTime.utc(2026, 11, 11, 18),
        minutes: 30,
        rpe: 5,
        type: SessionType.run,
      );

      final entries = await repo.loadEntriesOf(userId);
      expect(entries.map((e) => e.load), unorderedEquals([420, 150]));
    });

    test('omite las sesiones en curso y las borradas', () async {
      await start(SessionType.strength); // en curso
      await finished(DateTime.utc(2026, 11, 10, 18), minutes: 60, rpe: 7);
      final deleted = await start(SessionType.run);
      await repo.finishSession(deleted, durationS: 1800, sessionRpe: 6);
      await repo.deleteSession(deleted);

      final entries = await repo.loadEntriesOf(userId);
      expect(entries.single.load, 420);
    });

    test('asigna la sesión a su día local, no al día en UTC', () async {
      // 02:00 UTC del día 11 son las 20:00 del día 10 en UTC−6.
      await finished(DateTime.utc(2026, 11, 11, 2), minutes: 60, rpe: 7);

      final entry = (await repo.loadEntriesOf(userId)).single;
      expect(entry.day.day, 10);
    });
  });
}
