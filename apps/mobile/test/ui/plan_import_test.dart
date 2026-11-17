import 'dart:io';

import 'package:anfybio/app/appearance.dart';
import 'package:anfybio/app/plan_import.dart';
import 'package:anfybio/app/providers.dart';
import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/repositories/nutrition_repository.dart';
import 'package:anfybio/domain/nutrition.dart';
import 'package:anfybio/ui/app.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences preferences;
  late String userId;
  final planText = File('test/fixtures/plan_alimentacion_ejemplo.txt')
      .readAsStringSync();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Ana'));
    userId = user.id;
  });

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Arranca la app en la pestaña de alimentación. [picker] hace de selector
  /// de archivos: devuelve el "PDF" ya convertido en texto.
  Future<void> openNutrition(WidgetTester tester, PdfTextPicker picker) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(preferences),
          pdfTextPickerProvider.overrideWithValue(picker),
        ],
        child: const AnfybioApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Alimentación'));
  }

  Future<void> shutDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  Future<PickedPdf?> examplePdf() async =>
      (fileName: 'plan.pdf', text: planText);

  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).last,
      );

  testWidgets('importar muestra la revisión con lo que no se entendió', (
    tester,
  ) async {
    await openNutrition(tester, examplePdf);

    await tap(tester, find.text('Importar desde PDF'));

    expect(find.text('Revisar plan'), findsOneWidget);
    expect(find.text('Plan de alimentación Ejemplo'), findsOneWidget);
    expect(
      find.text('2 menús · 7 comidas · 25 alimentos · 3 suplementos'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Hay 4 renglones que no se entendieron'),
      findsOneWidget,
    );
    // Todavía no se guardó nada.
    expect(await db.select(db.nutritionPlans).get(), isEmpty);
    await shutDown(tester);
  });

  testWidgets('corregir un renglón marcado le quita la advertencia', (
    tester,
  ) async {
    await openNutrition(tester, examplePdf);
    await tap(tester, find.text('Importar desde PDF'));

    // "Mango: 60 h" → el usuario confirma que son gramos.
    expect(find.text('No se reconoció la unidad "h".'), findsOneWidget);
    // Se toca sin desplazar la lista, para que el resumen siga a la vista.
    await tester.tap(find.text('Mango'));
    await tester.pumpAndSettle();
    expect(find.text('Corregir alimento'), findsOneWidget);
    await tap(tester, find.text('Guardar cambios'));

    expect(find.text('No se reconoció la unidad "h".'), findsNothing);
    expect(find.text('60 g'), findsOneWidget);
    expect(
      find.textContaining('Hay 3 renglones que no se entendieron'),
      findsOneWidget,
    );
    await shutDown(tester);
  });

  testWidgets('guardar con renglones pendientes pide confirmación', (
    tester,
  ) async {
    await openNutrition(tester, examplePdf);
    await tap(tester, find.text('Importar desde PDF'));

    await tap(tester, find.text('Guardar plan'));
    expect(find.text('Quedan 4 renglones por revisar'), findsOneWidget);

    await tap(tester, find.text('Seguir revisando'));
    expect(find.text('Revisar plan'), findsOneWidget);
    expect(await db.select(db.nutritionPlans).get(), isEmpty);
    await shutDown(tester);
  });

  testWidgets('al guardar, el plan queda activo con todo su contenido', (
    tester,
  ) async {
    await openNutrition(tester, examplePdf);
    await tap(tester, find.text('Importar desde PDF'));
    await tap(tester, find.text('Guardar plan'));
    await tap(tester, find.text('Guardar así'));

    // De vuelta en la pestaña, con el menú de descanso (hoy no hay sesiones).
    expect(find.text('Revisar plan'), findsNothing);
    expect(find.text('1. Colación / Comida 1'), findsOneWidget);
    expect(find.text('Yogurt natural'), findsOneWidget);

    final view = (await NutritionRepository(db).activePlan(userId))!;
    expect(view.plan.sourceFileName, 'plan.pdf');
    expect(view.menuFor(DayType.training)!.meals, hasLength(4));
    expect(view.menuFor(DayType.rest)!.meals, hasLength(3));
    expect(view.supplements.map((s) => s.name), contains('Vitamina C'));
    await shutDown(tester);
  });

  testWidgets('quitar un alimento en la revisión no lo guarda', (tester) async {
    await openNutrition(tester, examplePdf);
    await tap(tester, find.text('Importar desde PDF'));

    await scrollTo(tester, find.text('Té verde'));
    await tap(tester, find.text('Té verde'));
    await tap(tester, find.byIcon(CupertinoIcons.trash));
    await tap(tester, find.text('Borrar'));
    expect(find.text('Té verde'), findsNothing);

    await tap(tester, find.text('Guardar plan'));
    await tap(tester, find.text('Guardar así'));

    final items = await db.select(db.planItems).get();
    expect(items, hasLength(24));
    expect(items.map((i) => i.name), isNot(contains('Té verde')));
    await shutDown(tester);
  });

  testWidgets('cancelar la revisión no guarda nada', (tester) async {
    await openNutrition(tester, examplePdf);
    await tap(tester, find.text('Importar desde PDF'));

    await tap(tester, find.text('Cancelar'));

    expect(find.text('Aún no tienes un plan'), findsOneWidget);
    expect(await db.select(db.nutritionPlans).get(), isEmpty);
    await shutDown(tester);
  });

  testWidgets('un PDF sin texto explica que puede ser un escaneo', (
    tester,
  ) async {
    await openNutrition(tester, () async => (fileName: 'foto.pdf', text: ''));

    await tap(tester, find.text('Importar desde PDF'));

    expect(find.text('No se encontró un plan'), findsOneWidget);
    expect(find.textContaining('imagen escaneada'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('un PDF que no es un plan lo dice y no abre la revisión', (
    tester,
  ) async {
    await openNutrition(
      tester,
      () async => (fileName: 'factura.pdf', text: 'Factura 123\nTotal: 500'),
    );

    await tap(tester, find.text('Importar desde PDF'));

    expect(find.textContaining('no tiene el formato esperado'), findsOneWidget);
    expect(find.text('Revisar plan'), findsNothing);
    await shutDown(tester);
  });

  testWidgets('si el lector falla, avisa en vez de cerrarse', (tester) async {
    await openNutrition(tester, () async => throw const FormatException('x'));

    await tap(tester, find.text('Importar desde PDF'));

    expect(find.text('No se pudo leer el PDF'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('cancelar el selector de archivos no hace nada', (tester) async {
    await openNutrition(tester, () async => null);

    await tap(tester, find.text('Importar desde PDF'));

    expect(find.text('Aún no tienes un plan'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('importar otro plan reemplaza al activo y conserva el anterior', (
    tester,
  ) async {
    await NutritionRepository(db).createEmptyPlan(userId, name: 'Plan viejo');
    await openNutrition(tester, examplePdf);

    await tap(tester, find.byIcon(CupertinoIcons.ellipsis_circle));
    await tap(tester, find.text('Importar otro plan (PDF)'));
    await tap(tester, find.text('Guardar plan'));
    await tap(tester, find.text('Guardar así'));

    expect(find.text('Plan de alimentación Ejemplo'), findsOneWidget);
    final plans = await db.select(db.nutritionPlans).get();
    expect(plans.map((p) => (p.name, p.isActive)), [
      ('Plan viejo', false),
      ('Plan de alimentación Ejemplo', true),
    ]);
    await shutDown(tester);
  });
}
