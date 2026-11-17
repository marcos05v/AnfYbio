import 'package:drift/drift.dart';

import '../database.dart';
import 'training_repository.dart' show RecordNotFound;

/// Lotes de cocción del usuario.
class CookingRepository {
  CookingRepository(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Lotes del usuario, del más reciente al más antiguo.
  Stream<List<CookingBatch>> watchBatchesOf(String userId) {
    return (_db.select(_db.cookingBatches)
          ..where((b) => b.userId.equals(userId) & b.deletedAt.isNull())
          ..orderBy([
            (b) => OrderingTerm.desc(b.cookedAt),
            (b) => OrderingTerm.desc(b.createdAt),
          ]))
        .watch();
  }

  Future<CookingBatch> addBatch({
    required String userId,
    required String foodName,
    required double rawWeightG,
    required double cookedWeightG,
    bool withOtherIngredients = false,
    String? note,
    DateTime? cookedAt,
  }) {
    return _db
        .into(_db.cookingBatches)
        .insertReturning(
          CookingBatchesCompanion.insert(
            userId: userId,
            foodName: foodName.trim(),
            rawWeightG: rawWeightG,
            cookedWeightG: cookedWeightG,
            cookedAt: (cookedAt ?? _now()).toUtc(),
            withOtherIngredients: Value(withOtherIngredients),
            note: Value(_clean(note)),
          ),
        );
  }

  /// Corrige un lote. La fecha en que se cocinó no cambia.
  Future<void> updateBatch(
    String batchId, {
    required String foodName,
    required double rawWeightG,
    required double cookedWeightG,
    required bool withOtherIngredients,
    required String? note,
  }) async {
    final updated =
        await (_db.update(
          _db.cookingBatches,
        )..where((b) => b.id.equals(batchId) & b.deletedAt.isNull())).write(
          CookingBatchesCompanion(
            foodName: Value(foodName.trim()),
            rawWeightG: Value(rawWeightG),
            cookedWeightG: Value(cookedWeightG),
            withOtherIngredients: Value(withOtherIngredients),
            note: Value(_clean(note)),
            updatedAt: Value(_now()),
          ),
        );
    if (updated == 0) throw RecordNotFound(batchId);
  }

  Future<void> deleteBatch(String batchId) async {
    final now = Value(_now());
    final deleted =
        await (_db.update(_db.cookingBatches)
              ..where((b) => b.id.equals(batchId) & b.deletedAt.isNull()))
            .write(CookingBatchesCompanion(deletedAt: now, updatedAt: now));
    if (deleted == 0) throw RecordNotFound(batchId);
  }

  String? _clean(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
