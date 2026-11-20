import 'dart:async';

import 'package:drift/drift.dart';

import '../../catalog/catalog_exercise.dart';
import '../../catalog/exercise_matching.dart';
import '../../domain/routine.dart';
import '../../domain/weight.dart';
import '../database.dart';
import 'training_repository.dart' show RecordNotFound;

/// La rutina activa completa, lista para mostrarse.
class RoutineView {
  const RoutineView({required this.routine, required this.days});

  final Routine routine;
  final List<RoutineDayView> days;
}

class RoutineDayView {
  const RoutineDayView({required this.day, required this.exercises});

  final RoutineDay day;
  final List<RoutineExercise> exercises;
}

/// Lectura y escritura de la rutina de entrenamiento.
///
/// Reglas que garantiza:
/// - un usuario tiene a lo sumo una rutina activa; guardar una nueva
///   desactiva la anterior, que se conserva;
/// - el borrado es lógico y en cascada (rutina → días → ejercicios);
/// - los hijos heredan el usuario de su padre;
/// - toda modificación actualiza `updatedAt`.
class RoutineRepository {
  RoutineRepository(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _now;

  // ------------------------------------------------------------------ rutina

  /// Guarda una rutina completa y la deja como activa, en una transacción.
  Future<String> saveRoutine(String userId, RoutineDraft draft) {
    return _db.transaction(() async {
      await (_db.update(_db.routines)..where(
            (r) =>
                r.userId.equals(userId) &
                r.isActive.equals(true) &
                r.deletedAt.isNull(),
          ))
          .write(
            RoutinesCompanion(
              isActive: const Value(false),
              updatedAt: Value(_now()),
            ),
          );

      final routine = await _db
          .into(_db.routines)
          .insertReturning(
            RoutinesCompanion.insert(
              userId: userId,
              name: draft.name.trim(),
              sourceFileName: Value(draft.sourceFileName),
            ),
          );
      for (final (dayIndex, dayDraft) in draft.days.indexed) {
        final day = await _db
            .into(_db.routineDays)
            .insertReturning(
              RoutineDaysCompanion.insert(
                userId: userId,
                routineId: routine.id,
                position: dayIndex + 1,
                name: dayDraft.name.trim(),
              ),
            );
        for (final (index, exercise) in dayDraft.exercises.indexed) {
          await _db
              .into(_db.routineExercises)
              .insert(_exerciseCompanion(userId, day.id, index + 1, exercise));
        }
      }
      return routine.id;
    });
  }

  /// Borra la rutina con sus días y ejercicios (borrado lógico). Las sesiones
  /// que la siguieron se conservan.
  Future<void> deleteRoutine(String routineId) {
    return _db.transaction(() async {
      final now = Value(_now());
      final deleted =
          await (_db.update(
            _db.routines,
          )..where((r) => r.id.equals(routineId) & r.deletedAt.isNull())).write(
            RoutinesCompanion(
              deletedAt: now,
              updatedAt: now,
              isActive: const Value(false),
            ),
          );
      if (deleted == 0) throw RecordNotFound(routineId);

      final dayIds = _db.selectOnly(_db.routineDays)
        ..addColumns([_db.routineDays.id])
        ..where(_db.routineDays.routineId.equals(routineId));
      await (_db.update(_db.routineExercises)
            ..where((e) => e.dayId.isInQuery(dayIds) & e.deletedAt.isNull()))
          .write(RoutineExercisesCompanion(deletedAt: now, updatedAt: now));
      await (_db.update(
            _db.routineDays,
          )..where((d) => d.routineId.equals(routineId) & d.deletedAt.isNull()))
          .write(RoutineDaysCompanion(deletedAt: now, updatedAt: now));
    });
  }

  /// La rutina activa del usuario con sus días y ejercicios; `null` si no
  /// tiene.
  Future<RoutineView?> activeRoutine(String userId) async {
    final routine =
        await (_db.select(_db.routines)
              ..where(
                (r) =>
                    r.userId.equals(userId) &
                    r.isActive.equals(true) &
                    r.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (routine == null) return null;

    final days =
        await (_db.select(_db.routineDays)
              ..where(
                (d) => d.routineId.equals(routine.id) & d.deletedAt.isNull(),
              )
              ..orderBy([(d) => OrderingTerm.asc(d.position)]))
            .get();
    final exercises =
        await (_db.select(_db.routineExercises)
              ..where(
                (e) =>
                    e.dayId.isIn(days.map((d) => d.id)) & e.deletedAt.isNull(),
              )
              ..orderBy([(e) => OrderingTerm.asc(e.position)]))
            .get();

    return RoutineView(
      routine: routine,
      days: [
        for (final day in days)
          RoutineDayView(
            day: day,
            exercises: [
              for (final exercise in exercises)
                if (exercise.dayId == day.id) exercise,
            ],
          ),
      ],
    );
  }

  /// Igual que [activeRoutine], pero vuelve a emitir cuando cambia.
  Stream<RoutineView?> watchActiveRoutine(String userId) {
    final changes = _db.tableUpdates(
      TableUpdateQuery.onAllTables([
        _db.routines,
        _db.routineDays,
        _db.routineExercises,
      ]),
    );
    late final StreamController<RoutineView?> controller;
    StreamSubscription<void>? subscription;

    Future<void> emit() async {
      final view = await activeRoutine(userId);
      if (!controller.isClosed) controller.add(view);
    }

    controller = StreamController<RoutineView?>(
      onListen: () {
        subscription = changes.listen((_) => emit());
        emit();
      },
      onCancel: () async {
        await subscription?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  /// Un día de rutina con sus ejercicios, para la sesión que lo sigue. Emite
  /// de nuevo cuando cambian sus ejercicios; `null` si el día no existe.
  Stream<RoutineDayView?> watchDay(String dayId) {
    final exercises = _db.select(_db.routineExercises)
      ..where((e) => e.dayId.equals(dayId) & e.deletedAt.isNull())
      ..orderBy([(e) => OrderingTerm.asc(e.position)]);
    return exercises.watch().asyncMap((exercises) async {
      final day = await (_db.select(
        _db.routineDays,
      )..where((d) => d.id.equals(dayId))).getSingleOrNull();
      return day == null
          ? null
          : RoutineDayView(day: day, exercises: exercises);
    });
  }

  // -------------------------------------------------------------------- días

  Future<RoutineDay> addDay(String routineId, {required String name}) {
    return _db.transaction(() async {
      final routine =
          await (_db.select(_db.routines)
                ..where((r) => r.id.equals(routineId) & r.deletedAt.isNull()))
              .getSingleOrNull();
      if (routine == null) throw RecordNotFound(routineId);

      return _db
          .into(_db.routineDays)
          .insertReturning(
            RoutineDaysCompanion.insert(
              userId: routine.userId,
              routineId: routineId,
              position: await _nextPosition(
                _db.routineDays,
                _db.routineDays.position,
                _db.routineDays.routineId,
                routineId,
              ),
              name: name.trim(),
            ),
          );
    });
  }

  Future<void> updateDay(String dayId, {required String name}) async {
    final updated =
        await (_db.update(
          _db.routineDays,
        )..where((d) => d.id.equals(dayId) & d.deletedAt.isNull())).write(
          RoutineDaysCompanion(
            name: Value(name.trim()),
            updatedAt: Value(_now()),
          ),
        );
    if (updated == 0) throw RecordNotFound(dayId);
  }

  /// Borra un día junto con sus ejercicios.
  Future<void> deleteDay(String dayId) {
    return _db.transaction(() async {
      final now = Value(_now());
      final deleted =
          await (_db.update(_db.routineDays)
                ..where((d) => d.id.equals(dayId) & d.deletedAt.isNull()))
              .write(RoutineDaysCompanion(deletedAt: now, updatedAt: now));
      if (deleted == 0) throw RecordNotFound(dayId);
      await (_db.update(_db.routineExercises)
            ..where((e) => e.dayId.equals(dayId) & e.deletedAt.isNull()))
          .write(RoutineExercisesCompanion(deletedAt: now, updatedAt: now));
    });
  }

  // -------------------------------------------------------------- ejercicios

  Future<RoutineExercise> addExercise(
    String dayId,
    RoutineExerciseDraft exercise,
  ) {
    return _db.transaction(() async {
      final day =
          await (_db.select(_db.routineDays)
                ..where((d) => d.id.equals(dayId) & d.deletedAt.isNull()))
              .getSingleOrNull();
      if (day == null) throw RecordNotFound(dayId);

      final position = await _nextPosition(
        _db.routineExercises,
        _db.routineExercises.position,
        _db.routineExercises.dayId,
        dayId,
      );
      return _db
          .into(_db.routineExercises)
          .insertReturning(
            _exerciseCompanion(day.userId, dayId, position, exercise),
          );
    });
  }

  /// Corrige un ejercicio de la rutina. Si cambia de nombre, se desenlaza
  /// del ejercicio con el que se registraba: ya es otro ejercicio.
  Future<void> updateExercise(
    String routineExerciseId,
    RoutineExerciseDraft exercise,
  ) {
    return _db.transaction(() async {
      final current = await _routineExercise(routineExerciseId);
      final renamed =
          current.name.trim().toLowerCase() !=
          exercise.name.trim().toLowerCase();

      await (_db.update(
        _db.routineExercises,
      )..where((e) => e.id.equals(routineExerciseId))).write(
        RoutineExercisesCompanion(
          name: Value(exercise.name.trim()),
          exerciseId: renamed ? const Value(null) : const Value.absent(),
          groupLabel: Value(_clean(exercise.groupLabel)),
          warmupSets: Value(exercise.warmupSets),
          workSets: Value(exercise.workSets),
          repsMin: Value(exercise.repsMin),
          repsMax: Value(exercise.repsMax),
          repsNote: Value(_clean(exercise.repsNote)),
          supersetWithPrevious: Value(exercise.supersetWithPrevious),
          note: Value(_clean(exercise.note)),
          updatedAt: Value(_now()),
        ),
      );
    });
  }

  Future<void> deleteExercise(String routineExerciseId) async {
    final now = Value(_now());
    final deleted =
        await (_db.update(_db.routineExercises)..where(
              (e) => e.id.equals(routineExerciseId) & e.deletedAt.isNull(),
            ))
            .write(RoutineExercisesCompanion(deletedAt: now, updatedAt: now));
    if (deleted == 0) throw RecordNotFound(routineExerciseId);
  }

  /// El ejercicio con el que se registran las series de un ejercicio de la
  /// rutina. La primera vez busca uno del usuario con el mismo nombre (sin
  /// distinguir mayúsculas) o lo crea, y deja el enlace guardado.
  Future<Exercise> exerciseFor(String routineExerciseId) {
    return _db.transaction(() async {
      final routineExercise = await _routineExercise(routineExerciseId);

      if (routineExercise.exerciseId case final linkedId?) {
        final linked =
            await (_db.select(_db.exercises)
                  ..where((e) => e.id.equals(linkedId) & e.deletedAt.isNull()))
                .getSingleOrNull();
        if (linked != null) return linked;
      }

      final name = routineExercise.name.trim();
      final existing =
          await (_db.select(_db.exercises)
                ..where(
                  (e) =>
                      e.userId.equals(routineExercise.userId) &
                      e.deletedAt.isNull() &
                      e.name.lower().equals(name.toLowerCase()),
                )
                ..limit(1))
              .getSingleOrNull();
      final exercise =
          existing ??
          await _db
              .into(_db.exercises)
              .insertReturning(
                ExercisesCompanion.insert(
                  userId: routineExercise.userId,
                  name: name.length > 100 ? name.substring(0, 100) : name,
                  defaultUnit: WeightUnit.kg,
                ),
              );

      await (_db.update(
        _db.routineExercises,
      )..where((e) => e.id.equals(routineExerciseId))).write(
        RoutineExercisesCompanion(
          exerciseId: Value(exercise.id),
          updatedAt: Value(_now()),
        ),
      );

      // Si ese nombre ya se había enlazado con el catálogo, el ejercicio
      // hereda el enlace.
      if (exercise.catalogId == null) {
        final alias =
            await (_db.select(_db.exerciseAliases)
                  ..where(
                    (a) =>
                        a.userId.equals(routineExercise.userId) &
                        a.alias.equals(normalizeText(name)) &
                        a.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (alias != null && isCatalogLink(alias.catalogId)) {
          await (_db.update(_db.exercises)
                ..where((e) => e.id.equals(exercise.id)))
              .write(ExercisesCompanion(catalogId: Value(alias.catalogId)));
          return exercise.copyWith(catalogId: Value(alias.catalogId));
        }
      }
      return exercise;
    });
  }

  // ---------------------------------------------------------------- internos

  Future<RoutineExercise> _routineExercise(String id) async {
    final exercise = await (_db.select(
      _db.routineExercises,
    )..where((e) => e.id.equals(id) & e.deletedAt.isNull())).getSingleOrNull();
    if (exercise == null) throw RecordNotFound(id);
    return exercise;
  }

  RoutineExercisesCompanion _exerciseCompanion(
    String userId,
    String dayId,
    int position,
    RoutineExerciseDraft exercise,
  ) {
    return RoutineExercisesCompanion.insert(
      userId: userId,
      dayId: dayId,
      position: position,
      name: exercise.name.trim(),
      groupLabel: Value(_clean(exercise.groupLabel)),
      warmupSets: Value(exercise.warmupSets),
      workSets: Value(exercise.workSets),
      repsMin: Value(exercise.repsMin),
      repsMax: Value(exercise.repsMax),
      repsNote: Value(_clean(exercise.repsNote)),
      supersetWithPrevious: Value(exercise.supersetWithPrevious),
      note: Value(_clean(exercise.note)),
    );
  }

  String? _clean(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<int> _nextPosition(
    TableInfo table,
    GeneratedColumn<int> position,
    GeneratedColumn<String> parentColumn,
    String parentId,
  ) async {
    final maxPosition = position.max();
    final query = _db.selectOnly(table)
      ..addColumns([maxPosition])
      ..where(parentColumn.equals(parentId));
    final current = await query.map((row) => row.read(maxPosition)).getSingle();
    return (current ?? 0) + 1;
  }
}
