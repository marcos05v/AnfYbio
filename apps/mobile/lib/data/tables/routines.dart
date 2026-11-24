// Las restricciones check() de drift se escriben nombrando la propia columna;
// el analizador lo confunde con recursión, pero drift no ejecuta ese getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import '../../domain/routine.dart';
import 'exercises.dart';
import 'sync_columns.dart';
import 'users.dart';

/// Una rutina de entrenamiento: lo que toca hacer, no lo que se hizo.
///
/// Se conservan las rutinas anteriores; solo una está activa a la vez.
class Routines extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Nombre del archivo del que se importó; nulo si se capturó a mano.
  TextColumn get sourceFileName => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Indicaciones generales que el plan da antes del primer día: descansos,
  /// calentamiento, cómo progresar. Nulo si no trae.
  TextColumn get notes => text().nullable()();
}

/// Un día de la rutina: "Pecho y Tríceps".
@TableIndex(name: 'routine_days_routine', columns: {#routineId})
class RoutineDays extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get routineId => text().references(Routines, #id)();
  IntColumn get position => integer().check(position.isBiggerThanValue(0))();
  TextColumn get name => text().withLength(min: 1, max: 100)();
}

/// Un ejercicio de un día, con las series y repeticiones que se piden.
@TableIndex(name: 'routine_exercises_day', columns: {#dayId})
class RoutineExercises extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get dayId => text().references(RoutineDays, #id)();
  IntColumn get position => integer().check(position.isBiggerThanValue(0))();

  /// Como lo escribe la rutina.
  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// El ejercicio con el que se registran sus series. Se enlaza la primera
  /// vez que se usa; hasta entonces es nulo.
  TextColumn get exerciseId => text().nullable().references(Exercises, #id)();
  TextColumn get groupLabel => text().nullable()();
  IntColumn get warmupSets => integer()
      .withDefault(const Constant(0))
      .check(warmupSets.isBiggerOrEqualValue(0))();
  IntColumn get workSets =>
      integer().nullable().check(workSets.isBiggerThanValue(0))();
  IntColumn get repsMin =>
      integer().nullable().check(repsMin.isBiggerThanValue(0))();
  IntColumn get repsMax =>
      integer().nullable().check(repsMax.isBiggerThanValue(0))();
  TextColumn get repsNote => text().nullable()();

  /// Forma biserie con el ejercicio anterior del mismo día.
  BoolColumn get supersetWithPrevious =>
      boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();

  /// Básico o accesorio, si el usuario lo eligió. Nulo: se deduce del nombre
  /// cada vez que se muestra (así mejora si mejora la deducción).
  TextColumn get role => textEnum<ExerciseRole>().nullable()();
}
