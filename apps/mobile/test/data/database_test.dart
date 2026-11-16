import 'package:anfybio/data/database.dart';
import 'package:anfybio/domain/weight.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  // Cada prueba recibe una base nueva en memoria: no comparten datos.
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<User> createUser() => db
      .into(db.users)
      .insertReturning(UsersCompanion.insert(displayName: 'Prueba'));

  test('guarda un ejercicio y lo lee de vuelta', () async {
    final user = await createUser();

    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            userId: user.id,
            name: 'Sentadilla',
            defaultUnit: WeightUnit.lb,
          ),
        );

    final exercise = await db.select(db.exercises).getSingle();
    expect(exercise.name, 'Sentadilla');
    expect(exercise.defaultUnit, WeightUnit.lb);
    expect(exercise.userId, user.id);
    expect(exercise.catalogId, isNull);
  });

  test('las columnas de sincronización se llenan solas', () async {
    final user = await createUser();

    // UUID versión 7: el carácter 15 indica la versión.
    expect(user.id, hasLength(36));
    expect(user.id[14], '7');
    expect(user.createdAt.isUtc, isTrue);
    expect(user.updatedAt.isUtc, isTrue);
    expect(user.deletedAt, isNull);
  });

  test('rechaza un ejercicio de un usuario que no existe', () async {
    final insert = db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            userId: 'no-existe',
            name: 'Sentadilla',
            defaultUnit: WeightUnit.kg,
          ),
        );

    await expectLater(insert, throwsA(isA<SqliteException>()));
  });

  test('rechaza un nombre de ejercicio vacío', () async {
    final user = await createUser();

    final insert = db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            userId: user.id,
            name: '',
            defaultUnit: WeightUnit.kg,
          ),
        );

    await expectLater(insert, throwsA(anything));
  });
}
