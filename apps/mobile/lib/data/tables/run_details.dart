// Las restricciones check() de drift se escriben nombrando la propia columna;
// el analizador lo confunde con recursión, pero drift no ejecuta ese getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'sessions.dart';
import 'sync_columns.dart';
import 'users.dart';

/// Datos propios de una sesión de carrera. Relación 1:1 con [Sessions].
///
/// La duración y el RPE están en la sesión; el ritmo se calcula.
class RunDetails extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get sessionId => text().unique().references(Sessions, #id)();
  IntColumn get distanceM => integer().check(distanceM.isBiggerThanValue(0))();
}
