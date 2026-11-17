// Las restricciones check() de drift se escriben nombrando la propia columna;
// el analizador lo confunde con recursión, pero drift no ejecuta ese getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'sync_columns.dart';
import 'users.dart';

/// Un lote cocinado: cuánto pesaba en crudo y cuánto ya cocido.
///
/// El factor de rendimiento (cocido ÷ crudo) no se guarda: se calcula
/// (ADR-0002, regla 5).
@DataClassName('CookingBatch')
@TableIndex(name: 'cooking_batches_user', columns: {#userId, #cookedAt})
class CookingBatches extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get foodName => text().withLength(min: 1, max: 100)();
  RealColumn get rawWeightG => real().check(rawWeightG.isBiggerThanValue(0))();
  RealColumn get cookedWeightG =>
      real().check(cookedWeightG.isBiggerThanValue(0))();
  DateTimeColumn get cookedAt => dateTime()();

  /// Se cocinó junto con salsa, verduras u otros ingredientes: el peso
  /// cocido los incluye y el factor es solo aproximado.
  BoolColumn get withOtherIngredients =>
      boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
}
