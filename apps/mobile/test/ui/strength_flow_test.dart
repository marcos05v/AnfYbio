import 'dart:convert';

import 'package:anfybio/app/appearance.dart';
import 'package:anfybio/app/backup.dart';
import 'package:anfybio/app/providers.dart';
import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/export/backup_exporter.dart';
import 'package:anfybio/data/repositories/training_repository.dart';
import 'package:anfybio/data/tables/sessions.dart';
import 'package:anfybio/domain/weight.dart';
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
  });

  /// Arranca la app completa sobre una base y unas preferencias en memoria.
  Future<void> pumpApp(WidgetTester tester) async {
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
  }

  /// Desmonta la app y cierra la base para no dejar temporizadores vivos.
  Future<void> shutDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  Future<void> createUser() =>
      db.into(db.users).insert(UsersCompanion.insert(displayName: 'Ana'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> startSession(WidgetTester tester) async {
    await createUser();
    await pumpApp(tester);
    await tap(tester, find.text('Iniciar sesión'));
    await tap(tester, find.text('Fuerza'));
  }

  /// Crea un ejercicio en libras desde la hoja de "Nueva serie".
  Future<void> createBenchPress(WidgetTester tester) async {
    await tap(tester, find.byKey(const Key('exercise')));
    await tap(tester, find.text('Nuevo ejercicio…'));
    await tester.enterText(
      find.byKey(const Key('exerciseName')),
      'Press de banca',
    );
    await tap(tester, find.text('Libras'));
    await tap(tester, find.text('Guardar'));
  }

  testWidgets('la primera vez pide el nombre y luego muestra las sesiones', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('¿Cómo te llamas?'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('name')), 'Marcos');
    await tap(tester, find.text('Empezar'));

    expect(find.text('Hola, Marcos'), findsOneWidget);
    expect(find.textContaining('Aún no hay sesiones'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('si ya existe un usuario, entra directo a las sesiones', (
    tester,
  ) async {
    await createUser();
    await pumpApp(tester);

    expect(find.text('Hola, Ana'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('registra una sesión de fuerza de principio a fin', (
    tester,
  ) async {
    await startSession(tester);
    expect(find.text('Sin series todavía'), findsOneWidget);

    // Serie: 225 lb × 5 a RPE 8,5 (con coma decimal).
    await tap(tester, find.text('Agregar ejercicio'));
    await createBenchPress(tester);
    await tester.enterText(find.byKey(const Key('weight')), '225');
    await tester.enterText(find.byKey(const Key('reps')), '5');
    await tester.enterText(find.byKey(const Key('rpe')), '8,5');
    await tap(tester, find.text('Guardar serie'));

    expect(find.text('Press de banca'), findsOneWidget);
    expect(find.text('225 lb × 5'), findsOneWidget);
    expect(find.text('RPE 8.5 · 1RM ≈ 119.1 kg'), findsOneWidget);
    final set = await db.select(db.strengthSets).getSingle();
    expect(set.weightUnit, WeightUnit.lb); // tomó la unidad del ejercicio

    // Terminar: 45 minutos, RPE 7 (valor propuesto).
    await tap(tester, find.text('Terminar'));
    await tester.enterText(find.byKey(const Key('minutes')), '45');
    await tap(tester, find.text('Guardar'));

    // De vuelta en la lista, con la carga sRPE: 45 × 7 = 315.
    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('45 min · RPE 7 · carga 315'), findsOneWidget);
    expect(find.text('En curso'), findsNothing);
    // Resumen de la semana: 45 min de entrenamiento y carga 315.
    expect(find.text('45 min'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('weekLoad'))).data, '315');
    await shutDown(tester);
  });

  testWidgets(
    '"+ Serie" propone el ejercicio, peso y repeticiones anteriores',
    (tester) async {
      await startSession(tester);
      await tap(tester, find.text('Agregar ejercicio'));
      await createBenchPress(tester);
      await tester.enterText(find.byKey(const Key('weight')), '225');
      await tester.enterText(find.byKey(const Key('reps')), '5');
      await tap(tester, find.text('Guardar serie'));

      // El botón "+ Serie" junto al nombre del ejercicio propone lo anterior.
      await tap(tester, find.text('Serie'));
      await tap(tester, find.text('Guardar serie'));

      final sets = await db.select(db.strengthSets).get();
      expect(sets.map((s) => (s.weight, s.reps, s.position)), [
        (225, 5, 1),
        (225, 5, 2),
      ]);
      await shutDown(tester);
    },
  );

  testWidgets('avisa si falta un dato y no guarda la serie', (tester) async {
    await startSession(tester);

    await tap(tester, find.text('Agregar ejercicio'));
    await tap(tester, find.text('Guardar serie'));

    expect(find.text('Elige un ejercicio.'), findsOneWidget);
    expect(await db.select(db.strengthSets).get(), isEmpty);
    await shutDown(tester);
  });

  testWidgets('"Agregar ejercicio" abre el formulario sin nada elegido', (
    tester,
  ) async {
    await startSession(tester);
    await tap(tester, find.text('Agregar ejercicio'));
    await createBenchPress(tester);
    await tester.enterText(find.byKey(const Key('weight')), '225');
    await tester.enterText(find.byKey(const Key('reps')), '5');
    await tap(tester, find.text('Guardar serie'));

    await tap(tester, find.text('Agregar ejercicio'));

    expect(find.text('Elegir'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('el calentamiento se marca con C y no consume número', (
    tester,
  ) async {
    await startSession(tester);
    await tap(tester, find.text('Agregar ejercicio'));
    await createBenchPress(tester);
    await tester.enterText(find.byKey(const Key('weight')), '135');
    await tester.enterText(find.byKey(const Key('reps')), '10');
    await tap(tester, find.byType(CupertinoSwitch));
    await tap(tester, find.text('Guardar serie'));

    await tap(tester, find.text('Serie'));
    await tap(tester, find.byType(CupertinoSwitch)); // ya no es calentamiento
    await tester.enterText(find.byKey(const Key('weight')), '225');
    await tester.enterText(find.byKey(const Key('reps')), '5');
    await tap(tester, find.text('Guardar serie'));

    expect(find.byType(WarmupBadge), findsOneWidget);
    expect(find.text('Calentamiento'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // la primera serie efectiva
    expect(find.text('2'), findsNothing);
    await shutDown(tester);
  });

  testWidgets('borrar la sesión la quita de la lista', (tester) async {
    await startSession(tester);

    await tap(tester, find.byIcon(CupertinoIcons.ellipsis_circle));
    await tap(tester, find.text('Borrar sesión'));
    await tap(tester, find.text('Borrar'));

    expect(find.textContaining('Aún no hay sesiones'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('la carga por semana avisa cuando aún no hay datos', (
    tester,
  ) async {
    await createUser();
    await pumpApp(tester);

    await tap(tester, find.text('Ver por semana'));

    expect(find.text('Aún no hay datos'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('la carga por semana lista las semanas con registros', (
    tester,
  ) async {
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Ana'));
    final repository = TrainingRepository(db);
    // Una sesión hoy (carga 420) y otra hace 16 días (carga 300).
    for (final (daysAgo, minutes, rpe) in [(0, 60, 7), (16, 50, 6)]) {
      final session = await repository.startSession(
        userId: user.id,
        type: SessionType.strength,
        startedAt: DateTime.now().subtract(Duration(days: daysAgo)),
      );
      await repository.finishSession(
        session.id,
        durationS: minutes * 60,
        sessionRpe: rpe,
      );
    }
    await pumpApp(tester);

    await tap(tester, find.text('Ver por semana'));

    expect(find.text('Esta semana'), findsOneWidget);
    expect(find.text('420'), findsOneWidget);
    expect(find.text('Semana anterior'), findsOneWidget);
    expect(find.text('Sin registros'), findsOneWidget); // semana sin sesiones
    expect(find.text('Hace 2 semanas'), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
    expect(
      find.text('Hace 3 semanas'),
      findsNothing,
    ); // no hay historial previo
    await shutDown(tester);
  });

  testWidgets('exportar respaldo entrega un archivo con los datos', (
    tester,
  ) async {
    await createUser();
    final shared = <Backup>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(preferences),
          // En vez de abrir la hoja de compartir, se guarda lo que recibiría.
          backupSharerProvider.overrideWithValue(
            (backup, {origin}) async => shared.add(backup),
          ),
        ],
        child: const AnfybioApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tap(tester, find.byIcon(CupertinoIcons.gear_alt));
    await tap(tester, find.text('Exportar respaldo'));

    expect(shared.single.fileName, startsWith('anfybio-respaldo-'));
    final document = jsonDecode(shared.single.json) as Map<String, dynamic>;
    expect((document['user'] as Map)['displayName'], 'Ana');
    await shutDown(tester);
  });

  testWidgets('si la exportación falla, avisa en vez de cerrarse', (
    tester,
  ) async {
    await createUser();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(preferences),
          backupSharerProvider.overrideWithValue(
            (backup, {origin}) async =>
                throw const FormatException('sin espacio'),
          ),
        ],
        child: const AnfybioApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tap(tester, find.byIcon(CupertinoIcons.gear_alt));
    await tap(tester, find.text('Exportar respaldo'));

    expect(find.text('No se pudo exportar'), findsOneWidget);
    await tap(tester, find.text('Aceptar'));
    expect(find.text('Exportar respaldo'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('el modo oscuro se aplica y se recuerda', (tester) async {
    await createUser();
    await pumpApp(tester);

    await tap(tester, find.byIcon(CupertinoIcons.gear_alt));
    await tap(tester, find.text('Oscuro'));

    final context = tester.element(find.text('Ajustes'));
    expect(CupertinoTheme.brightnessOf(context), Brightness.dark);
    expect(preferences.getString('appearance'), 'dark');
    await shutDown(tester);
  });

  testWidgets('arranca con la apariencia guardada', (tester) async {
    await preferences.setString('appearance', 'dark');
    await createUser();
    await pumpApp(tester);

    final context = tester.element(find.text('Hola, Ana'));
    expect(CupertinoTheme.brightnessOf(context), Brightness.dark);
    await shutDown(tester);
  });
}
