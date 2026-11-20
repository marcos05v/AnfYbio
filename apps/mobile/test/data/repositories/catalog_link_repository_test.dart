import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/repositories/catalog_link_repository.dart';
import 'package:anfybio/data/repositories/routine_repository.dart';
import 'package:anfybio/domain/routine.dart';
import 'package:anfybio/domain/weight.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CatalogLinkRepository repo;
  late String userId;
  const benchId = 'Barbell_Bench_Press_-_Medium_Grip';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CatalogLinkRepository(db);
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Prueba'));
    userId = user.id;
  });
  tearDown(() => db.close());

  Future<Exercise> exercise(String name) => db
      .into(db.exercises)
      .insertReturning(
        ExercisesCompanion.insert(
          userId: userId,
          name: name,
          defaultUnit: WeightUnit.kg,
        ),
      );

  test('enlazar guarda el alias y el enlace del ejercicio', () async {
    final bench = await exercise('Press de Banca Plano con Barra');

    await repo.link(
      userId: userId,
      name: bench.name,
      catalogId: benchId,
      exerciseId: bench.id,
    );

    expect((await db.select(db.exercises).getSingle()).catalogId, benchId);
    // El alias no distingue acentos, mayúsculas ni signos.
    expect(
      await repo.catalogIdFor(userId, 'press de banca plano con barra'),
      benchId,
    );
    expect(
      await repo.catalogIdFor(userId, 'PRESS DE BANCA PLANO, CON BARRA'),
      benchId,
    );
  });

  test('volver a enlazar el mismo nombre reemplaza el destino', () async {
    await repo.link(userId: userId, name: 'Press', catalogId: 'A');
    await repo.link(userId: userId, name: 'Press', catalogId: 'B');

    expect(await repo.catalogIdFor(userId, 'Press'), 'B');
    expect(await db.select(db.exerciseAliases).get(), hasLength(1));
  });

  test('quitar el enlace lo borra del alias y del ejercicio', () async {
    final bench = await exercise('Press de banca');
    await repo.link(
      userId: userId,
      name: bench.name,
      catalogId: benchId,
      exerciseId: bench.id,
    );

    await repo.unlink(userId: userId, name: bench.name, exerciseId: bench.id);

    expect(await repo.catalogIdFor(userId, bench.name), isNull);
    expect((await db.select(db.exercises).getSingle()).catalogId, isNull);
    // Volver a enlazarlo después funciona.
    await repo.link(userId: userId, name: bench.name, catalogId: benchId);
    expect(await repo.catalogIdFor(userId, bench.name), benchId);
  });

  test('los alias de un usuario no afectan a otro', () async {
    final other = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Hermana'));
    await repo.link(userId: userId, name: 'Press de banca', catalogId: benchId);

    expect(await repo.catalogIdFor(other.id, 'Press de banca'), isNull);
  });

  test('watchAliases emite el mapa de nombres a ejercicios', () async {
    await repo.link(userId: userId, name: 'Press de Banca', catalogId: benchId);
    expect(await repo.watchAliases(userId).first, {'press de banca': benchId});
  });

  test('un ejercicio de la rutina hereda el enlace al usarse', () async {
    await repo.link(
      userId: userId,
      name: 'Press de Banca Plano con Barra',
      catalogId: benchId,
    );
    final routines = RoutineRepository(db);
    await routines.saveRoutine(
      userId,
      const RoutineDraft(
        name: 'Rutina',
        days: [
          RoutineDayDraft(
            name: 'Pecho',
            exercises: [
              RoutineExerciseDraft(name: 'Press de banca plano con barra'),
            ],
          ),
        ],
      ),
    );
    final routineExercise = (await routines.activeRoutine(userId))!
        .days
        .single
        .exercises
        .single;

    final created = await routines.exerciseFor(routineExercise.id);

    expect(created.catalogId, benchId);
    expect((await db.select(db.exercises).getSingle()).catalogId, benchId);
  });
}
