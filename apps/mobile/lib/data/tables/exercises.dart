import 'package:drift/drift.dart';

import 'sync_columns.dart';
import 'users.dart';

/// Unidad en la que se captura el peso. Se guarda como texto: 'kg' o 'lb'.
enum WeightUnit { kg, lb }

class Exercises extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Unidad que la app propone al registrar una serie de este ejercicio.
  TextColumn get defaultUnit => textEnum<WeightUnit>()();

  /// Id del catálogo de ejercicios (Fase 4). Nulo mientras no exista catálogo.
  TextColumn get catalogId => text().nullable()();
}
