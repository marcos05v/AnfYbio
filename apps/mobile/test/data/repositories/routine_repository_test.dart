import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/repositories/routine_repository.dart';
import 'package:anfybio/data/repositories/training_repository.dart';
import 'package:anfybio/data/tables/sessions.dart';
import 'package:anfybio/domain/routine.dart';
import 'package:anfybio/domain/weight.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late RoutineRepository repo;
  late TrainingRepository training;
  late String userId;
  var clock = DateTime.utc(2026, 11, 16, 12);

  setUp(() async {
    clock = DateTime.utc(2026, 11, 16, 12);
    db = AppDatabase(NativeDatabase.memory());
    repo = RoutineRepository(db, now: () => clock);
    training = TrainingRepository(db, now: () => clock);
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Prueba'));
    userId = user.id;
  });
  tearDown(() => db.close());

  const draft = RoutineDraft(
    name: 'Rutina de prueba',
    sourceFileName: 'rutina.pdf',
    days: [
      RoutineDayDraft(
        name: 'Pecho y Tríceps',
        exercises: [
          RoutineExerciseDraft(
            name: 'Press de banca',
            groupLabel: 'Pecho',
            warmupSets: 2,
            workSets: 4,
            repsMin: 8,
            repsMax: 12,
            note: 'Ejercicio principal',
          ),
          RoutineExerciseDraft(name: 'Press inclinado', workSets: 4),
          RoutineExerciseDraft(
            name: 'Aperturas',
            workSets: 3,
            supersetWithPrevious: true,
          ),
        ],
      ),
      RoutineDayDraft(
        name: 'Pierna',
        exercises: [
          RoutineExerciseDraft(
            name: 'Plancha',
            workSets: 3,
            repsNote: 'al fallo',
          ),
        ],
      ),
      RoutineDayDraft(name: 'Espalda'),
    ],
  );

  Future<RoutineView> saved() async {
    await repo.saveRoutine(userId, draft);
    return (await repo.activeRoutine(userId))!;
  }

  group('guardar y leer', () {
    test('guarda días y ejercicios en orden', () async {
      final view = await saved();

      expect(view.routine.name, 'Rutina de prueba');
      expect(view.routine.sourceFileName, 'rutina.pdf');
      expect(view.days.map((d) => (d.day.position, d.day.name)), [
        (1, 'Pecho y Tríceps'),
        (2, 'Pierna'),
        (3, 'Espalda'),
      ]);
      final bench = view.days.first.exercises.first;
      expect((bench.warmupSets, bench.workSets), (2, 4));
      expect((bench.repsMin, bench.repsMax), (8, 12));
      expect((bench.groupLabel, bench.note), ('Pecho', 'Ejercicio principal'));
      expect(bench.exerciseId, isNull); // aún no se ha usado
      expect(view.days.first.exercises.map((e) => e.supersetWithPrevious), [
        false,
        false,
        true,
      ]);
      expect(view.days[1].exercises.single.repsNote, 'al fallo');
    });

    test('guardar otra rutina desactiva la anterior y la conserva', () async {
      final first = await repo.saveRoutine(userId, draft);
      final second = await repo.saveRoutine(
        userId,
        const RoutineDraft(name: 'Nueva'),
      );

      expect((await repo.activeRoutine(userId))!.routine.id, second);
      final old = (await db.select(db.routines).get()).singleWhere(
        (r) => r.id == first,
      );
      expect((old.isActive, old.deletedAt), (false, null));
    });

    test('sin rutina, la activa es nula', () async {
      expect(await repo.activeRoutine(userId), isNull);
    });

    test('borrar la rutina borra días y ejercicios, no las sesiones', () async {
      final view = await saved();
      final session = await training.startSession(
        userId: userId,
        type: SessionType.strength,
        routineDayId: view.days.first.day.id,
      );

      await repo.deleteRoutine(view.routine.id);

      expect(await repo.activeRoutine(userId), isNull);
      expect(
        (await db.select(db.routineExercises).get()).every(
          (e) => e.deletedAt != null,
        ),
        isTrue,
      );
      expect((await training.sessionsOf(userId)).single.id, session.id);
    });
  });

  group('editar', () {
    test('agregar, renombrar y borrar un día', () async {
      final view = await saved();

      final day = await repo.addDay(view.routine.id, name: ' Hombro ');
      expect((day.position, day.name), (4, 'Hombro'));

      await repo.updateDay(day.id, name: 'Hombro completo');
      await repo.deleteDay(view.days.first.day.id);

      final days = (await repo.activeRoutine(userId))!.days;
      expect(days.map((d) => d.day.name), [
        'Pierna',
        'Espalda',
        'Hombro completo',
      ]);
      // Los ejercicios del día borrado también quedaron borrados.
      final orphans = (await db.select(db.routineExercises).get()).where(
        (e) => e.dayId == view.days.first.day.id && e.deletedAt == null,
      );
      expect(orphans, isEmpty);
    });

    test('agregar, editar y borrar un ejercicio', () async {
      final view = await saved();
      final dayId = view.days.last.day.id;

      final added = await repo.addExercise(
        dayId,
        const RoutineExerciseDraft(name: 'Jalón al pecho', workSets: 4),
      );
      expect(added.position, 1);

      await repo.updateExercise(
        added.id,
        const RoutineExerciseDraft(
          name: 'Jalón al pecho',
          workSets: 5,
          repsMin: 10,
          repsMax: 12,
        ),
      );
      var exercises = (await repo.activeRoutine(userId))!.days.last.exercises;
      expect((exercises.single.workSets, exercises.single.repsMax), (5, 12));

      await repo.deleteExercise(added.id);
      exercises = (await repo.activeRoutine(userId))!.days.last.exercises;
      expect(exercises, isEmpty);
    });

    test('no se puede editar lo que no existe', () async {
      await expectLater(
        repo.updateDay('no-existe', name: 'X'),
        throwsA(isA<RecordNotFound>()),
      );
      await expectLater(
        repo.deleteExercise('no-existe'),
        throwsA(isA<RecordNotFound>()),
      );
    });
  });

  group('ejercicio con el que se registran las series', () {
    test('la primera vez lo crea y deja el enlace guardado', () async {
      final view = await saved();
      final bench = view.days.first.exercises.first;

      final exercise = await repo.exerciseFor(bench.id);

      expect(exercise.name, 'Press de banca');
      expect(exercise.userId, userId);
      final linked = (await repo.activeRoutine(userId))!
          .days
          .first
          .exercises
          .first;
      expect(linked.exerciseId, exercise.id);
      // Pedirlo de nuevo devuelve el mismo, no crea otro.
      expect((await repo.exerciseFor(bench.id)).id, exercise.id);
      expect(await db.select(db.exercises).get(), hasLength(1));
    });

    test('reutiliza un ejercicio que ya existe con el mismo nombre', () async {
      final existing = await db
          .into(db.exercises)
          .insertReturning(
            ExercisesCompanion.insert(
              userId: userId,
              name: 'PRESS DE BANCA', // distinto en mayúsculas
              defaultUnit: WeightUnit.lb,
            ),
          );
      final view = await saved();

      final exercise = await repo.exerciseFor(
        view.days.first.exercises.first.id,
      );

      expect(exercise.id, existing.id);
      expect(exercise.defaultUnit, WeightUnit.lb);
    });

    test('renombrar el ejercicio de la rutina lo desenlaza', () async {
      final view = await saved();
      final bench = view.days.first.exercises.first;
      await repo.exerciseFor(bench.id);

      await repo.updateExercise(
        bench.id,
        const RoutineExerciseDraft(name: 'Press con mancuernas', workSets: 4),
      );

      final renamed = (await repo.activeRoutine(userId))!
          .days
          .first
          .exercises
          .first;
      expect(renamed.exerciseId, isNull);
    });

    test('cambiar solo sus series conserva el enlace', () async {
      final view = await saved();
      final bench = view.days.first.exercises.first;
      final exercise = await repo.exerciseFor(bench.id);

      await repo.updateExercise(
        bench.id,
        const RoutineExerciseDraft(name: 'Press de banca', workSets: 5),
      );

      final edited = (await repo.activeRoutine(userId))!
          .days
          .first
          .exercises
          .first;
      expect(edited.exerciseId, exercise.id);
    });
  });

  group('sesión ligada a la rutina', () {
    test('la sesión recuerda qué día siguió', () async {
      final view = await saved();
      final session = await training.startSession(
        userId: userId,
        type: SessionType.strength,
        routineDayId: view.days[1].day.id,
      );
      expect(session.routineDayId, view.days[1].day.id);
    });

    test('solo una sesión de fuerza puede seguir un día de rutina', () async {
      final view = await saved();
      expect(
        () => training.startSession(
          userId: userId,
          type: SessionType.run,
          routineDayId: view.days.first.day.id,
        ),
        throwsArgumentError,
      );
    });

    test(
      'registrar en otra unidad la deja como habitual del ejercicio',
      () async {
        final view = await saved();
        final exercise = await repo.exerciseFor(
          view.days.first.exercises.first.id,
        );
        expect(exercise.defaultUnit, WeightUnit.kg);
        final session = await training.startSession(
          userId: userId,
          type: SessionType.strength,
        );

        await training.addStrengthSet(
          sessionId: session.id,
          exerciseId: exercise.id,
          weight: 225,
          weightUnit: WeightUnit.lb,
          reps: 5,
        );

        final updated = await db.select(db.exercises).getSingle();
        expect(updated.defaultUnit, WeightUnit.lb);
      },
    );
  });

  test(
    'watchActiveRoutine vuelve a emitir cuando cambia un ejercicio',
    () async {
      final view = await saved();
      final counts = <int>[];
      final subscription = repo.watchActiveRoutine(userId).listen((routine) {
        counts.add(routine!.days.expand((d) => d.exercises).length);
      });
      await pumpEventQueue();
      expect(counts, [4]);

      await repo.addExercise(
        view.days.last.day.id,
        const RoutineExerciseDraft(name: 'Remo'),
      );
      await pumpEventQueue();

      expect(counts.last, 5);
      await subscription.cancel();
    },
  );
}
