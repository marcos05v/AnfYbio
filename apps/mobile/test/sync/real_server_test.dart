import 'dart:io';
import 'dart:math';

import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/export/backup_exporter.dart';
import 'package:anfybio/data/repositories/exercise_repository.dart';
import 'package:anfybio/data/repositories/training_repository.dart';
import 'package:anfybio/data/repositories/user_repository.dart';
import 'package:anfybio/data/tables/sessions.dart';
import 'package:anfybio/domain/weight.dart';
import 'package:anfybio/sync/sync_service.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contra la API real (apps/api). Se salta salvo que se indique dónde está:
///
///     ANFYBIO_SERVER=localhost flutter test test/sync/real_server_test.dart
///
/// Crea una cuenta nueva con un nombre al azar en esa base.
void main() {
  final address = Platform.environment['ANFYBIO_SERVER'];
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('dos teléfonos sincronizan a través del servidor real', () {
    // flutter_test bloquea la red a propósito; esta prueba sí la necesita.
    return HttpOverrides.runWithHttpOverrides(
      _realServerScenario,
      _RealNetwork(),
    );
  }, skip: address == null ? 'Indica ANFYBIO_SERVER para correrla' : false);
}

Future<void> _realServerScenario() async {
  final address = Platform.environment['ANFYBIO_SERVER']!;
  {
    Future<(AppDatabase, SyncService)> phone(String name) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      return (
        db,
        SyncService(db: db, preferences: prefs, tokens: MemoryTokenStore()),
      );
    }

    final username = 'prueba${Random().nextInt(1 << 30)}';
    final (dbA, syncA) = await phone('a');
    final user = await UserRepository(dbA).createUser('Prueba');
    final exercise = await ExerciseRepository(dbA).createExercise(
      userId: user.id,
      name: 'Sentadilla',
      defaultUnit: WeightUnit.lb,
    );
    final training = TrainingRepository(dbA);
    final session = await training.startSession(
      userId: user.id,
      type: SessionType.strength,
    );
    await training.addStrengthSet(
      sessionId: session.id,
      exerciseId: exercise.id,
      weight: 225,
      weightUnit: WeightUnit.lb,
      reps: 5,
      rpe: 8.5,
    );
    final pushed = await syncA.register(
      address: address,
      username: username,
      password: 'contraseña-segura',
    );
    expect(pushed.pushed, 4);
    expect(pushed.rejected, 0);

    final (dbB, syncB) = await phone('b');
    final pulled = await syncB.login(
      address: address,
      username: username,
      password: 'contraseña-segura',
    );
    expect(pulled.pulled, 4);
    expect(pulled.failed, 0);

    Future<Object?> snapshot(AppDatabase db) =>
        BackupExporter(db)
            .buildDocument(user.id, exportedAt: DateTime.utc(2026));
    expect(await snapshot(dbB), await snapshot(dbA));
  }
}

/// Sin reemplazos: conexiones de verdad.
class _RealNetwork extends HttpOverrides {}
