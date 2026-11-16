// Las restricciones check() de drift se escriben nombrando la propia columna;
// el analizador lo confunde con recursión, pero drift no ejecuta ese getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'exercises.dart';
import 'sessions.dart';
import 'sync_columns.dart';
import 'users.dart';

/// Una serie de un ejercicio de fuerza dentro de una sesión.
@TableIndex(name: 'strength_sets_session', columns: {#sessionId})
@TableIndex(name: 'strength_sets_exercise', columns: {#exerciseId})
class StrengthSets extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get sessionId => text().references(Sessions, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();

  /// Orden de la serie dentro de la sesión, empezando en 1.
  IntColumn get position => integer().check(position.isBiggerThanValue(0))();

  /// Peso tal como se capturó, en la unidad de [weightUnit] (ADR-0002).
  /// Cero es válido: ejercicios con peso corporal.
  RealColumn get weight => real().check(weight.isBiggerOrEqualValue(0))();
  TextColumn get weightUnit => textEnum<WeightUnit>()();

  /// Cero es válido: una serie fallida.
  IntColumn get reps => integer().check(reps.isBiggerOrEqualValue(0))();

  /// Esfuerzo percibido de la serie, escala 1–10 con medios puntos (8.5).
  RealColumn get rpe => real().nullable().check(rpe.isBetweenValues(1, 10))();

  /// Calentamiento o aproximación: no cuenta para 1RM ni progresión.
  BoolColumn get isWarmup => boolean().withDefault(const Constant(false))();
}
