import 'dart:async';

import 'package:drift/drift.dart';

import '../../domain/supplement_inventory.dart';
import '../database.dart';
import 'training_repository.dart' show RecordNotFound;

/// Un suplemento con todo su movimiento de inventario.
class SupplementView {
  const SupplementView({
    required this.supplement,
    required this.purchases,
    required this.intakes,
  });

  final Supplement supplement;

  /// Compras, de la más reciente a la más antigua.
  final List<SupplementPurchase> purchases;

  /// Tomas y ajustes, del más reciente al más antiguo.
  final List<SupplementIntake> intakes;

  /// Estado del inventario visto desde [now] (hora local).
  InventoryStatus statusAt(DateTime now) => inventoryStatus(
    dailyDose: supplement.dailyDose,
    restockLeadDays: supplement.restockLeadDays,
    purchases: [
      for (final p in purchases)
        (at: p.purchasedAt.toLocal(), quantity: p.quantity),
    ],
    outflows: [
      for (final i in intakes)
        (
          at: i.takenAt.toLocal(),
          amount: i.amount,
          isAdjustment: i.isAdjustment,
        ),
    ],
    now: now,
  );
}

/// Inventario de suplementos: altas, compras, tomas y ajustes.
///
/// Las existencias no se guardan: son siempre compras menos tomas y ajustes.
class SupplementRepository {
  SupplementRepository(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _now;

  // ------------------------------------------------------------- suplementos

  /// Da de alta un suplemento. Con [initialQuantity] registra además el
  /// envase que ya se tiene como primera compra, con fecha [purchasedAt].
  ///
  /// Si el envase ya está empezado, [alreadyConsumed] es lo que se calcula
  /// que se ha tomado: se anota como un ajuste, no como tomas, para que no
  /// cuente en la adherencia.
  Future<Supplement> addSupplement({
    required String userId,
    required String name,
    required String unitLabel,
    required double dailyDose,
    String? timing,
    int restockLeadDays = 7,
    double? initialQuantity,
    DateTime? purchasedAt,
    double alreadyConsumed = 0,
  }) {
    return _db.transaction(() async {
      final supplement = await _db
          .into(_db.supplements)
          .insertReturning(
            SupplementsCompanion.insert(
              userId: userId,
              name: name.trim(),
              unitLabel: unitLabel.trim(),
              dailyDose: dailyDose,
              timing: Value(_clean(timing)),
              restockLeadDays: Value(restockLeadDays),
            ),
          );
      if (initialQuantity != null && initialQuantity > 0) {
        await _insertPurchase(supplement, initialQuantity, purchasedAt, null);
        if (alreadyConsumed > 0) {
          await _db
              .into(_db.supplementIntakes)
              .insert(
                SupplementIntakesCompanion.insert(
                  userId: userId,
                  supplementId: supplement.id,
                  takenAt: _now(),
                  amount: alreadyConsumed,
                  isAdjustment: const Value(true),
                ),
              );
        }
      }
      return supplement;
    });
  }

  Future<void> updateSupplement(
    String supplementId, {
    required String name,
    required String unitLabel,
    required double dailyDose,
    required String? timing,
    required int restockLeadDays,
  }) async {
    final updated =
        await (_db.update(_db.supplements)
              ..where((s) => s.id.equals(supplementId) & s.deletedAt.isNull()))
            .write(
              SupplementsCompanion(
                name: Value(name.trim()),
                unitLabel: Value(unitLabel.trim()),
                dailyDose: Value(dailyDose),
                timing: Value(_clean(timing)),
                restockLeadDays: Value(restockLeadDays),
                updatedAt: Value(_now()),
              ),
            );
    if (updated == 0) throw RecordNotFound(supplementId);
  }

  /// Borra el suplemento con sus compras y tomas (borrado lógico).
  Future<void> deleteSupplement(String supplementId) {
    return _db.transaction(() async {
      final now = Value(_now());
      final deleted =
          await (_db.update(
                _db.supplements,
              )..where((s) => s.id.equals(supplementId) & s.deletedAt.isNull()))
              .write(SupplementsCompanion(deletedAt: now, updatedAt: now));
      if (deleted == 0) throw RecordNotFound(supplementId);
      await (_db.update(_db.supplementPurchases)..where(
            (p) => p.supplementId.equals(supplementId) & p.deletedAt.isNull(),
          ))
          .write(SupplementPurchasesCompanion(deletedAt: now, updatedAt: now));
      await (_db.update(_db.supplementIntakes)..where(
            (i) => i.supplementId.equals(supplementId) & i.deletedAt.isNull(),
          ))
          .write(SupplementIntakesCompanion(deletedAt: now, updatedAt: now));
    });
  }

  /// Suplementos del usuario con su movimiento, en orden alfabético.
  Future<List<SupplementView>> supplementsOf(String userId) async {
    final supplements =
        await (_db.select(_db.supplements)
              ..where((s) => s.userId.equals(userId) & s.deletedAt.isNull())
              ..orderBy([(s) => OrderingTerm.asc(s.name.lower())]))
            .get();
    final ids = supplements.map((s) => s.id);
    final purchases =
        await (_db.select(_db.supplementPurchases)
              ..where((p) => p.supplementId.isIn(ids) & p.deletedAt.isNull())
              ..orderBy([(p) => OrderingTerm.desc(p.purchasedAt)]))
            .get();
    final intakes =
        await (_db.select(_db.supplementIntakes)
              ..where((i) => i.supplementId.isIn(ids) & i.deletedAt.isNull())
              ..orderBy([(i) => OrderingTerm.desc(i.takenAt)]))
            .get();

    return [
      for (final supplement in supplements)
        SupplementView(
          supplement: supplement,
          purchases: [
            for (final p in purchases)
              if (p.supplementId == supplement.id) p,
          ],
          intakes: [
            for (final i in intakes)
              if (i.supplementId == supplement.id) i,
          ],
        ),
    ];
  }

  /// Igual que [supplementsOf], pero vuelve a emitir cuando cambia algo.
  Stream<List<SupplementView>> watchSupplementsOf(String userId) {
    final changes = _db.tableUpdates(
      TableUpdateQuery.onAllTables([
        _db.supplements,
        _db.supplementPurchases,
        _db.supplementIntakes,
      ]),
    );
    late final StreamController<List<SupplementView>> controller;
    StreamSubscription<void>? subscription;

    Future<void> emit() async {
      final views = await supplementsOf(userId);
      if (!controller.isClosed) controller.add(views);
    }

    controller = StreamController<List<SupplementView>>(
      onListen: () {
        subscription = changes.listen((_) => emit());
        emit();
      },
      onCancel: () async {
        await subscription?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  // ----------------------------------------------------------------- compras

  Future<SupplementPurchase> addPurchase(
    String supplementId, {
    required double quantity,
    DateTime? purchasedAt,
    String? note,
  }) async {
    final supplement = await _supplement(supplementId);
    return _insertPurchase(supplement, quantity, purchasedAt, note);
  }

  Future<void> deletePurchase(String purchaseId) async {
    final now = Value(_now());
    final deleted =
        await (_db.update(
          _db.supplementPurchases,
        )..where((p) => p.id.equals(purchaseId) & p.deletedAt.isNull())).write(
          SupplementPurchasesCompanion(deletedAt: now, updatedAt: now),
        );
    if (deleted == 0) throw RecordNotFound(purchaseId);
  }

  // ------------------------------------------------------------------- tomas

  /// Registra una toma. Sin [amount] es la dosis diaria del suplemento.
  Future<SupplementIntake> logIntake(
    String supplementId, {
    double? amount,
    DateTime? takenAt,
  }) async {
    final supplement = await _supplement(supplementId);
    return _db
        .into(_db.supplementIntakes)
        .insertReturning(
          SupplementIntakesCompanion.insert(
            userId: supplement.userId,
            supplementId: supplementId,
            takenAt: (takenAt ?? _now()).toUtc(),
            amount: amount ?? supplement.dailyDose,
          ),
        );
  }

  /// Borra una toma o un ajuste.
  Future<void> deleteIntake(String intakeId) async {
    final now = Value(_now());
    final deleted =
        await (_db.update(_db.supplementIntakes)
              ..where((i) => i.id.equals(intakeId) & i.deletedAt.isNull()))
            .write(SupplementIntakesCompanion(deletedAt: now, updatedAt: now));
    if (deleted == 0) throw RecordNotFound(intakeId);
  }

  /// Corrige las existencias para que coincidan con lo que realmente queda.
  ///
  /// No modifica compras ni tomas: agrega un ajuste por la diferencia, que
  /// descuenta (o devuelve) inventario sin contar como toma.
  Future<void> adjustStock(
    String supplementId, {
    required double actualStock,
    required DateTime now,
  }) {
    return _db.transaction(() async {
      final supplement = await _supplement(supplementId);
      final view = (await supplementsOf(supplement.userId))
          .singleWhere((v) => v.supplement.id == supplementId);
      final difference = view.statusAt(now).stock - actualStock;
      if (difference == 0) return;

      await _db
          .into(_db.supplementIntakes)
          .insert(
            SupplementIntakesCompanion.insert(
              userId: supplement.userId,
              supplementId: supplementId,
              takenAt: _now(),
              amount: difference,
              isAdjustment: const Value(true),
            ),
          );
    });
  }

  // ---------------------------------------------------------------- internos

  Future<Supplement> _supplement(String id) async {
    final supplement = await (_db.select(
      _db.supplements,
    )..where((s) => s.id.equals(id) & s.deletedAt.isNull())).getSingleOrNull();
    if (supplement == null) throw RecordNotFound(id);
    return supplement;
  }

  Future<SupplementPurchase> _insertPurchase(
    Supplement supplement,
    double quantity,
    DateTime? purchasedAt,
    String? note,
  ) {
    return _db
        .into(_db.supplementPurchases)
        .insertReturning(
          SupplementPurchasesCompanion.insert(
            userId: supplement.userId,
            supplementId: supplement.id,
            quantity: quantity,
            purchasedAt: (purchasedAt ?? _now()).toUtc(),
            note: Value(_clean(note)),
          ),
        );
  }

  String? _clean(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
