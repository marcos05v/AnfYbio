// Las restricciones check() de drift se escriben nombrando la propia columna;
// el analizador lo confunde con recursión, pero drift no ejecuta ese getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'sessions.dart';
import 'sync_columns.dart';
import 'users.dart';

enum SwimStroke { freestyle, backstroke, breaststroke, butterfly, medley }

/// Datos propios de una sesión de natación. Relación 1:1 con [Sessions].
class SwimDetails extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get sessionId => text().unique().references(Sessions, #id)();
  IntColumn get poolLengthM =>
      integer().check(poolLengthM.isBiggerThanValue(0))();
}

/// Un bloque nadado con un mismo estilo (por ejemplo, 400 m libre).
@TableIndex(name: 'swim_intervals_session', columns: {#sessionId})
class SwimIntervals extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get sessionId => text().references(Sessions, #id)();

  /// Orden del bloque dentro de la sesión, empezando en 1.
  IntColumn get position => integer().check(position.isBiggerThanValue(0))();
  TextColumn get stroke => textEnum<SwimStroke>()();
  IntColumn get distanceM => integer().check(distanceM.isBiggerThanValue(0))();

  /// Tiempo total del bloque. El ritmo por 100 m se calcula, no se guarda.
  IntColumn get durationMs =>
      integer().check(durationMs.isBiggerThanValue(0))();
}

/// Parcial de una vuelta dentro de un bloque. Es opcional registrarlos.
@TableIndex(name: 'swim_laps_interval', columns: {#intervalId})
class SwimLaps extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get intervalId => text().references(SwimIntervals, #id)();
  IntColumn get lapNumber => integer().check(lapNumber.isBiggerThanValue(0))();
  IntColumn get splitMs => integer().check(splitMs.isBiggerThanValue(0))();
}
