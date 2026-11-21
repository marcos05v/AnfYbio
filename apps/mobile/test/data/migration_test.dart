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

  test('de la versión 1 a la actual: el esquema queda como el de una '
      'instalación nueva y los datos se conservan', () async {
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
    await verifier.migrateAndValidate(db, 9);

    final user = await db.select(db.users).getSingle();
    final session = await db.select(db.sessions).getSingle();
    expect(user.displayName, 'Marcos');
    expect(session.type, SessionType.strength);
    expect(session.startedAt, DateTime.utc(2026, 11, 2, 18));
    expect((session.durationS, session.sessionRpe), (3600, 7));
    // Las tablas nuevas existen y están vacías.
    expect(await db.select(db.nutritionPlans).get(), isEmpty);
    expect(await db.select(db.planItems).get(), isEmpty);
    expect(await db.select(db.routines).get(), isEmpty);
    // La sesión antigua queda como sesión libre.
    expect(session.routineDayId, isNull);
    await db.close();
  });

  test('de la versión 2 a la actual: se conserva el plan de alimentación', () async {
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase
      ..execute(
        "INSERT INTO users (id, created_at, updated_at, display_name) VALUES "
        "('u1', '2026-11-01T10:00:00.000Z', '2026-11-01T10:00:00.000Z', 'Marcos')",
      )
      ..execute(
        "INSERT INTO nutrition_plans (id, created_at, updated_at, user_id, name, "
        "is_active) VALUES ('p1', '2026-11-10T10:00:00.000Z', "
        "'2026-11-10T10:00:00.000Z', 'u1', 'Plan', 1)",
      )
      ..execute(
        "INSERT INTO sessions (id, created_at, updated_at, user_id, type, "
        "started_at) VALUES ('s1', '2026-11-12T18:00:00.000Z', "
        "'2026-11-12T18:00:00.000Z', 'u1', 'run', '2026-11-12T18:00:00.000Z')",
      );

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final plan = await db.select(db.nutritionPlans).getSingle();
    final session = await db.select(db.sessions).getSingle();
    expect((plan.name, plan.isActive), ('Plan', true));
    expect((session.type, session.routineDayId), (SessionType.run, null));
    await db.close();
  });

  test(
    'de la versión 3 a la actual: se conserva la rutina y su sesión',
    () async {
      final schema = await verifier.schemaAt(3);
      const stamp = "'2026-11-10T10:00:00.000Z'";
      schema.rawDatabase
        ..execute(
          "INSERT INTO users (id, created_at, updated_at, display_name) VALUES "
          "('u1', $stamp, $stamp, 'Marcos')",
        )
        ..execute(
          "INSERT INTO routines (id, created_at, updated_at, user_id, name, "
          "is_active) VALUES ('r1', $stamp, $stamp, 'u1', 'Rutina', 1)",
        )
        ..execute(
          "INSERT INTO routine_days (id, created_at, updated_at, user_id, "
          "routine_id, position, name) VALUES "
          "('d1', $stamp, $stamp, 'u1', 'r1', 1, 'Empuje')",
        )
        ..execute(
          "INSERT INTO sessions (id, created_at, updated_at, user_id, type, "
          "started_at, routine_day_id) VALUES "
          "('s1', $stamp, $stamp, 'u1', 'strength', $stamp, 'd1')",
        );

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      final day = await db.select(db.routineDays).getSingle();
      final session = await db.select(db.sessions).getSingle();
      expect(day.name, 'Empuje');
      expect(session.routineDayId, 'd1');
      expect(await db.select(db.cookingBatches).get(), isEmpty);
      await db.close();
    },
  );

  test(
    'de la versión 4 a la actual: se conservan los lotes de cocción',
    () async {
      final schema = await verifier.schemaAt(4);
      const stamp = "'2026-11-14T13:00:00.000Z'";
      schema.rawDatabase
        ..execute(
          "INSERT INTO users (id, created_at, updated_at, display_name) VALUES "
          "('u1', $stamp, $stamp, 'Marcos')",
        )
        ..execute(
          "INSERT INTO cooking_batches (id, created_at, updated_at, user_id, "
          "food_name, raw_weight_g, cooked_weight_g, cooked_at) VALUES "
          "('b1', $stamp, $stamp, 'u1', 'Pollo', 1000, 720, $stamp)",
        );

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      final batch = await db.select(db.cookingBatches).getSingle();
      expect((batch.foodName, batch.cookedWeightG), ('Pollo', 720));
      expect(await db.select(db.supplements).get(), isEmpty);
      await db.close();
    },
  );

  test(
    'de la versión 5 a la actual: los suplementos quedan sin recordatorio',
    () async {
      final schema = await verifier.schemaAt(5);
      const stamp = "'2026-11-16T13:00:00.000Z'";
      schema.rawDatabase
        ..execute(
          "INSERT INTO users (id, created_at, updated_at, display_name) VALUES "
          "('u1', $stamp, $stamp, 'Marcos')",
        )
        ..execute(
          "INSERT INTO supplements (id, created_at, updated_at, user_id, name, "
          "unit_label, daily_dose, restock_lead_days) VALUES "
          "('s1', $stamp, $stamp, 'u1', 'Creatina', 'g', 5, 7)",
        );

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      final supplement = await db.select(db.supplements).getSingle();
      expect((supplement.name, supplement.dailyDose), ('Creatina', 5));
      expect(supplement.reminderMinute, isNull);
      await db.close();
    },
  );

  test('de la versión 6 a la 7: se conserva el recordatorio', () async {
    final schema = await verifier.schemaAt(6);
    const stamp = "'2026-11-18T13:00:00.000Z'";
    schema.rawDatabase
      ..execute(
        "INSERT INTO users (id, created_at, updated_at, display_name) VALUES "
        "('u1', $stamp, $stamp, 'Marcos')",
      )
      ..execute(
        "INSERT INTO supplements (id, created_at, updated_at, user_id, name, "
        "unit_label, daily_dose, restock_lead_days, reminder_minute) VALUES "
        "('s1', $stamp, $stamp, 'u1', 'Creatina', 'g', 5, 7, 570)",
      );

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final supplement = await db.select(db.supplements).getSingle();
    expect(supplement.reminderMinute, 570);
    expect(await db.select(db.exerciseAliases).get(), isEmpty);
    await db.close();
  });

  test('de la versión 7 a la 8: los ejercicios quedan sin forma de medir '
      'elegida', () async {
    final schema = await verifier.schemaAt(7);
    const stamp = "'2026-11-01T10:00:00.000Z'";
    schema.rawDatabase
      ..execute(
        "INSERT INTO users (id, created_at, updated_at, display_name) VALUES "
        "('u1', $stamp, $stamp, 'Marcos')",
      )
      ..execute(
        "INSERT INTO exercises (id, created_at, updated_at, user_id, name, "
        "default_unit) VALUES ('e1', $stamp, $stamp, 'u1', 'Press Arnold', 'kg')",
      );

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final exercise = await db.select(db.exercises).getSingle();
    expect(exercise.name, 'Press Arnold');
    // Sin elegir: la app la deduce del catálogo hasta que se confirme.
    expect(exercise.loadMode, isNull);
    await db.close();
  });

  test('de la versión 8 a la 9: los alimentos quedan sueltos, sin plato ni '
      'alternativa', () async {
    final schema = await verifier.schemaAt(8);
    const stamp = "'2026-11-01T10:00:00.000Z'";
    schema.rawDatabase
      ..execute(
        "INSERT INTO users (id, created_at, updated_at, display_name) VALUES "
        "('u1', $stamp, $stamp, 'Marcos')",
      )
      ..execute(
        "INSERT INTO nutrition_plans (id, created_at, updated_at, user_id, "
        "name, is_active) VALUES ('p1', $stamp, $stamp, 'u1', 'Plan', 1)",
      )
      ..execute(
        "INSERT INTO plan_menus (id, created_at, updated_at, user_id, plan_id, "
        "day_type, title) VALUES ('m1', $stamp, $stamp, 'u1', 'p1', "
        "'training', 'Entreno')",
      )
      ..execute(
        "INSERT INTO plan_meals (id, created_at, updated_at, user_id, menu_id, "
        "position, name) VALUES ('c1', $stamp, $stamp, 'u1', 'm1', 1, "
        "'Desayuno')",
      )
      ..execute(
        "INSERT INTO plan_items (id, created_at, updated_at, user_id, meal_id, "
        "position, name, amount, unit, state, is_free) VALUES ('i1', $stamp, "
        "$stamp, 'u1', 'c1', 1, 'Avena', 50, 'gram', 'dry', 0)",
      )
      ..execute(
        "INSERT INTO exercises (id, created_at, updated_at, user_id, name, "
        "default_unit, load_mode) VALUES ('e1', $stamp, $stamp, 'u1', "
        "'Press Arnold', 'kg', 'perHand')",
      );

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final item = await db.select(db.planItems).getSingle();
    expect((item.name, item.amount), ('Avena', 50));
    expect((item.parentItemId, item.alternativeOfId), (null, null));
    final exercise = await db.select(db.exercises).getSingle();
    expect(exercise.loadMode?.name, 'perHand');
    await db.close();
  });

  test('una instalación nueva crea directamente el esquema actual', () async {
    final db = AppDatabase(await verifier.startAt(9));
    await verifier.migrateAndValidate(db, 9);
    await db.close();
  });
}
