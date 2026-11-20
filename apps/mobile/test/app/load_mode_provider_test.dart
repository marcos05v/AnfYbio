import 'dart:io';

import 'package:anfybio/app/catalog.dart';
import 'package:anfybio/app/providers.dart';
import 'package:anfybio/catalog/exercise_catalog.dart';
import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/repositories/exercise_repository.dart';
import 'package:anfybio/domain/load_mode.dart';
import 'package:anfybio/domain/weight.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogJson = File('assets/catalog/exercises.json').readAsStringSync();
  late AppDatabase db;
  late ProviderContainer container;
  late String userId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        exerciseCatalogProvider.overrideWithValue(
          BundledExerciseCatalog(() async => catalogJson),
        ),
      ],
    );
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Prueba'));
    userId = user.id;
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Exercise> exercise({String? catalogId, LoadMode? mode}) => db
      .into(db.exercises)
      .insertReturning(
        ExercisesCompanion.insert(
          userId: userId,
          name: 'Ejercicio',
          defaultUnit: WeightUnit.kg,
          catalogId: Value(catalogId),
          loadMode: Value(mode),
        ),
      );

  Future<LoadMode> modeOf(Exercise e) async {
    if (e.catalogId case final id?) {
      await container.read(catalogExerciseProvider(id).future);
    }
    return container.read(loadModeProvider(e));
  }

  test('sin catálogo ni elección, el peso es total', () async {
    expect(await modeOf(await exercise()), LoadMode.total);
  });

  test(
    'enlazado a un ejercicio con mancuernas, sugiere por mancuerna',
    () async {
      final arnold = await exercise(catalogId: 'Arnold_Dumbbell_Press');
      expect(await modeOf(arnold), LoadMode.perHand);
      final bench = await exercise(
        catalogId: 'Barbell_Bench_Press_-_Medium_Grip',
      );
      expect(await modeOf(bench), LoadMode.total);
    },
  );

  test('lo que elige el usuario manda sobre el catálogo', () async {
    final arnold = await exercise(
      catalogId: 'Arnold_Dumbbell_Press',
      mode: LoadMode.total,
    );
    expect(await modeOf(arnold), LoadMode.total);
  });

  test('setLoadMode guarda la elección y marca el cambio', () async {
    final e = await exercise();
    final later = DateTime.utc(2030);

    await ExerciseRepository(db)
        .setLoadMode(e.id, LoadMode.perSide, now: later);

    final saved = await db.select(db.exercises).getSingle();
    expect(saved.loadMode, LoadMode.perSide);
    expect(saved.updatedAt, later);
  });
}
