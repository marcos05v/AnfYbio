import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';

/// Versión del formato del archivo de respaldo. Sube cuando cambia su
/// estructura, para que una futura importación sepa cómo leer cada archivo.
const int backupFormatVersion = 1;

/// Un respaldo listo para guardarse o compartirse.
class Backup {
  const Backup({required this.fileName, required this.json});

  final String fileName;
  final String json;
}

/// Arma el respaldo completo de un usuario como un documento JSON (ADR-0005).
///
/// Incluye **todas** sus filas, también las borradas (con su `deletedAt`):
/// es una copia fiel de la base, no un informe.
class BackupExporter {
  BackupExporter(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Fechas como texto ISO 8601 en lugar de un número de milisegundos.
  static const _serializer = ValueSerializer.defaults(
    serializeDateTimeValuesAsString: true,
  );

  Future<Backup> export(String userId) async {
    final now = _now();
    final document = await buildDocument(userId, exportedAt: now);
    final date = now.toIso8601String().substring(0, 10);
    return Backup(
      fileName: 'anfybio-respaldo-$date.json',
      json: const JsonEncoder.withIndent('  ').convert(document),
    );
  }

  /// El contenido del respaldo como mapa, antes de convertirlo en texto.
  Future<Map<String, Object?>> buildDocument(
    String userId, {
    required DateTime exportedAt,
  }) async {
    final db = _db;
    final user = await (db.select(
      db.users,
    )..where((u) => u.id.equals(userId))).getSingle();

    // Todas las tablas se leen en una transacción para que el respaldo sea
    // una foto coherente, aunque se esté guardando algo al mismo tiempo.
    return db.transaction(() async {
      Future<List<Map<String, Object?>>> rows<
        T extends Table,
        D extends DataClass
      >(TableInfo<T, D> table, GeneratedColumn<String> userIdColumn) async {
        final query = db.select(table)
          ..where((_) => userIdColumn.equals(userId))
          ..orderBy([(_) => OrderingTerm.asc(table.columnsByName['id']!)]);
        return [
          for (final row in await query.get())
            row.toJson(serializer: _serializer),
        ];
      }

      return {
        'format': 'anfybio-backup',
        'formatVersion': backupFormatVersion,
        'schemaVersion': db.schemaVersion,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'user': user.toJson(serializer: _serializer),
        'tables': {
          'exercises': await rows(db.exercises, db.exercises.userId),
          'sessions': await rows(db.sessions, db.sessions.userId),
          'strengthSets': await rows(db.strengthSets, db.strengthSets.userId),
          'swimDetails': await rows(db.swimDetails, db.swimDetails.userId),
          'swimIntervals': await rows(
            db.swimIntervals,
            db.swimIntervals.userId,
          ),
          'swimLaps': await rows(db.swimLaps, db.swimLaps.userId),
          'runDetails': await rows(db.runDetails, db.runDetails.userId),
          'apneaAttempts': await rows(
            db.apneaAttempts,
            db.apneaAttempts.userId,
          ),
        },
      };
    });
  }
}
