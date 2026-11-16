import 'package:anfybio/app/providers.dart';
import 'package:anfybio/data/database.dart';
import 'package:anfybio/domain/weight.dart';
import 'package:anfybio/ui/app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  /// Arranca la app completa sobre una base en memoria.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
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

  Finder field(String label) => find.widgetWithText(TextField, label);

  testWidgets('la primera vez pide el nombre y luego muestra las sesiones', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('¿Cómo te llamas?'), findsOneWidget);

    await tester.enterText(field('Nombre'), 'Marcos');
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Marcos'), findsOneWidget);
    expect(find.textContaining('Aún no hay sesiones'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('si ya existe un usuario, entra directo a las sesiones', (
    tester,
  ) async {
    await db.into(db.users).insert(UsersCompanion.insert(displayName: 'Ana'));

    await pumpApp(tester);

    expect(find.text('Hola, Ana'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('registra una sesión de fuerza de principio a fin', (
    tester,
  ) async {
    await db.into(db.users).insert(UsersCompanion.insert(displayName: 'Ana'));
    await pumpApp(tester);

    // Iniciar la sesión.
    await tester.tap(find.text('Sesión de fuerza'));
    await tester.pumpAndSettle();
    expect(find.text('Agrega tu primera serie.'), findsOneWidget);

    // Crear un ejercicio que se mide en libras.
    await tester.tap(find.byTooltip('Nuevo ejercicio'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Nombre'), 'Press de banca');
    await tester.tap(find.text('lb').last);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Agregar una serie: 225 lb × 5 a RPE 8,5 (con coma decimal).
    await tester.enterText(field('Peso'), '225');
    await tester.enterText(field('Reps'), '5');
    await tester.enterText(field('RPE'), '8,5');
    await tester.tap(find.text('Agregar serie'));
    await tester.pumpAndSettle();

    expect(find.text('Press de banca'), findsWidgets);
    expect(find.text('225 lb × 5 · RPE 8.5 · 1RM ≈ 119.1 kg'), findsOneWidget);
    final set = await db.select(db.strengthSets).getSingle();
    expect(set.weightUnit, WeightUnit.lb); // tomó la unidad del ejercicio

    // Terminar: 45 minutos, RPE 7 (valor propuesto).
    await tester.tap(find.text('Terminar'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Duración (minutos)'), '45');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // De vuelta en la lista, con la carga sRPE: 45 × 7 = 315.
    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.textContaining('45 min · RPE 7 · carga 315'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('avisa si falta un dato y no guarda la serie', (tester) async {
    await db.into(db.users).insert(UsersCompanion.insert(displayName: 'Ana'));
    await pumpApp(tester);
    await tester.tap(find.text('Sesión de fuerza'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar serie'));
    await tester.pumpAndSettle();

    expect(find.text('Elige un ejercicio.'), findsOneWidget);
    expect(await db.select(db.strengthSets).get(), isEmpty);
    await shutDown(tester);
  });

  testWidgets('borrar la sesión la quita de la lista', (tester) async {
    await db.into(db.users).insert(UsersCompanion.insert(displayName: 'Ana'));
    await pumpApp(tester);
    await tester.tap(find.text('Sesión de fuerza'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Borrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aún no hay sesiones'), findsOneWidget);
    await shutDown(tester);
  });
}
