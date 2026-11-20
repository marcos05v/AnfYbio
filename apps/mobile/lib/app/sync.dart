import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_api.dart';
import '../sync/sync_service.dart';
import 'appearance.dart';
import 'providers.dart';

/// Dónde vive el token. Las pruebas lo reemplazan por uno en memoria.
final tokenStoreProvider = Provider<TokenStore>(
  (ref) => const KeychainTokenStore(),
);

/// Cómo se crea el cliente de la API. Las pruebas usan un servidor falso.
final syncApiFactoryProvider = Provider<SyncApi Function(Uri)>(
  (ref) => SyncApi.new,
);

final syncServiceProvider = Provider(
  (ref) => SyncService(
    db: ref.watch(databaseProvider),
    preferences: ref.watch(sharedPreferencesProvider),
    tokens: ref.watch(tokenStoreProvider),
    apiFor: ref.watch(syncApiFactoryProvider),
  ),
);

/// Lo que la pantalla del servidor necesita mostrar.
class SyncStatus {
  const SyncStatus({
    required this.connected,
    this.address,
    this.username,
    this.lastSyncedAt,
    this.busy = false,
    this.error,
    this.lastReport,
  });

  final bool connected;
  final String? address;
  final String? username;
  final DateTime? lastSyncedAt;

  /// Hay una operación con el servidor en curso.
  final bool busy;
  final String? error;
  final SyncReport? lastReport;
}

class SyncController extends Notifier<SyncStatus> {
  SyncService get _service => ref.read(syncServiceProvider);

  @override
  SyncStatus build() {
    final service = ref.watch(syncServiceProvider);
    return _statusOf(service);
  }

  SyncStatus _statusOf(
    SyncService service, {
    bool busy = false,
    String? error,
    SyncReport? report,
  }) => SyncStatus(
    connected: service.isConnected,
    address: service.address,
    username: service.username,
    lastSyncedAt: service.lastSyncedAt,
    busy: busy,
    error: error,
    lastReport: report,
  );

  Future<void> register(String address, String username, String password) =>
      _run(
        () => _service.register(
          address: address,
          username: username,
          password: password,
        ),
      );

  Future<void> login(String address, String username, String password) => _run(
    () => _service.login(
      address: address,
      username: username,
      password: password,
    ),
  );

  Future<void> syncNow() => _run(_service.sync);

  /// Al abrir la app o volver a ella: sincroniza si hay sesión, sin mostrar
  /// errores (la Mac puede estar apagada o el teléfono fuera de casa).
  Future<void> syncQuietly() async {
    if (!_service.isConnected || state.busy) return;
    try {
      final report = await _service.sync();
      state = _statusOf(_service, report: report);
    } on SyncException catch (error) {
      // Solo se avisa si hay que volver a iniciar sesión.
      state = _statusOf(
        _service,
        error: error.sessionExpired ? error.message : null,
      );
    } catch (_) {
      state = _statusOf(_service);
    }
  }

  Future<void> logout() async {
    await _service.logout();
    state = _statusOf(_service);
  }

  Future<void> _run(Future<SyncReport> Function() action) async {
    state = _statusOf(_service, busy: true);
    try {
      final report = await action();
      state = _statusOf(_service, report: report);
    } on SyncException catch (error) {
      state = _statusOf(_service, error: error.message);
    } catch (_) {
      state = _statusOf(
        _service,
        error: 'Algo salió mal al sincronizar. Vuelve a intentarlo.',
      );
    }
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);
