import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
// Lo usa el código generado (database.g.dart) para crear los UUID.
import 'package:uuid/uuid.dart';

import '../domain/nutrition.dart';
import '../domain/weight.dart';
import 'tables/apnea_attempts.dart';
import 'tables/cooking_batches.dart';
import 'tables/exercises.dart';
import 'tables/nutrition.dart';
import 'tables/routines.dart';
import 'tables/run_details.dart';
import 'tables/sessions.dart';
import 'tables/strength_sets.dart';
import 'tables/supplements.dart';
import 'tables/swim.dart';
import 'tables/users.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Exercises,
    Sessions,
    StrengthSets,
    SwimDetails,
    SwimIntervals,
    SwimLaps,
    RunDetails,
    ApneaAttempts,
    NutritionPlans,
    PlanMenus,
    PlanMeals,
    PlanItems,
    SupplementGuidelines,
    Routines,
    RoutineDays,
    RoutineExercises,
    CookingBatches,
    Supplements,
    SupplementPurchases,
    SupplementIntakes,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// En pruebas se pasa una base en memoria; en la app se usa el archivo real.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'anfybio'));

  /// 1: entrenamiento (Fase 1).
  /// 2: plan de alimentación y guía de suplementos (Fase 2).
  /// 3: rutina de entrenamiento, y qué día de ella siguió cada sesión.
  /// 4: lotes de cocción.
  /// 5: inventario de suplementos (Fase 3).
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // Cada paso lleva la base de una versión a la siguiente; una app que
      // se quedó varias versiones atrás los recorre todos en orden.
      if (from < 2) {
        await m.createTable(nutritionPlans);
        await m.createTable(planMenus);
        await m.createTable(planMeals);
        await m.createTable(planItems);
        await m.createTable(supplementGuidelines);
        await m.createIndex(planMenusPlan);
        await m.createIndex(planMealsMenu);
        await m.createIndex(planItemsMeal);
        await m.createIndex(supplementGuidelinesPlan);
      }
      if (from < 3) {
        await m.createTable(routines);
        await m.createTable(routineDays);
        await m.createTable(routineExercises);
        await m.createIndex(routineDaysRoutine);
        await m.createIndex(routineExercisesDay);
        await m.addColumn(sessions, sessions.routineDayId);
      }
      if (from < 4) {
        await m.createTable(cookingBatches);
        await m.createIndex(cookingBatchesUser);
      }
      if (from < 5) {
        await m.createTable(supplements);
        await m.createTable(supplementPurchases);
        await m.createTable(supplementIntakes);
        await m.createIndex(supplementPurchasesSupplement);
        await m.createIndex(supplementIntakesSupplement);
      }
    },
    beforeOpen: (details) async {
      // SQLite no valida las llaves foráneas a menos que se active en cada
      // conexión. Sin esto, un ejercicio podría apuntar a un usuario inexistente.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
