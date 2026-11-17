// Las restricciones check() de drift se escriben nombrando la propia columna;
// el analizador lo confunde con recursión, pero drift no ejecuta ese getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'sync_columns.dart';
import 'users.dart';

/// Un suplemento que el usuario toma y del que lleva inventario.
///
/// Compras, dosis y tomas se expresan en una misma unidad, que elige el
/// usuario: gramos para un polvo, cápsulas para un frasco.
class Supplements extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get unitLabel => text().withLength(min: 1, max: 20)();
  RealColumn get dailyDose => real().check(dailyDose.isBiggerThanValue(0))();

  /// Indicación de cuándo tomarlo, como texto.
  TextColumn get timing => text().nullable()();

  /// Con cuántos días de anticipación avisar que hay que reabastecer.
  IntColumn get restockLeadDays => integer()
      .withDefault(const Constant(7))
      .check(restockLeadDays.isBiggerOrEqualValue(0))();
}

/// Una compra: lo que entra al inventario.
@TableIndex(name: 'supplement_purchases_supplement', columns: {#supplementId})
class SupplementPurchases extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get supplementId => text().references(Supplements, #id)();
  RealColumn get quantity => real().check(quantity.isBiggerThanValue(0))();
  DateTimeColumn get purchasedAt => dateTime()();
  TextColumn get note => text().nullable()();
}

/// Lo que sale del inventario: una toma, o un ajuste de existencias.
@TableIndex(name: 'supplement_intakes_supplement', columns: {#supplementId})
class SupplementIntakes extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get supplementId => text().references(Supplements, #id)();
  DateTimeColumn get takenAt => dateTime()();

  /// Positivo en una toma. En un ajuste puede ser negativo: había más de lo
  /// que la app creía.
  RealColumn get amount => real().check(amount.equals(0).not())();

  /// Corrección de existencias: descuenta del inventario pero no cuenta como
  /// toma para la adherencia.
  BoolColumn get isAdjustment => boolean().withDefault(const Constant(false))();
}
