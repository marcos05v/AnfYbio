// Las restricciones check() de drift se escriben nombrando la propia columna;
// el analizador lo confunde con recursión, pero drift no ejecuta ese getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import '../../domain/nutrition.dart';
import 'sync_columns.dart';
import 'users.dart';

/// Un plan de alimentación tal como lo entrega la nutrióloga.
///
/// Se conservan los planes anteriores; solo uno está activo a la vez (lo
/// garantiza el repositorio).
class NutritionPlans extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Nombre del archivo del que se importó; nulo si se capturó a mano.
  TextColumn get sourceFileName => text().nullable()();

  /// Indicaciones generales de pesaje, tal como vienen en el plan.
  TextColumn get weighingNotes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// El menú de un tipo de día (entrenamiento o descanso) dentro de un plan.
@DataClassName('PlanMenu')
@TableIndex(name: 'plan_menus_plan', columns: {#planId})
class PlanMenus extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get planId => text().references(NutritionPlans, #id)();
  TextColumn get dayType => textEnum<DayType>()();
  TextColumn get title => text().withLength(min: 1, max: 150)();
}

/// Un tiempo de comida dentro de un menú: desayuno, pre-entreno, cena…
@TableIndex(name: 'plan_meals_menu', columns: {#menuId})
class PlanMeals extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get menuId => text().references(PlanMenus, #id)();
  IntColumn get position => integer().check(position.isBiggerThanValue(0))();
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Indicación de horario: "30 min – 1 hora antes de entrenar".
  TextColumn get timingNote => text().nullable()();
}

/// Un alimento de una comida, con su cantidad.
@TableIndex(name: 'plan_items_meal', columns: {#mealId})
class PlanItems extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get mealId => text().references(PlanMeals, #id)();
  IntColumn get position => integer().check(position.isBiggerThanValue(0))();

  /// Como lo escribe el plan, alternativas incluidas ("Pollo o res magra").
  TextColumn get name => text().withLength(min: 1, max: 200)();
  RealColumn get amount =>
      real().nullable().check(amount.isBiggerThanValue(0))();
  TextColumn get unit => textEnum<FoodUnit>().nullable()();
  TextColumn get state => textEnum<FoodState>()();

  /// Consumo libre: no lleva cantidad.
  BoolColumn get isFree => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
}

/// Un suplemento de la guía que acompaña al plan. Es texto de consulta; el
/// inventario y los recordatorios llegan en la Fase 3.
@TableIndex(name: 'supplement_guidelines_plan', columns: {#planId})
class SupplementGuidelines extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get planId => text().references(NutritionPlans, #id)();
  IntColumn get position => integer().check(position.isBiggerThanValue(0))();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get dose => text().nullable()();
  TextColumn get timing => text().nullable()();
  TextColumn get benefit => text().nullable()();
}
