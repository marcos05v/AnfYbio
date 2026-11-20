import 'package:drift/drift.dart';

import '../../catalog/exercise_matching.dart';
import '../database.dart';

/// Enlaces entre los ejercicios del usuario y el catálogo (ADR-0015).
///
/// Un enlace se guarda en dos lugares: en el ejercicio (`catalogId`), para
/// mostrar sus fotos e instrucciones, y como alias del nombre en español,
/// para que la próxima vez que aparezca ese nombre se enlace solo.
class CatalogLinkRepository {
  CatalogLinkRepository(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Alias del usuario: nombre normalizado → id del catálogo.
  Stream<Map<String, String>> watchAliases(String userId) {
    return (_db.select(_db.exerciseAliases)
          ..where((a) => a.userId.equals(userId) & a.deletedAt.isNull()))
        .watch()
        .map((rows) => {for (final row in rows) row.alias: row.catalogId});
  }

  /// El id del catálogo ya confirmado para ese nombre, si lo hay.
  Future<String?> catalogIdFor(String userId, String name) async {
    final alias = await _alias(userId, normalizeText(name));
    return alias?.catalogId;
  }

  /// Enlaza el nombre [name] con [catalogId] y, si se indica, también el
  /// ejercicio [exerciseId]. Si el nombre ya tenía otro enlace, se reemplaza.
  Future<void> link({
    required String userId,
    required String name,
    required String catalogId,
    String? exerciseId,
  }) {
    return _db.transaction(() async {
      final key = normalizeText(name);
      if (key.isEmpty) return;
      final existing = await _alias(userId, key);
      if (existing == null) {
        await _db
            .into(_db.exerciseAliases)
            .insert(
              ExerciseAliasesCompanion.insert(
                userId: userId,
                alias: key.length > 200 ? key.substring(0, 200) : key,
                catalogId: catalogId,
              ),
            );
      } else if (existing.catalogId != catalogId) {
        await (_db.update(
          _db.exerciseAliases,
        )..where((a) => a.id.equals(existing.id))).write(
          ExerciseAliasesCompanion(
            catalogId: Value(catalogId),
            updatedAt: Value(_now()),
          ),
        );
      }
      if (exerciseId != null) await _setExercise(exerciseId, catalogId);
    });
  }

  /// Quita el enlace del nombre y, si se indica, del ejercicio.
  Future<void> unlink({
    required String userId,
    required String name,
    String? exerciseId,
  }) {
    return _db.transaction(() async {
      final existing = await _alias(userId, normalizeText(name));
      if (existing != null) {
        final now = Value(_now());
        await (_db.update(_db.exerciseAliases)
              ..where((a) => a.id.equals(existing.id)))
            .write(ExerciseAliasesCompanion(deletedAt: now, updatedAt: now));
      }
      if (exerciseId != null) await _setExercise(exerciseId, null);
    });
  }

  Future<void> _setExercise(String exerciseId, String? catalogId) {
    return (_db.update(
      _db.exercises,
    )..where((e) => e.id.equals(exerciseId))).write(
      ExercisesCompanion(catalogId: Value(catalogId), updatedAt: Value(_now())),
    );
  }

  Future<ExerciseAliase?> _alias(String userId, String key) {
    return (_db.select(_db.exerciseAliases)
          ..where(
            (a) =>
                a.userId.equals(userId) &
                a.alias.equals(key) &
                a.deletedAt.isNull(),
          )
          ..limit(1))
        .getSingleOrNull();
  }
}
