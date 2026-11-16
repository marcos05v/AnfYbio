// Las restricciones check() de drift se escriben nombrando la propia columna;
// el analizador lo confunde con recursión, pero drift no ejecuta ese getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'sync_columns.dart';
import 'users.dart';

enum SessionType { strength, swim, run, apnea }

/// Una sesión de entrenamiento de cualquier tipo.
///
/// La duración y el RPE de sesión viven aquí, y no en las tablas de detalle,
/// porque la carga unificada (sRPE = RPE × minutos) los necesita para todos
/// los tipos por igual.
@TableIndex(name: 'sessions_user_started', columns: {#userId, #startedAt})
class Sessions extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get type => textEnum<SessionType>()();
  DateTimeColumn get startedAt => dateTime()();

  /// Nulos mientras la sesión está en curso; se capturan al terminarla.
  IntColumn get durationS =>
      integer().nullable().check(durationS.isBiggerThanValue(0))();

  /// Esfuerzo percibido de la sesión completa, escala 1–10.
  IntColumn get sessionRpe =>
      integer().nullable().check(sessionRpe.isBetweenValues(1, 10))();

  TextColumn get notes => text().nullable()();
}
