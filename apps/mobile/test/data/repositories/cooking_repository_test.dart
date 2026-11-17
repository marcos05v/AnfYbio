import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/repositories/cooking_repository.dart';
import 'package:anfybio/data/repositories/training_repository.dart'
    show RecordNotFound;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CookingRepository repo;
  late String userId;
  var clock = DateTime.utc(2026, 11, 16, 12);

  setUp(() async {
    clock = DateTime.utc(2026, 11, 16, 12);
    db = AppDatabase(NativeDatabase.memory());
    repo = CookingRepository(db, now: () => clock);
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Prueba'));
    userId = user.id;
  });
  tearDown(() => db.close());

  Future<CookingBatch> chicken({DateTime? cookedAt}) => repo.addBatch(
    userId: userId,
    foodName: ' Pechuga de pollo ',
    rawWeightG: 1000,
    cookedWeightG: 720,
    cookedAt: cookedAt,
  );

  test(
    'un lote nuevo se fecha ahora y guarda el nombre sin espacios',
    () async {
      final batch = await chicken();

      expect(batch.foodName, 'Pechuga de pollo');
      expect(batch.cookedAt, clock);
      expect((batch.withOtherIngredients, batch.note), (false, null));
    },
  );

  test('lista los lotes del más reciente al más antiguo', () async {
    await chicken(cookedAt: DateTime.utc(2026, 11, 1));
    final recent = await chicken(cookedAt: DateTime.utc(2026, 11, 10));

    final batches = await repo.watchBatchesOf(userId).first;
    expect(batches, hasLength(2));
    expect(batches.first.id, recent.id);
  });

  test('no muestra los lotes de otro usuario', () async {
    final other = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Hermana'));
    await chicken();

    expect(await repo.watchBatchesOf(other.id).first, isEmpty);
  });

  test('editar cambia los pesos pero no la fecha del lote', () async {
    final batch = await chicken(cookedAt: DateTime.utc(2026, 11, 10));
    clock = clock.add(const Duration(hours: 1));

    await repo.updateBatch(
      batch.id,
      foodName: 'Pollo',
      rawWeightG: 900,
      cookedWeightG: 650,
      withOtherIngredients: true,
      note: 'Con salsa',
    );

    final edited = (await repo.watchBatchesOf(userId).first).single;
    expect(
      (edited.foodName, edited.rawWeightG, edited.cookedWeightG),
      ('Pollo', 900, 650),
    );
    expect((edited.withOtherIngredients, edited.note), (true, 'Con salsa'));
    expect(edited.cookedAt, DateTime.utc(2026, 11, 10));
    expect(edited.updatedAt, clock);
  });

  test('borrar un lote lo quita de la lista, no de la base', () async {
    final batch = await chicken();

    await repo.deleteBatch(batch.id);

    expect(await repo.watchBatchesOf(userId).first, isEmpty);
    expect((await db.select(db.cookingBatches).getSingle()).deletedAt, clock);
    await expectLater(
      repo.deleteBatch(batch.id),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('la base rechaza pesos que no sean positivos', () async {
    await expectLater(
      repo.addBatch(
        userId: userId,
        foodName: 'Pollo',
        rawWeightG: 0,
        cookedWeightG: 500,
      ),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      repo.addBatch(
        userId: userId,
        foodName: 'Pollo',
        rawWeightG: 500,
        cookedWeightG: -1,
      ),
      throwsA(isA<Exception>()),
    );
  });
}
