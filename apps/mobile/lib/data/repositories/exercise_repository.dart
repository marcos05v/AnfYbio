import 'package:drift/drift.dart';

import '../../domain/weight.dart';
import '../database.dart';

/// Ejercicios de fuerza definidos por el usuario.
class ExerciseRepository {
  ExerciseRepository(this._db);

  final AppDatabase _db;

  /// Ejercicios del usuario en orden alfabético, sin distinguir mayúsculas.
  Stream<List<Exercise>> watchExercisesOf(String userId) {
    return (_db.select(_db.exercises)
          ..where((e) => e.userId.equals(userId) & e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm.asc(e.name.lower())]))
        .watch();
  }

  Future<Exercise> createExercise({
    required String userId,
    required String name,
    required WeightUnit defaultUnit,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('El nombre no puede estar vacío.');
    return _db
        .into(_db.exercises)
        .insertReturning(
          ExercisesCompanion.insert(
            userId: userId,
            name: trimmed,
            defaultUnit: defaultUnit,
          ),
        );
  }
}
