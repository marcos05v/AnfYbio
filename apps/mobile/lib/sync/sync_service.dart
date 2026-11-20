import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import 'sync_api.dart';
import 'sync_tables.dart';

/// Dónde se guarda el token de la sesión.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String? token);
}

/// En el Llavero de iOS (Keychain), cifrado por el sistema, en lugar de un
/// archivo de preferencias que cualquiera con el respaldo del teléfono
/// podría leer.
class KeychainTokenStore implements TokenStore {
  const KeychainTokenStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'anfybio.sync.token';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String? token) => token == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: token);
}

/// Para las pruebas.
class MemoryTokenStore implements TokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String? value) async => token = value;
}

/// Resultado de una sincronización.
class SyncReport {
  const SyncReport({
    required this.pushed,
    required this.pulled,
    required this.rejected,
    required this.failed,
  });

  /// Filas propias que el servidor guardó.
  final int pushed;

  /// Filas que llegaron de otro dispositivo y se guardaron aquí.
  final int pulled;

  /// Filas que el servidor rechazó (por ejemplo, con la hora mal).
  final int rejected;

  /// Filas que llegaron pero no se pudieron leer (de una versión más nueva
  /// de la app, por ejemplo).
  final int failed;
}

/// La sincronización con el servidor de la casa (ADR-0016 y ADR-0020).
///
/// 1. **Subir**: las filas cuyo `updatedAt` es posterior a la última subida.
/// 2. **Bajar**: lo que el servidor aceptó después del último número de
///    secuencia visto, y guardarlo si es más reciente que lo local.
class SyncService {
  SyncService({
    required this._db,
    required SharedPreferences preferences,
    required this._tokens,
    SyncApi Function(Uri baseUri)? apiFor,
    DateTime Function()? now,
  }) : _prefs = preferences,
       _apiFor = apiFor ?? SyncApi.new,
       _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final SharedPreferences _prefs;
  final TokenStore _tokens;
  final SyncApi Function(Uri baseUri) _apiFor;
  final DateTime Function() _now;

  static const _addressKey = 'sync.address';
  static const _usernameKey = 'sync.username';
  static const _userIdKey = 'sync.userId';
  static const _pushMarkKey = 'sync.lastPushMark';
  static const _pullSeqKey = 'sync.lastPullSeq';
  static const _syncedAtKey = 'sync.lastSyncedAt';

  /// Filas por subida (el servidor acepta hasta 500).
  static const pushBatchSize = 500;

  /// Margen al guardar la marca de subida: una fila que se estaba guardando
  /// justo al empezar se vuelve a subir la próxima vez en lugar de perderse.
  /// Subirla dos veces no hace daño: el servidor ignora lo que ya tiene.
  static const pushMarkMargin = Duration(seconds: 5);

  String? get address => _prefs.getString(_addressKey);
  String? get username => _prefs.getString(_usernameKey);
  bool get isConnected => username != null;

  DateTime? get lastSyncedAt => switch (_prefs.getString(_syncedAtKey)) {
    final String text => DateTime.parse(text),
    null => null,
  };

  Future<SyncReport>? _running;

  /// Crea la cuenta con el usuario de este teléfono y sube todo.
  Future<SyncReport> register({
    required String address,
    required String username,
    required String password,
  }) async {
    final user = await _localUser();
    if (user == null) {
      throw const SyncException(
        'Primero escribe tu nombre en la app; luego crea la cuenta.',
      );
    }
    final api = await _connect(address);
    final session = await api.register(
      userId: user.id,
      username: username,
      password: password,
    );
    await _start(address, session);
    return sync();
  }

  /// Inicia sesión. En una instalación nueva baja todos los datos de la
  /// cuenta; en una con datos, solo si son de la misma cuenta.
  Future<SyncReport> login({
    required String address,
    required String username,
    required String password,
  }) async {
    final api = await _connect(address);
    final session = await api.login(username: username, password: password);
    final user = await _localUser();
    if (user != null && user.id != session.userId) {
      // Mezclar los datos de dos personas no tiene arreglo (ADR-0007).
      throw const SyncException(
        'Este teléfono ya tiene los datos de otra persona. Esa cuenta solo '
        'se puede abrir en una instalación nueva de la app.',
      );
    }
    await _start(address, session);
    return sync();
  }

  /// Cierra la sesión. Los datos se quedan en el teléfono.
  Future<void> logout() async {
    await _tokens.write(null);
    for (final key in [
      _usernameKey,
      _userIdKey,
      _pushMarkKey,
      _pullSeqKey,
      _syncedAtKey,
    ]) {
      await _prefs.remove(key);
    }
  }

  /// Sube y baja los cambios. Si ya hay una sincronización en curso,
  /// devuelve esa misma.
  Future<SyncReport> sync() => _running ??= _sync().whenComplete(() {
    _running = null;
  });

  Future<SyncReport> _sync() async {
    final address = this.address;
    final userId = _prefs.getString(_userIdKey);
    final token = await _tokens.read();
    if (address == null || userId == null || token == null) {
      throw const SyncException(
        'Inicia sesión en el servidor para sincronizar.',
        sessionExpired: true,
      );
    }
    final api = _apiFor(serverUri(address));
    final startedAt = _now();

    try {
      // 1. Subir.
      final since = switch (_prefs.getString(_pushMarkKey)) {
        final String text => DateTime.parse(text),
        null => null,
      };
      final changes = [
        for (final table in syncTablesOf(_db))
          for (final row in await table.changedSince(_db, userId, since))
            (table: table.name, data: row),
      ];
      var pushed = 0;
      var rejected = 0;
      for (var i = 0; i < changes.length; i += pushBatchSize) {
        final batch = changes.sublist(
          i,
          i + pushBatchSize > changes.length
              ? changes.length
              : i + pushBatchSize,
        );
        final result = await api.push(token, batch);
        pushed += result.applied;
        rejected += result.rejected;
      }

      // 2. Bajar todas las páginas y guardarlas juntas.
      var seq = _prefs.getInt(_pullSeqKey) ?? 0;
      final pulled = <PulledRow>[];
      PullPage page;
      do {
        page = await api.pull(token, since: seq);
        pulled.addAll(page.rows);
        seq = page.next;
      } while (page.hasMore);
      final (applied, failed) = await _apply(pulled);

      // 3. Recordar hasta dónde se llegó.
      await _prefs.setString(
        _pushMarkKey,
        startedAt.subtract(pushMarkMargin).toIso8601String(),
      );
      await _prefs.setInt(_pullSeqKey, seq);
      await _prefs.setString(_syncedAtKey, _now().toIso8601String());
      return SyncReport(
        pushed: pushed,
        pulled: applied,
        rejected: rejected,
        failed: failed,
      );
    } on SyncException catch (error) {
      // Sin sesión válida se vuelve al formulario de inicio de sesión; los
      // datos y la dirección se quedan.
      if (error.sessionExpired) await logout();
      rethrow;
    }
  }

  /// Guarda las filas bajadas en una sola transacción, en orden de
  /// dependencias. Las llaves foráneas se revisan al final: una serie puede
  /// llegar antes que su sesión si la sesión cambió después.
  Future<(int applied, int failed)> _apply(List<PulledRow> rows) async {
    if (rows.isEmpty) return (0, 0);
    final tables = syncTablesOf(_db);
    final order = {for (final (i, t) in tables.indexed) t.name: i};
    final byName = {for (final t in tables) t.name: t};
    final sorted = [for (final (i, row) in rows.indexed) (i: i, row: row)]
      ..sort((a, b) {
        final byTable = (order[a.row.table] ?? tables.length).compareTo(
          order[b.row.table] ?? tables.length,
        );
        return byTable != 0 ? byTable : a.i.compareTo(b.i);
      });

    var applied = 0;
    var failed = 0;
    try {
      await _applyAll(
        sorted,
        byName,
        onApplied: () => applied++,
        onFailed: () => failed++,
      );
    } catch (_) {
      // Al confirmar, una fila apuntaba a algo que no llegó: no se guarda
      // nada y la próxima sincronización lo vuelve a intentar.
      throw const SyncException(
        'Los datos del servidor llegaron incompletos. Vuelve a sincronizar.',
      );
    }
    return (applied, failed);
  }

  Future<void> _applyAll(
    List<({int i, PulledRow row})> sorted,
    Map<String, SyncTable> byName, {
    required void Function() onApplied,
    required void Function() onFailed,
  }) {
    return _db.transaction(() async {
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final (i: _, :row) in sorted) {
        final table = byName[row.table];
        if (table == null) {
          // Una tabla que esta versión de la app no conoce.
          onFailed();
          continue;
        }
        try {
          if (await table.apply(_db, row.data)) onApplied();
        } catch (_) {
          onFailed();
        }
      }
    });
  }

  Future<SyncApi> _connect(String address) async {
    final api = _apiFor(serverUri(address));
    await api.checkHealth();
    return api;
  }

  Future<void> _start(String address, ServerSession session) async {
    await _tokens.write(session.token);
    await _prefs.setString(_addressKey, address.trim());
    await _prefs.setString(_usernameKey, session.username);
    await _prefs.setString(_userIdKey, session.userId);
    // Desde cero: sube todo lo local y baja todo lo de la cuenta. Lo que ya
    // está igual en los dos lados se ignora.
    await _prefs.remove(_pushMarkKey);
    await _prefs.remove(_pullSeqKey);
  }

  Future<User?> _localUser() {
    return (_db.select(_db.users)
          ..where((u) => u.deletedAt.isNull())
          ..orderBy([(u) => OrderingTerm.asc(u.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }
}
