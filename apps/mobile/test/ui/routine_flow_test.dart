import 'dart:io';

import 'package:anfybio/app/appearance.dart';
import 'package:anfybio/app/catalog.dart';
import 'package:anfybio/app/plan_import.dart';
import 'package:anfybio/app/providers.dart';
import 'package:anfybio/catalog/exercise_catalog.dart';
import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/repositories/routine_repository.dart';
import 'package:anfybio/data/repositories/training_repository.dart';
import 'package:anfybio/data/tables/sessions.dart';
import 'package:anfybio/domain/routine.dart';
import 'package:anfybio/domain/weight.dart';
import 'package:anfybio/ui/app.dart';
import 'package:anfybio/ui/routine_widgets.dart';
import 'package:anfybio/ui/widgets.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences preferences;
  late String userId;
  final routineText = File('test/fixtures/rutina_ejemplo.txt')
      .readAsStringSync();
  final catalogJson = File('assets/catalog/exercises.json').readAsStringSync();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Se fija que el Día 1 caiga hoy, para que las pruebas no dependan del
    // día de la semana en que se ejecuten.
    SharedPreferences.setMockInitialValues({
      'routineDayOneWeekday': DateTime.now().weekday,
    });
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

  Future<void> type(WidgetTester tester, String key, String text) =>
      tester.enterText(find.byKey(Key(key)), text);

  Future<void> pumpApp(WidgetTester tester, {PdfTextPicker? picker}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(preferences),
          if (picker != null) pdfTextPickerProvider.overrideWithValue(picker),
          // El catálogo, leído de antemano (cargarlo de los recursos no
          // avanza con el reloj simulado de las pruebas).
          exerciseCatalogProvider.overrideWithValue(
            BundledExerciseCatalog(() async => catalogJson),
          ),
        ],
        child: const AnfybioApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shutDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  Future<PickedPdf?> examplePdf() async =>
      (fileName: 'rutina.pdf', text: routineText);

  /// Una rutina de dos días ya guardada.
  Future<void> saveRoutine() => RoutineRepository(db).saveRoutine(
    userId,
    const RoutineDraft(
      name: 'Rutina de prueba',
      days: [
        RoutineDayDraft(
          name: 'Empuje',
          exercises: [
            RoutineExerciseDraft(
              name: 'Press con barra',
              warmupSets: 1,
              workSets: 2,
              repsMin: 8,
              repsMax: 12,
              note: 'Ejercicio principal',
            ),
            RoutineExerciseDraft(
              name: 'Aperturas',
              workSets: 3,
              repsMin: 15,
              repsMax: 15,
              supersetWithPrevious: true,
            ),
          ],
        ),
        RoutineDayDraft(
          name: 'Tirón',
          exercises: [
            RoutineExerciseDraft(
              name: 'Dominadas',
              workSets: 3,
              repsNote: 'al fallo',
            ),
          ],
        ),
      ],
    ),
  );

  group('pantalla de rutina', () {
    testWidgets('sin rutina, ofrece importarla o crearla', (tester) async {
      await pumpApp(tester);
      await tap(tester, find.text('Configurar rutina'));

      expect(find.text('Aún no tienes una rutina'), findsOneWidget);
      expect(find.text('Importar desde PDF'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('muestra días, objetivos y biseries', (tester) async {
      await saveRoutine();
      await pumpApp(tester);
      await tap(tester, find.text('Ver rutina'));

      expect(find.text('Rutina de prueba'), findsOneWidget);
      expect(find.text('2 días · 3 ejercicios'), findsOneWidget);
      expect(find.text('Empuje'), findsOneWidget);
      expect(find.text('1 aprox. + 2 × 8–12'), findsOneWidget);
      expect(find.text('Ejercicio principal'), findsOneWidget);
      expect(find.text('3 × 15'), findsOneWidget);
      // La biserie es un bloque con sus dos ejercicios marcados A y B.
      expect(find.byType(SupersetBlock), findsOneWidget);
      expect(find.text('Biserie'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SupersetBlock),
          matching: find.text('Press con barra'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SupersetBlock),
          matching: find.text('Aperturas'),
        ),
        findsOneWidget,
      );
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('3 × al fallo'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('crea una rutina a mano con un día y un ejercicio', (
      tester,
    ) async {
      await pumpApp(tester);
      await tap(tester, find.text('Configurar rutina'));

      await tap(tester, find.text('Crear rutina a mano'));
      await type(tester, 'nameField', 'Mi rutina nueva');
      await tap(tester, find.text('Crear'));
      await tap(tester, find.text('Agregar día'));
      await type(tester, 'nameField', 'Pierna');
      await tap(tester, find.text('Guardar'));
      expect(find.text('Sin ejercicios.'), findsOneWidget);

      await tap(tester, find.text('Ejercicio'));
      await type(tester, 'exerciseName', 'Sentadilla');
      await type(tester, 'warmupSets', '2');
      await type(tester, 'workSets', '4');
      await type(tester, 'repsMin', '6');
      await type(tester, 'repsMax', '8');
      await tap(tester, find.text('Guardar ejercicio'));

      expect(find.text('Sentadilla'), findsOneWidget);
      expect(find.text('2 aprox. + 4 × 6–8'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('tocar un ejercicio permite corregirlo o borrarlo', (
      tester,
    ) async {
      await saveRoutine();
      await pumpApp(tester);
      await tap(tester, find.text('Ver rutina'));

      await tap(tester, find.text('Dominadas'));
      await type(tester, 'workSets', '5');
      await tap(tester, find.text('Guardar cambios'));
      expect(find.text('5 × al fallo'), findsOneWidget);

      await tap(tester, find.text('Dominadas'));
      await tap(tester, find.byIcon(CupertinoIcons.trash));
      await tap(tester, find.text('Borrar'));
      expect(find.text('Dominadas'), findsNothing);
      await shutDown(tester);
    });

    testWidgets('el mínimo de repeticiones no puede superar al máximo', (
      tester,
    ) async {
      await saveRoutine();
      await pumpApp(tester);
      await tap(tester, find.text('Ver rutina'));

      await tap(tester, find.text('Press con barra'));
      await type(tester, 'repsMin', '20');
      await tap(tester, find.text('Guardar cambios'));

      expect(find.textContaining('no puede superar al máximo'), findsOneWidget);
      await shutDown(tester);
    });
  });

  group('importar desde PDF', () {
    testWidgets('muestra la revisión y guarda la rutina', (tester) async {
      await pumpApp(tester, picker: examplePdf);
      await tap(tester, find.text('Configurar rutina'));

      await tap(tester, find.text('Importar desde PDF'));
      expect(find.text('Revisar rutina'), findsOneWidget);
      expect(find.text('Rutina de ejemplo'), findsOneWidget);
      expect(find.text('2 días · 12 ejercicios'), findsOneWidget);
      expect(
        find.textContaining('Hay 2 ejercicios que no se entendieron'),
        findsOneWidget,
      );
      expect(await db.select(db.routines).get(), isEmpty); // aún sin guardar

      await tap(tester, find.text('Guardar rutina'));
      expect(find.text('Quedan 2 ejercicios por revisar'), findsOneWidget);
      await tap(tester, find.text('Guardar así'));

      expect(find.text('Revisar rutina'), findsNothing);
      // Al guardar, pasa directo a enlazar los ejercicios con el catálogo.
      expect(find.text('Enlazar con el catálogo'), findsOneWidget);
      expect(find.textContaining('Faltan 12 ejercicios'), findsOneWidget);
      final view = (await RoutineRepository(db).activeRoutine(userId))!;
      expect(view.routine.sourceFileName, 'rutina.pdf');
      expect(view.days.map((d) => d.day.name), ['Empuje', 'Tirón y Core']);
      expect(view.days.first.exercises, hasLength(7));
      await shutDown(tester);
    });

    testWidgets('corregir un ejercicio marcado le quita el aviso', (
      tester,
    ) async {
      await pumpApp(tester, picker: examplePdf);
      await tap(tester, find.text('Configurar rutina'));
      await tap(tester, find.text('Importar desde PDF'));

      await tester.scrollUntilVisible(
        find.text('Caminata de Granjero'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tap(tester, find.text('Caminata de Granjero'));
      await type(tester, 'workSets', '3');
      await tap(tester, find.text('Guardar cambios'));

      expect(
        find.text('No se entendieron las series de este ejercicio.'),
        findsNothing,
      );
      await shutDown(tester);
    });

    testWidgets('un PDF que no es una rutina no abre la revisión', (
      tester,
    ) async {
      await pumpApp(
        tester,
        picker: () async => (fileName: 'x.pdf', text: 'Factura\nTotal: 500'),
      );
      await tap(tester, find.text('Configurar rutina'));
      await tap(tester, find.text('Importar desde PDF'));

      expect(find.text('No se encontró una rutina'), findsOneWidget);
      expect(find.text('Revisar rutina'), findsNothing);
      await shutDown(tester);
    });
  });

  group('sesión que sigue la rutina', () {
    Future<void> startDay(WidgetTester tester, String dayName) async {
      await tap(tester, find.text('Iniciar sesión'));
      // "Fuerza" puede estar también en el historial: se toca la de la hoja.
      await tap(tester, find.text('Fuerza').last);
      // El nombre del día también está en la tarjeta del inicio.
      await tap(tester, find.text(dayName).last);
    }

    testWidgets('al iniciar fuerza pregunta el día y sugiere el primero', (
      tester,
    ) async {
      await saveRoutine();
      await pumpApp(tester);

      await tap(tester, find.text('Iniciar sesión'));
      await tap(tester, find.text('Fuerza'));

      expect(find.text('¿Qué día toca?'), findsOneWidget);
      expect(find.text('Día 1 · 2 ejercicios'), findsOneWidget);
      expect(find.text('Toca hoy'), findsOneWidget);
      expect(find.text('Sesión libre'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('la sesión muestra lo que toca aunque no haya series', (
      tester,
    ) async {
      await saveRoutine();
      await pumpApp(tester);
      await startDay(tester, 'Empuje');

      expect(find.textContaining('Empuje'), findsOneWidget); // en el resumen
      expect(find.text('Press con barra'), findsOneWidget);
      expect(find.text('1 aprox. + 2 × 8–12 · 0 de 2 hechas'), findsOneWidget);
      expect(find.text('Aperturas'), findsOneWidget);
      expect(find.byType(SupersetBlock), findsOneWidget);
      final session = await db.select(db.sessions).getSingle();
      expect(session.routineDayId, isNotNull);
      await shutDown(tester);
    });

    testWidgets('la primera serie se propone como aproximación; después, '
        'efectivas, hasta completar el objetivo', (tester) async {
      await saveRoutine();
      await pumpApp(tester);
      await startDay(tester, 'Empuje');

      // Serie 1: la rutina pide 1 de aproximación → el interruptor ya viene
      // encendido.
      await tap(tester, find.text('Serie').first);
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
        isTrue,
      );
      await type(tester, 'weight', '60');
      await type(tester, 'reps', '10');
      await tap(tester, find.text('Guardar serie'));
      expect(find.byType(WarmupBadge), findsOneWidget);

      // Series 2 y 3: ya efectivas, con el peso anterior propuesto.
      for (var i = 0; i < 2; i++) {
        await tap(tester, find.text('Serie').first);
        expect(
          tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
          isFalse,
        );
        await tap(tester, find.text('Guardar serie'));
      }

      expect(find.text('1 aprox. + 2 × 8–12 · completo'), findsOneWidget);
      final sets = await db.select(db.strengthSets).get();
      expect(sets.map((s) => (s.weight, s.isWarmup)), [
        (60, true),
        (60, false),
        (60, false),
      ]);
      await shutDown(tester);
    });

    testWidgets('propone el peso y la unidad de la última sesión', (
      tester,
    ) async {
      await saveRoutine();
      final routines = RoutineRepository(db);
      final training = TrainingRepository(db);
      final day = (await routines.activeRoutine(userId))!.days[1];
      final exercise = await routines.exerciseFor(day.exercises.single.id);
      final previous = await training.startSession(
        userId: userId,
        type: SessionType.strength,
        routineDayId: day.day.id,
        startedAt: DateTime.now().subtract(const Duration(days: 7)),
      );
      await training.addStrengthSet(
        sessionId: previous.id,
        exerciseId: exercise.id,
        weight: 25,
        weightUnit: WeightUnit.lb,
        reps: 9,
      );
      await pumpApp(tester);

      // Hoy toca "Empuje"; se elige "Tirón" a mano.
      await startDay(tester, 'Tirón');
      await tap(tester, find.text('Serie'));

      final weight = tester.widget<RowTextField>(
        find.byKey(const Key('weight')),
      );
      final reps = tester.widget<RowTextField>(find.byKey(const Key('reps')));
      expect((weight.controller.text, reps.controller.text), ('25', '9'));
      await tap(tester, find.text('Guardar serie'));
      final sets = await db.select(db.strengthSets).get();
      expect(sets.last.weightUnit, WeightUnit.lb);
      await shutDown(tester);
    });

    testWidgets('cambiar el día que toca recorre la rutina y se recuerda', (
      tester,
    ) async {
      await saveRoutine();
      await pumpApp(tester);
      expect(find.text('HOY TOCA · DÍA 1 DE 2'), findsOneWidget);

      await tap(tester, find.byKey(const Key('changeRoutineDay')));
      expect(find.text('¿Qué día toca hoy?'), findsOneWidget);
      expect(find.text('Actual'), findsOneWidget);
      await tap(tester, find.text('Tirón'));

      expect(find.text('HOY TOCA · DÍA 2 DE 2'), findsOneWidget);
      // Si hoy es el Día 2, el Día 1 fue ayer.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(preferences.getInt('routineDayOneWeekday'), yesterday.weekday);
      await shutDown(tester);
    });

    testWidgets('un día de la semana sin rutina se muestra como descanso', (
      tester,
    ) async {
      // Con una rutina de 2 días, se coloca hoy en el cuarto día de la semana.
      await preferences.setInt(
        'routineDayOneWeekday',
        dayOneWeekdayFor(today: DateTime.now(), todayIndex: 3),
      );
      await saveRoutine();
      await pumpApp(tester);

      expect(find.text('Hoy toca descanso'), findsOneWidget);
      expect(find.byKey(const Key('startRoutineDay')), findsNothing);

      // Aun así se puede elegir un día para hoy.
      await tap(tester, find.text('Elegir un día'));
      await tap(tester, find.text('Empuje'));
      expect(find.text('HOY TOCA · DÍA 1 DE 2'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('en un día de descanso, el selector no marca ningún día', (
      tester,
    ) async {
      await preferences.setInt(
        'routineDayOneWeekday',
        dayOneWeekdayFor(today: DateTime.now(), todayIndex: 3),
      );
      await saveRoutine();
      await pumpApp(tester);

      await tap(tester, find.text('Iniciar sesión'));
      await tap(tester, find.text('Fuerza'));

      expect(find.text('¿Qué día toca?'), findsOneWidget);
      expect(find.text('Toca hoy'), findsNothing);
      await shutDown(tester);
    });

    testWidgets('la tarjeta del inicio muestra el día que toca y lo empieza', (
      tester,
    ) async {
      await saveRoutine();
      await pumpApp(tester);

      expect(find.text('HOY TOCA · DÍA 1 DE 2'), findsOneWidget);
      expect(find.text('Empuje'), findsOneWidget);
      expect(find.text('2 ejercicios'), findsOneWidget);

      // "Empezar" abre la sesión de ese día sin preguntar nada.
      await tap(tester, find.byKey(const Key('startRoutineDay')));
      expect(find.text('¿Qué día toca?'), findsNothing);
      expect(find.text('Press con barra'), findsOneWidget);

      // El día depende de la fecha, no de lo que ya se hizo: al volver
      // sigue siendo el mismo.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('HOY TOCA · DÍA 1 DE 2'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('sin rutina, la tarjeta invita a configurarla', (tester) async {
      await pumpApp(tester);

      expect(find.text('Rutina de entrenamiento'), findsOneWidget);
      expect(find.text('Configurar rutina'), findsOneWidget);
      expect(find.byKey(const Key('startRoutineDay')), findsNothing);
      await shutDown(tester);
    });

    testWidgets('"Sesión libre" no sigue la rutina', (tester) async {
      await saveRoutine();
      await pumpApp(tester);
      await startDay(tester, 'Sesión libre');

      expect(find.text('Sin series todavía'), findsOneWidget);
      expect((await db.select(db.sessions).getSingle()).routineDayId, isNull);
      await shutDown(tester);
    });

    testWidgets('un ejercicio fuera de la rutina aparece al final', (
      tester,
    ) async {
      await saveRoutine();
      await pumpApp(tester);
      await startDay(tester, 'Tirón');

      await tap(tester, find.text('Agregar ejercicio'));
      await tap(tester, find.byKey(const Key('exercise')));
      await tap(tester, find.text('Nuevo ejercicio…'));
      await tester.enterText(find.byKey(const Key('exerciseName')), 'Curl');
      await tap(tester, find.text('Guardar'));
      await type(tester, 'weight', '12');
      await type(tester, 'reps', '12');
      await tap(tester, find.text('Guardar serie'));

      expect(find.text('Curl'), findsOneWidget);
      expect(find.text('Dominadas'), findsOneWidget);
      expect(find.text('12 kg × 12'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('sin rutina, iniciar fuerza no pregunta nada', (tester) async {
      await pumpApp(tester);
      await tap(tester, find.text('Iniciar sesión'));
      await tap(tester, find.text('Fuerza'));

      expect(find.text('¿Qué día toca?'), findsNothing);
      expect(find.text('Sin series todavía'), findsOneWidget);
      await shutDown(tester);
    });
  });
}
