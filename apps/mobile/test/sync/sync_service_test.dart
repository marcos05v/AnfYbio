import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/export/backup_exporter.dart';
import 'package:anfybio/data/repositories/exercise_repository.dart';
import 'package:anfybio/data/repositories/training_repository.dart';
import 'package:anfybio/data/repositories/user_repository.dart';
import 'package:anfybio/data/tables/sessions.dart';
import 'package:anfybio/domain/weight.dart';
import 'package:anfybio/sync/sync_api.dart';
import 'package:anfybio/sync/sync_service.dart';
import 'package:anfybio/sync/sync_tables.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

/// Un teléfono: su base, sus preferencias y su sincronización.
class Phone {
  Phone._(this.db, this.sync, this.tokens);

  static Future<Phone> create(FakeSyncServer server) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Cada teléfono con sus propias preferencias.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final tokens = MemoryTokenStore();
    final sync = SyncService(
      db: db,
      preferences: _IsolatedPrefs(prefs),
      tokens: tokens,
      apiFor: (uri) => SyncApi(uri, client: server.client),
    );
    return Phone._(db, sync, tokens);
  }

  final AppDatabase db;
  final SyncService sync;
  final MemoryTokenStore tokens;

  TrainingRepository get training => TrainingRepository(db);

  Future<User?> user() => UserRepository(db).watchCurrentUser().first;

  /// Una sesión de fuerza con una serie.
  Future<(Session, StrengthSet)> logWorkout(String userId) async {
    final exercise = await ExerciseRepository(db).createExercise(
      userId: userId,
      name: 'Press de banca',
      defaultUnit: WeightUnit.kg,
    );
    final session = await training.startSession(
      userId: userId,
      type: SessionType.strength,
    );
    final set = await training.addStrengthSet(
      sessionId: session.id,
      exerciseId: exercise.id,
      weight: 60,
      weightUnit: WeightUnit.kg,
      reps: 8,
    );
    return (session, set);
  }

  /// Todos los datos del usuario, como en un respaldo.
  Future<Map<String, Object?>> snapshot(String userId) async {
    final document = await BackupExporter(db)
        .buildDocument(userId, exportedAt: DateTime.utc(2026));
    return document;
  }
}

void main() {
  late FakeSyncServer server;
  const address = 'mi-mac.local';

  // Cada teléfono tiene su propia base en memoria: es intencional.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() => server = FakeSyncServer());

  test('cubre todas las tablas de la base', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(
      syncTablesOf(db).map((t) => t.table.actualTableName).toSet(),
      db.allTables.map((t) => t.actualTableName).toSet(),
    );
  });

  test('la dirección se completa con http y el puerto 4310', () {
    expect(serverUri('mi-mac.local').toString(), 'http://mi-mac.local:4310');
    expect(
      serverUri(' 192.168.1.20:8080 ').toString(),
      'http://192.168.1.20:8080',
    );
    expect(() => serverUri('  '), throwsA(isA<SyncException>()));
  });

  test('un teléfono nuevo recibe exactamente los datos del otro', () async {
    final mine = await Phone.create(server);
    final user = await UserRepository(mine.db).createUser('Marcos');
    await mine.logWorkout(user.id);

    final first = await mine.sync.register(
      address: address,
      username: 'marcos',
      password: 'contraseña-segura',
    );
    // Usuario, ejercicio, sesión y serie.
    expect(first.pushed, 4);

    final other = await Phone.create(server);
    final report = await other.sync.login(
      address: address,
      username: 'marcos',
      password: 'contraseña-segura',
    );

    expect(report.pulled, 4);
    expect(report.failed, 0);
    expect((await other.user())!.id, user.id);
    expect(await other.snapshot(user.id), await mine.snapshot(user.id));
  });

  test('solo sube lo que cambió desde la última vez', () async {
    final phone = await Phone.create(server);
    final user = await UserRepository(phone.db).createUser('Marcos');
    final (session, _) = await phone.logWorkout(user.id);
    await phone.sync.register(
      address: address,
      username: 'marcos',
      password: 'contraseña-segura',
    );
    // Lo que se subió dentro del margen de 5 s puede volver a subir; el
    // servidor lo ignora. Lo que importa es que lo nuevo sí llegue.
    await phone.training.finishSession(
      session.id,
      durationS: 3600,
      sessionRpe: 7,
    );

    await phone.sync.sync();

    final sessions = server.rowsOf(user.id)['sessions']!;
    expect(sessions.single['durationS'], 3600);
  });

  test('los cambios y borrados viajan entre teléfonos', () async {
    final a = await Phone.create(server);
    final user = await UserRepository(a.db).createUser('Marcos');
    final (session, set) = await a.logWorkout(user.id);
    await a.sync.register(
      address: address,
      username: 'marcos',
      password: 'contraseña-segura',
    );
    final b = await Phone.create(server);
    await b.sync.login(
      address: address,
      username: 'marcos',
      password: 'contraseña-segura',
    );

    // En B se corrige la serie y se termina la sesión; en A se borra otra
    // cosa: la serie.
    await b.training.finishSession(session.id, durationS: 1800, sessionRpe: 6);
    await b.sync.sync();
    await a.sync.sync();

    final inA = await a.training.strengthSetsOf(session.id);
    expect(inA.single.id, set.id);
    final finished = await a.training.watchSession(session.id).first;
    expect(finished!.durationS, 1800);

    await a.training.deleteStrengthSet(set.id);
    await a.sync.sync();
    await b.sync.sync();
    expect(await b.training.strengthSetsOf(session.id), isEmpty);
  });

  test('en un conflicto gana el cambio más reciente en los dos', () async {
    final a = await Phone.create(server);
    final user = await UserRepository(a.db).createUser('Marcos');
    final (session, _) = await a.logWorkout(user.id);
    await a.sync.register(
      address: address,
      username: 'marcos',
      password: 'contraseña-segura',
    );
    final b = await Phone.create(server);
    await b.sync.login(
      address: address,
      username: 'marcos',
      password: 'contraseña-segura',
    );

    // Los dos editan la misma sesión sin sincronizar; B lo hace después.
    await a.training.finishSession(session.id, durationS: 1000, sessionRpe: 5);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await b.training.finishSession(session.id, durationS: 2000, sessionRpe: 8);

    await b.sync.sync();
    await a.sync.sync(); // la de A es más vieja: el servidor la ignora
    await b.sync.sync();

    for (final phone in [a, b]) {
      final result = await phone.training.watchSession(session.id).first;
      expect(result!.durationS, 2000);
    }
  });

  test('una serie que llega antes que su sesión se guarda bien', () async {
    final a = await Phone.create(server);
    final user = await UserRepository(a.db).createUser('Marcos');
    final (session, set) = await a.logWorkout(user.id);
    await a.sync.register(
      address: address,
      username: 'marcos',
      password: 'contraseña-segura',
    );
    // La sesión cambia después: en el servidor queda detrás de su serie.
    await a.training.finishSession(session.id, durationS: 900, sessionRpe: 4);
    await a.sync.sync();

    final b = await Phone.create(server);
    final report = await b.sync.login(
      address: address,
      username: 'marcos',
      password: 'contraseña-segura',
    );

    expect(report.failed, 0);
    expect((await b.training.strengthSetsOf(session.id)).single.id, set.id);
  });

  test('no mezcla los datos de dos personas en un teléfono', () async {
    final sister = await Phone.create(server);
    final her = await UserRepository(sister.db).createUser('Ana');
    await sister.sync.register(
      address: address,
      username: 'ana',
      password: 'contraseña-segura',
    );
    final mine = await Phone.create(server);
    await UserRepository(mine.db).createUser('Marcos');

    await expectLater(
      mine.sync.login(
        address: address,
        username: 'ana',
        password: 'contraseña-segura',
      ),
      throwsA(
        isA<SyncException>().having(
          (e) => e.message,
          'message',
          contains('otra persona'),
        ),
      ),
    );
    expect(mine.sync.isConnected, isFalse);
    expect(server.rowsOf(her.id).keys, ['users']);
  });

  test('una sesión vencida pide volver a iniciar sesión', () async {
    final phone = await Phone.create(server);
    await UserRepository(phone.db).createUser('Marcos');
    await phone.sync.register(
      address: address,
      username: 'marcos',
      password: 'contraseña-segura',
    );
    server.expireTokens();

    await expectLater(
      phone.sync.sync(),
      throwsA(
        isA<SyncException>().having((e) => e.sessionExpired, 'vencida', true),
      ),
    );
    expect(phone.sync.isConnected, isFalse);
    expect(phone.tokens.token, isNull);
    // La dirección se recuerda para volver a entrar.
    expect(phone.sync.address, address);
  });

  test('no confunde otro programa con el servidor', () async {
    server.impostor = true;
    final phone = await Phone.create(server);
    await UserRepository(phone.db).createUser('Marcos');

    await expectLater(
      phone.sync.register(
        address: address,
        username: 'marcos',
        password: 'contraseña-segura',
      ),
      throwsA(
        isA<SyncException>().having(
          (e) => e.message,
          'message',
          contains('otro programa'),
        ),
      ),
    );
  });
}

/// SharedPreferences es global en las pruebas; esta envoltura le da a cada
/// teléfono su propio espacio.
class _IsolatedPrefs implements SharedPreferences {
  _IsolatedPrefs(this._inner);

  // ignore: unused_field
  final SharedPreferences _inner;
  final _values = <String, Object>{};

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  int? getInt(String key) => _values[key] as int?;

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
