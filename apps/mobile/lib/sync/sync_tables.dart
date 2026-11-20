import 'package:drift/drift.dart';

import '../data/database.dart';

/// Convierte una fila en JSON con todas las fechas en UTC e ISO 8601 con
/// microsegundos, que es lo que espera el servidor (ADR-0016).
class SyncSerializer extends ValueSerializer {
  const SyncSerializer();

  static const _defaults = ValueSerializer.defaults(
    serializeDateTimeValuesAsString: true,
  );

  @override
  T fromJson<T>(dynamic json) => _defaults.fromJson<T>(json);

  @override
  dynamic toJson<T>(T value) => value is DateTime
      ? value.toUtc().toIso8601String()
      : _defaults.toJson(value);
}

const syncSerializer = SyncSerializer();

typedef RowFromJson<D> = D Function(
  Map<String, dynamic> json, {
  ValueSerializer? serializer,
});

/// Una tabla de la app que se sincroniza, con lo necesario para leer sus
/// cambios y aplicar los que llegan del servidor sin escribir código por
/// cada tabla.
class SyncTable<T extends Table, D extends DataClass> {
  const SyncTable(this.name, this.table, this.fromJson);

  /// Nombre en el servidor: el mismo del respaldo JSON (ADR-0005).
  final String name;
  final TableInfo<T, D> table;
  final RowFromJson<D> fromJson;

  GeneratedColumn<String> get _id =>
      table.columnsByName['id']! as GeneratedColumn<String>;

  /// La columna del dueño. En `users`, la fila es el usuario mismo.
  GeneratedColumn<String> get _owner =>
      table.columnsByName[name == 'users' ? 'id' : 'user_id']!
          as GeneratedColumn<String>;

  GeneratedColumn<DateTime> get _updatedAt =>
      table.columnsByName['updated_at']! as GeneratedColumn<DateTime>;

  /// Las filas de [userId] que cambiaron después de [since] (todas si es
  /// `null`), listas para subir.
  Future<List<Map<String, dynamic>>> changedSince(
    AppDatabase db,
    String userId,
    DateTime? since,
  ) async {
    final query = db.select(table)
      ..where(
        (_) => since == null
            ? _owner.equals(userId)
            : _owner.equals(userId) & _updatedAt.isBiggerThanValue(since),
      );
    return [
      for (final row in await query.get())
        row.toJson(serializer: syncSerializer),
    ];
  }

  /// Guarda una fila que llegó del servidor si es nueva o más reciente que
  /// la local; si la local es igual o más nueva, no hace nada. Devuelve si
  /// la guardó.
  Future<bool> apply(AppDatabase db, Map<String, dynamic> json) async {
    final incoming = fromJson(json, serializer: syncSerializer);
    final local = await (db.select(
      table,
    )..where((_) => _id.equals(json['id'] as String))).getSingleOrNull();
    if (local != null) {
      final localUpdated = DateTime.parse(
        local.toJson(serializer: syncSerializer)['updatedAt'] as String,
      );
      final incomingUpdated = DateTime.parse(json['updatedAt'] as String);
      if (!incomingUpdated.isAfter(localUpdated)) return false;
    }
    await db.into(table).insertOnConflictUpdate(incoming as Insertable<D>);
    return true;
  }
}

/// Todas las tablas que se sincronizan, en orden de dependencias: cada una
/// va después de aquellas a las que apunta con una llave foránea (el mismo
/// orden que la restauración del respaldo).
List<SyncTable> syncTablesOf(AppDatabase db) => [
  SyncTable('users', db.users, User.fromJson),
  SyncTable('exercises', db.exercises, Exercise.fromJson),
  SyncTable('routines', db.routines, Routine.fromJson),
  SyncTable('routineDays', db.routineDays, RoutineDay.fromJson),
  SyncTable('routineExercises', db.routineExercises, RoutineExercise.fromJson),
  SyncTable('sessions', db.sessions, Session.fromJson),
  SyncTable('strengthSets', db.strengthSets, StrengthSet.fromJson),
  SyncTable('swimDetails', db.swimDetails, SwimDetail.fromJson),
  SyncTable('swimIntervals', db.swimIntervals, SwimInterval.fromJson),
  SyncTable('swimLaps', db.swimLaps, SwimLap.fromJson),
  SyncTable('runDetails', db.runDetails, RunDetail.fromJson),
  SyncTable('apneaAttempts', db.apneaAttempts, ApneaAttempt.fromJson),
  SyncTable('nutritionPlans', db.nutritionPlans, NutritionPlan.fromJson),
  SyncTable('planMenus', db.planMenus, PlanMenu.fromJson),
  SyncTable('planMeals', db.planMeals, PlanMeal.fromJson),
  SyncTable('planItems', db.planItems, PlanItem.fromJson),
  SyncTable(
    'supplementGuidelines',
    db.supplementGuidelines,
    SupplementGuideline.fromJson,
  ),
  SyncTable('cookingBatches', db.cookingBatches, CookingBatch.fromJson),
  SyncTable('supplements', db.supplements, Supplement.fromJson),
  SyncTable(
    'supplementPurchases',
    db.supplementPurchases,
    SupplementPurchase.fromJson,
  ),
  SyncTable('exerciseAliases', db.exerciseAliases, ExerciseAliase.fromJson),
  SyncTable(
    'supplementIntakes',
    db.supplementIntakes,
    SupplementIntake.fromJson,
  ),
];
