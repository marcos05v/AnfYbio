import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';
import 'backup_exporter.dart';

/// El archivo no se puede importar. [message] está escrito para mostrarse
/// tal cual al usuario.
class BackupImportException implements Exception {
  const BackupImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Restaura un respaldo creado por [BackupExporter] (ADR-0007).
///
/// Solo funciona sobre una base sin usuarios: así no hay nada que
/// sobrescribir ni que combinar. Se importa todo o nada.
class BackupImporter {
  BackupImporter(this._db);

  final AppDatabase _db;

  static const _serializer = ValueSerializer.defaults(
    serializeDateTimeValuesAsString: true,
  );

  Future<void> import(String json) async {
    final document = _decode(json);

    if (document['format'] != 'anfybio-backup') {
      throw const BackupImportException(
        'Este archivo no es un respaldo de AnfYbio.',
      );
    }
    final formatVersion = document['formatVersion'];
    final schemaVersion = document['schemaVersion'];
    if (formatVersion is! int ||
        schemaVersion is! int ||
        formatVersion > backupFormatVersion ||
        schemaVersion > _db.schemaVersion) {
      throw const BackupImportException(
        'El respaldo viene de una versión más nueva de la app. '
        'Actualiza la app y vuelve a intentarlo.',
      );
    }

    try {
      await _db.transaction(() async {
        if (await _db.select(_db.users).get() case [_, ...]) {
          throw const BackupImportException(
            'Esta app ya tiene datos. Un respaldo solo se puede restaurar '
            'en una instalación nueva.',
          );
        }

        final tables = document['tables'] as Map<String, dynamic>;
        Iterable<Map<String, dynamic>> rows(String name) =>
            (tables[name] as List).cast<Map<String, dynamic>>();

        // El orden importa: cada tabla va después de aquellas a las que
        // apunta con una llave foránea.
        await _db
            .into(_db.users)
            .insert(
              User.fromJson(
                document['user'] as Map<String, dynamic>,
                serializer: _serializer,
              ),
            );
        for (final row in rows('exercises')) {
          await _db
              .into(_db.exercises)
              .insert(Exercise.fromJson(row, serializer: _serializer));
        }
        for (final row in rows('sessions')) {
          await _db
              .into(_db.sessions)
              .insert(Session.fromJson(row, serializer: _serializer));
        }
        for (final row in rows('strengthSets')) {
          await _db
              .into(_db.strengthSets)
              .insert(StrengthSet.fromJson(row, serializer: _serializer));
        }
        for (final row in rows('swimDetails')) {
          await _db
              .into(_db.swimDetails)
              .insert(SwimDetail.fromJson(row, serializer: _serializer));
        }
        for (final row in rows('swimIntervals')) {
          await _db
              .into(_db.swimIntervals)
              .insert(SwimInterval.fromJson(row, serializer: _serializer));
        }
        for (final row in rows('swimLaps')) {
          await _db
              .into(_db.swimLaps)
              .insert(SwimLap.fromJson(row, serializer: _serializer));
        }
        for (final row in rows('runDetails')) {
          await _db
              .into(_db.runDetails)
              .insert(RunDetail.fromJson(row, serializer: _serializer));
        }
        for (final row in rows('apneaAttempts')) {
          await _db
              .into(_db.apneaAttempts)
              .insert(ApneaAttempt.fromJson(row, serializer: _serializer));
        }
      });
    } on BackupImportException {
      rethrow;
    } catch (_) {
      // Un dato faltante, de otro tipo o que viola una regla de la base:
      // la transacción ya deshizo todo lo insertado.
      throw const BackupImportException(
        'El respaldo está dañado o incompleto. No se importó nada.',
      );
    }
  }

  Map<String, dynamic> _decode(String json) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupImportException(
        'Este archivo no es un respaldo de AnfYbio.',
      );
    }
  }
}
