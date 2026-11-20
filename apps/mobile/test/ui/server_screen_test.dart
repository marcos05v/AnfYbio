import 'package:anfybio/app/appearance.dart';
import 'package:anfybio/app/providers.dart';
import 'package:anfybio/app/sync.dart';
import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/repositories/user_repository.dart';
import 'package:anfybio/sync/sync_api.dart';
import 'package:anfybio/sync/sync_service.dart';
import 'package:anfybio/ui/server_screen.dart';
import 'package:anfybio/ui/theme.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sync/fake_server.dart';

void main() {
  late AppDatabase db;
  late FakeSyncServer server;
  late MemoryTokenStore tokens;
  late SharedPreferences preferences;

  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    server = FakeSyncServer();
    tokens = MemoryTokenStore();
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(preferences),
          tokenStoreProvider.overrideWithValue(tokens),
          syncApiFactoryProvider.overrideWithValue(
            (uri) => SyncApi(uri, client: server.client),
          ),
        ],
        child: CupertinoApp(
          theme: buildTheme(Brightness.light),
          home: const ServerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shutDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // drift suelta sus consultas vivas con un temporizador; sin avanzarlo,
    // cerrar la base se queda esperando.
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('serverAddress')),
      'mi-mac.local',
    );
    await tester.enterText(find.byKey(const Key('serverUsername')), 'marcos');
    await tester.enterText(
      find.byKey(const Key('serverPassword')),
      'contraseña-segura',
    );
  }

  testWidgets('crear cuenta sube los datos y muestra el resultado', (
    tester,
  ) async {
    final user = await tester.runAsync(
      () => UserRepository(db).createUser('Marcos'),
    );
    await pump(tester);

    await fill(tester);
    await tester.tap(find.byKey(const Key('createAccount')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conectado'), findsOneWidget);
    expect(find.text('marcos'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('syncResult')),
              matching: find.byType(Text),
            ),
          )
          .data,
      'Listo: 1 cambio subido.',
    );
    expect(server.rowsOf(user!.id).keys, ['users']);
    expect(tokens.token, isNotNull);
    await shutDown(tester);
  });

  testWidgets('un error del servidor se muestra en el formulario', (
    tester,
  ) async {
    await tester.runAsync(() => UserRepository(db).createUser('Marcos'));
    server.impostor = true;
    await pump(tester);

    await fill(tester);
    await tester.tap(find.byKey(const Key('createAccount')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('otro programa'), findsOneWidget);
    expect(find.text('Conectado'), findsNothing);
    await shutDown(tester);
  });

  testWidgets('sin usuario local solo se puede iniciar sesión', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('createAccount')), findsNothing);
    expect(find.byKey(const Key('login')), findsOneWidget);
    await shutDown(tester);
  });

  test('describeReport resume en palabras', () {
    String text(int pushed, int pulled, [int rejected = 0]) => describeReport(
      SyncReport(pushed: pushed, pulled: pulled, rejected: rejected, failed: 0),
    );
    expect(text(0, 0), 'Listo: Todo estaba al día.');
    expect(text(3, 1), 'Listo: 3 cambios subidos y 1 cambio recibido.');
    expect(text(1, 0, 2), startsWith('Listo: 1 cambio subido. 2 no se'));
  });
}
