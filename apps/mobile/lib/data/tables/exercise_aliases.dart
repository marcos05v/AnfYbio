import 'package:drift/drift.dart';

import 'sync_columns.dart';
import 'users.dart';

/// Un nombre en español que el usuario ya enlazó con un ejercicio del
/// catálogo: "press de banca plano con barra" → "Barbell_Bench_Press_-_...".
///
/// Se llena con las confirmaciones manuales y se consulta antes de buscar
/// por parecido, así cada nombre se confirma una sola vez (ADR-0015).
@TableIndex(name: 'exercise_aliases_user_alias', columns: {#userId, #alias})
class ExerciseAliases extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();

  /// El nombre ya normalizado (sin acentos, mayúsculas ni signos).
  TextColumn get alias => text().withLength(min: 1, max: 200)();
  TextColumn get catalogId => text().withLength(min: 1, max: 200)();
}
