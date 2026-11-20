import 'package:drift/drift.dart';

import '../../domain/load_mode.dart';
import '../../domain/weight.dart';
import 'sync_columns.dart';
import 'users.dart';

class Exercises extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Unidad que la app propone al registrar una serie de este ejercicio.
  TextColumn get defaultUnit => textEnum<WeightUnit>()();

  /// Id del catálogo de ejercicios (Fase 4). Nulo mientras no exista catálogo.
  TextColumn get catalogId => text().nullable()();

  /// Qué significa el peso anotado: total, por mancuerna, por lado o lastre
  /// (ADR-0022). Nulo mientras el usuario no lo confirme; entonces se deduce
  /// del catálogo.
  TextColumn get loadMode => textEnum<LoadMode>().nullable()();
}
