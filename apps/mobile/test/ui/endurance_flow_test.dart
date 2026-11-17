import 'package:anfybio/app/appearance.dart';
import 'package:anfybio/app/providers.dart';
import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/tables/apnea_attempts.dart';
import 'package:anfybio/data/tables/swim.dart';
import 'package:anfybio/ui/apnea_session_screen.dart';
import 'package:anfybio/ui/app.dart';
import 'package:anfybio/ui/widgets.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences preferences;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    await db.into(db.users).insert(UsersCompanion.insert(displayName: 'Ana'));
  });

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) =>
      tester.enterText(find.byKey(Key(key)), text);

  /// Arranca la app e inicia una sesión del tipo indicado.
  Future<void> startSession(WidgetTester tester, String typeLabel) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const AnfybioApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Iniciar sesión'));
    await tap(tester, find.text(typeLabel));
  }

  Future<void> shutDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  Future<void> finish(WidgetTester tester, String duration) async {
    await tap(tester, find.text('Terminar'));
    await type(tester, 'minutes', duration);
    await tap(tester, find.text('Guardar'));
  }

  group('natación', () {
    testWidgets('pide la alberca y registra un bloque con parciales', (
      tester,
    ) async {
      await startSession(tester, 'Natación');
      await tap(tester, find.text('25 m'));
      expect(find.textContaining('Alberca de 25 m'), findsOneWidget);
      expect(find.text('Sin bloques todavía'), findsOneWidget);

      await tap(tester, find.text('Agregar bloque'));
      await tap(tester, find.byKey(const Key('stroke')));
      await tap(tester, find.text('Dorso'));
      await type(tester, 'distance', '100');
      await type(tester, 'time', '1:35');
      await type(tester, 'splits', '23 24 24 24');
      await tap(tester, find.text('Guardar bloque'));

      expect(find.text('100 m · Dorso'), findsOneWidget);
      expect(find.text('1:35 · 1:35 /100 m'), findsOneWidget);
      expect(find.textContaining('Parciales: 0:23'), findsOneWidget);
      final block = await db.select(db.swimIntervals).getSingle();
      expect(block.stroke, SwimStroke.backstroke);
      expect(await db.select(db.swimLaps).get(), hasLength(4));
      await shutDown(tester);
    });

    testWidgets('sin tiempo total, usa la suma de los parciales', (
      tester,
    ) async {
      await startSession(tester, 'Natación');
      await tap(tester, find.text('50 m'));
      await tap(tester, find.text('Agregar bloque'));
      await type(tester, 'distance', '100');
      await type(tester, 'splits', '40.5 41.5');
      await tap(tester, find.text('Guardar bloque'));

      final block = await db.select(db.swimIntervals).getSingle();
      expect(block.durationMs, 82000);
      await shutDown(tester);
    });

    testWidgets('avisa si los parciales no cuadran con la distancia', (
      tester,
    ) async {
      await startSession(tester, 'Natación');
      await tap(tester, find.text('25 m'));
      await tap(tester, find.text('Agregar bloque'));
      await type(tester, 'distance', '100');
      await type(tester, 'time', '1:35');
      await type(tester, 'splits', '23 24');
      await tap(tester, find.text('Guardar bloque'));

      expect(
        find.textContaining('son 4 parciales; escribiste 2'),
        findsOneWidget,
      );
      expect(await db.select(db.swimIntervals).get(), isEmpty);
      await shutDown(tester);
    });

    testWidgets('acepta una alberca de otra medida', (tester) async {
      await startSession(tester, 'Natación');
      await tap(tester, find.text('Otra medida…'));
      await type(tester, 'poolLength', '33');
      await tap(tester, find.text('Aceptar'));

      expect(find.textContaining('Alberca de 33 m'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('cancelar la alberca no crea ninguna sesión', (tester) async {
      await startSession(tester, 'Natación');
      await tap(tester, find.text('Cancelar'));

      expect(await db.select(db.sessions).get(), isEmpty);
      await shutDown(tester);
    });
  });

  group('carrera', () {
    testWidgets('registra la distancia y muestra el ritmo al terminar', (
      tester,
    ) async {
      await startSession(tester, 'Carrera');
      expect(find.text('Sin distancia todavía'), findsOneWidget);

      await tap(tester, find.text('Registrar distancia'));
      await type(tester, 'km', '5,2');
      await tap(tester, find.text('Guardar'));
      expect(find.text('5.2 km'), findsOneWidget);
      expect(find.text('Al terminar'), findsNWidgets(2)); // duración y ritmo

      await finish(tester, '26:00');

      // En la lista, y al reabrir, ya hay ritmo: 26:00 / 5.2 km = 5:00 /km.
      await tap(tester, find.text('Carrera'));
      expect(find.text('26:00'), findsOneWidget);
      expect(find.text('5:00 /km'), findsOneWidget);
      expect(find.text('Editar distancia'), findsOneWidget);
      await shutDown(tester);
    });
  });

  group('apnea', () {
    testWidgets(
      'el aviso de seguridad se ve en la pantalla y en el formulario',
      (tester) async {
        await startSession(tester, 'Apnea');
        expect(find.text(apneaSafetyMessage), findsOneWidget);

        await tap(tester, find.text('Agregar intento'));
        expect(find.byType(SafetyBanner), findsNWidgets(2));
        await shutDown(tester);
      },
    );

    testWidgets(
      'registra una estática por tiempo y una dinámica por distancia',
      (tester) async {
        await startSession(tester, 'Apnea');

        await tap(tester, find.text('Agregar intento'));
        await type(tester, 'time', '2:30');
        await tap(tester, find.text('Guardar intento'));

        await tap(tester, find.text('Agregar intento'));
        await tap(tester, find.text('Dinámica'));
        await type(tester, 'distance', '50');
        await tap(tester, find.text('Guardar intento'));

        expect(find.text('2:30'), findsOneWidget);
        expect(find.text('50 m'), findsOneWidget);
        expect(find.textContaining('2 intentos'), findsOneWidget);
        final attempts = await db.select(db.apneaAttempts).get();
        expect(attempts.map((a) => (a.kind, a.durationMs, a.distanceM)), [
          (ApneaKind.static, 150000, null),
          (ApneaKind.dynamic, null, 50),
        ]);
        await shutDown(tester);
      },
    );

    testWidgets('una estática sin tiempo no se guarda', (tester) async {
      await startSession(tester, 'Apnea');
      await tap(tester, find.text('Agregar intento'));
      await tap(tester, find.text('Guardar intento'));

      expect(find.textContaining('Escribe el tiempo'), findsOneWidget);
      expect(await db.select(db.apneaAttempts).get(), isEmpty);
      await shutDown(tester);
    });
  });
}
