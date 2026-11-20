import 'dart:io';

import 'package:anfybio/app/appearance.dart';
import 'package:anfybio/app/catalog.dart';
import 'package:anfybio/app/providers.dart';
import 'package:anfybio/catalog/exercise_catalog.dart';
import 'package:anfybio/catalog/exercise_images.dart';
import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/repositories/catalog_link_repository.dart';
import 'package:anfybio/data/repositories/routine_repository.dart';
import 'package:anfybio/domain/routine.dart';
import 'package:anfybio/ui/app.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacén de fotos falso: anota lo que se pidió y no descarga nada.
class FakeImageStore implements ExerciseImageStore {
  final requested = <String>[];

  @override
  Future<File?> image(String relativePath) async {
    requested.add(relativePath);
    return null;
  }

  @override
  Future<int> downloadAll(
    List<String> relativePaths, {
    void Function(int done, int total)? onProgress,
  }) async {
    for (final (index, path) in relativePaths.indexed) {
      requested.add(path);
      onProgress?.call(index + 1, relativePaths.length);
    }
    return 0;
  }
}

void main() {
  final catalogJson = File('assets/catalog/exercises.json').readAsStringSync();
  late AppDatabase db;
  late SharedPreferences preferences;
  late String userId;
  late FakeImageStore images;
  const benchId = 'Barbell_Bench_Press_-_Medium_Grip';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'routineDayOneWeekday': DateTime.now().weekday,
    });
    preferences = await SharedPreferences.getInstance();
    images = FakeImageStore();
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Ana'));
    userId = user.id;
    await RoutineRepository(db).saveRoutine(
      userId,
      const RoutineDraft(
        name: 'Rutina',
        days: [
          RoutineDayDraft(
            name: 'Empuje',
            exercises: [
              RoutineExerciseDraft(
                name: 'Press de banca plano con barra',
                workSets: 4,
              ),
              RoutineExerciseDraft(name: 'Face pull', workSets: 3),
              RoutineExerciseDraft(name: 'Xqzw raro', workSets: 3),
            ],
          ),
        ],
      ),
    );
  });

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(preferences),
          exerciseImageStoreProvider.overrideWithValue(images),
          // El catálogo real, leído de antemano: cargarlo de los recursos es
          // una operación de disco que no avanza con el reloj simulado de las
          // pruebas.
          exerciseCatalogProvider.overrideWithValue(
            BundledExerciseCatalog(() async => catalogJson),
          ),
        ],
        child: const AnfybioApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openRoutine(WidgetTester tester) async {
    await pumpApp(tester);
    await tap(tester, find.text('Ver rutina'));
  }

  Future<void> shutDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  Future<RoutineExercise> routineExercise(String name) async {
    final view = (await RoutineRepository(db).activeRoutine(userId))!;
    return view.days.single.exercises.singleWhere((e) => e.name == name);
  }

  Future<void> linkBench() async {
    final exercise = await RoutineRepository(
      db,
    ).exerciseFor((await routineExercise('Press de banca plano con barra')).id);
    await CatalogLinkRepository(db).link(
      userId: userId,
      name: 'Press de banca plano con barra',
      catalogId: benchId,
      exerciseId: exercise.id,
    );
  }

  testWidgets('la rutina avisa cuántos ejercicios faltan por enlazar', (
    tester,
  ) async {
    await openRoutine(tester);

    expect(find.text('3 ejercicios sin enlazar'), findsOneWidget);
    expect(find.text('Enlazar'), findsNWidgets(3));
    await shutDown(tester);
  });

  testWidgets('la revisión sugiere y solo enlaza al confirmar', (tester) async {
    await openRoutine(tester);
    await tap(tester, find.byKey(const Key('pendingLinks')));
    final bench = await routineExercise('Press de banca plano con barra');

    expect(
      tester.widget<Text>(find.byKey(Key('suggestion-${bench.id}'))).data,
      'Press de banca con barra - agarre medio',
    );
    // Sugerir no enlaza nada.
    expect(await db.select(db.exerciseAliases).get(), isEmpty);

    await tap(tester, find.byKey(Key('confirm-${bench.id}')));

    final alias = await db.select(db.exerciseAliases).getSingle();
    expect(
      (alias.alias, alias.catalogId),
      ('press de banca plano con barra', benchId),
    );
    final exercise = await db.select(db.exercises).getSingle();
    expect(exercise.catalogId, benchId);
    expect(
      find.text(
        'Faltan 2 ejercicios. Confirma cada sugerencia o elige '
        'otro: la próxima vez esos nombres se enlazan solos.',
      ),
      findsOneWidget,
    );
    await shutDown(tester);
  });

  testWidgets('sin sugerencia, se busca y se elige a mano', (tester) async {
    await openRoutine(tester);
    await tap(tester, find.byKey(const Key('pendingLinks')));
    final rare = await routineExercise('Xqzw raro');
    expect(find.text('Sin sugerencias: elígelo a mano.'), findsOneWidget);

    await tap(tester, find.byKey(Key('other-${rare.id}')));
    await tester.enterText(find.byKey(const Key('catalogSearch')), 'face pull');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Face pull').last);

    expect(
      await CatalogLinkRepository(db).catalogIdFor(userId, 'Xqzw raro'),
      'Face_Pull',
    );
    await shutDown(tester);
  });

  testWidgets('un ejercicio enlazado abre su ficha en español', (tester) async {
    await linkBench();
    await openRoutine(tester);
    final bench = await routineExercise('Press de banca plano con barra');

    await tap(tester, find.byKey(Key('catalog-${bench.id}')));

    expect(
      find.text('Press de banca con barra - agarre medio'),
      findsOneWidget,
    );
    expect(find.text('Barbell Bench Press - Medium Grip'), findsOneWidget);
    expect(find.text('Cómo hacerlo'), findsOneWidget);
    expect(find.text('Pecho'), findsOneWidget); // músculo principal traducido
    expect(find.textContaining('Barra · Principiante'), findsOneWidget);
    // Se pidieron sus dos fotos; sin internet lo explica.
    expect(images.requested, ['$benchId/0.jpg', '$benchId/1.jpg']);
    expect(find.textContaining('Las fotos se descargan'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('desde la ficha se quita el enlace', (tester) async {
    await linkBench();
    await openRoutine(tester);
    final bench = await routineExercise('Press de banca plano con barra');

    await tap(tester, find.byKey(Key('catalog-${bench.id}')));
    await tap(tester, find.byIcon(CupertinoIcons.ellipsis_circle));
    await tap(tester, find.text('Quitar enlace'));

    expect(find.byKey(Key('link-${bench.id}')), findsOneWidget);
    expect((await db.select(db.exercises).getSingle()).catalogId, isNull);
    await shutDown(tester);
  });

  testWidgets('descargar las fotos de la rutina guarda las de los enlazados', (
    tester,
  ) async {
    await linkBench();
    await openRoutine(tester);

    await tap(tester, find.byIcon(CupertinoIcons.ellipsis_circle));
    await tap(tester, find.text('Descargar fotos de la rutina'));

    expect(
      tester.widget<Text>(find.byKey(const Key('downloadResult'))).data,
      'Listo: las 2 fotos quedaron guardadas en el teléfono.',
    );
    expect(images.requested, ['$benchId/0.jpg', '$benchId/1.jpg']);
    await shutDown(tester);
  });

  testWidgets('sin ejercicios enlazados, la descarga lo explica', (
    tester,
  ) async {
    await openRoutine(tester);

    await tap(tester, find.byIcon(CupertinoIcons.ellipsis_circle));
    await tap(tester, find.text('Descargar fotos de la rutina'));

    expect(find.text('Aún no hay fotos que descargar'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('en la sesión, un ejercicio enlazado muestra cómo se hace', (
    tester,
  ) async {
    await linkBench();
    await pumpApp(tester);
    final bench = await routineExercise('Press de banca plano con barra');
    final faceUp = await routineExercise('Face pull');

    await tap(tester, find.byKey(const Key('startRoutineDay')));

    expect(find.byKey(Key('howTo-${faceUp.id}')), findsNothing);
    await tap(tester, find.byKey(Key('howTo-${bench.id}')));
    expect(find.text('Cómo hacerlo'), findsOneWidget);
    await shutDown(tester);
  });
}
