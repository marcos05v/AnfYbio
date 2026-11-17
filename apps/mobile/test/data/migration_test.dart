import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/tables/sessions.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_migrations/schema.dart';

/// Comprueba que una app instalada con una versión anterior de la base se
/// actualiza a la actual sin perder datos.
///
/// `drift_schemas/` guarda una copia del esquema de cada versión publicada;
/// de ahí salen los auxiliares de `generated_migrations/`.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('de la versión 1 a la 2: el esquema queda como el de una instalación '
      'nueva y los datos se conservan', () async {
    final schema = await verifier.schemaAt(1);

    // Datos escritos por la versión 1: un usuario con una sesión terminada.
    schema.rawDatabase
      ..execute(
        "INSERT INTO users (id, created_at, updated_at, display_name) VALUES "
        "('u1', '2026-11-01T10:00:00.000Z', '2026-11-01T10:00:00.000Z', 'Marcos')",
      )
      ..execute(
        "INSERT INTO sessions (id, created_at, updated_at, user_id, type, "
        "started_at, duration_s, session_rpe) VALUES "
        "('s1', '2026-11-02T18:00:00.000Z', '2026-11-02T19:00:00.000Z', 'u1', "
        "'strength', '2026-11-02T18:00:00.000Z', 3600, 7)",
      );

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);

    final user = await db.select(db.users).getSingle();
    final session = await db.select(db.sessions).getSingle();
    expect(user.displayName, 'Marcos');
    expect(session.type, SessionType.strength);
    expect(session.startedAt, DateTime.utc(2026, 11, 2, 18));
    expect((session.durationS, session.sessionRpe), (3600, 7));
    // Las tablas nuevas existen y están vacías.
    expect(await db.select(db.nutritionPlans).get(), isEmpty);
    expect(await db.select(db.planItems).get(), isEmpty);
    await db.close();
  });

  test('una instalación nueva crea directamente el esquema actual', () async {
    final db = AppDatabase(await verifier.startAt(2));
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });
}
