import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
// Lo usa el código generado (database.g.dart) para crear los UUID.
import 'package:uuid/uuid.dart';

import '../domain/weight.dart';
import 'tables/apnea_attempts.dart';
import 'tables/exercises.dart';
import 'tables/run_details.dart';
import 'tables/sessions.dart';
import 'tables/strength_sets.dart';
import 'tables/swim.dart';
import 'tables/users.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Exercises,
    Sessions,
    StrengthSets,
    SwimDetails,
    SwimIntervals,
    SwimLaps,
    RunDetails,
    ApneaAttempts,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// En pruebas se pasa una base en memoria; en la app se usa el archivo real.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'anfybio'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // SQLite no valida las llaves foráneas a menos que se active en cada
      // conexión. Sin esto, un ejercicio podría apuntar a un usuario inexistente.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
