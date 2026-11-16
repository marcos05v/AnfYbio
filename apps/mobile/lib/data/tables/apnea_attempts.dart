// Las restricciones check() de drift se escriben nombrando la propia columna;
// el analizador lo confunde con recursión, pero drift no ejecuta ese getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'sessions.dart';
import 'sync_columns.dart';
import 'users.dart';

/// static: apnea estática (se mide tiempo). dynamic: dinámica (se mide distancia).
enum ApneaKind { static, dynamic }

/// Un intento de apnea dentro de una sesión.
@TableIndex(name: 'apnea_attempts_session', columns: {#sessionId})
class ApneaAttempts extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get sessionId => text().references(Sessions, #id)();

  /// Orden del intento dentro de la sesión, empezando en 1.
  IntColumn get position => integer().check(position.isBiggerThanValue(0))();
  TextColumn get kind => textEnum<ApneaKind>()();
  IntColumn get durationMs =>
      integer().nullable().check(durationMs.isBiggerThanValue(0))();
  IntColumn get distanceM =>
      integer().nullable().check(distanceM.isBiggerThanValue(0))();

  /// La estática exige tiempo y la dinámica exige distancia. La dinámica puede
  /// llevar además el tiempo, si se midió.
  @override
  List<String> get customConstraints => [
    "CHECK ((kind = 'static' AND duration_ms IS NOT NULL) OR "
        "(kind = 'dynamic' AND distance_m IS NOT NULL))",
  ];
}
