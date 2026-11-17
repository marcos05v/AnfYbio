import 'dart:async';

import 'package:drift/drift.dart';

import '../../domain/nutrition.dart';
import '../database.dart';
import 'training_repository.dart' show RecordNotFound;

/// El plan activo completo, listo para mostrarse.
class NutritionPlanView {
  const NutritionPlanView({
    required this.plan,
    required this.menus,
    required this.supplements,
  });

  final NutritionPlan plan;
  final List<MenuView> menus;
  final List<SupplementGuideline> supplements;

  MenuView? menuFor(DayType dayType) =>
      menus.where((m) => m.menu.dayType == dayType).firstOrNull;
}

class MenuView {
  const MenuView({required this.menu, required this.meals});

  final PlanMenu menu;
  final List<MealView> meals;
}

class MealView {
  const MealView({required this.meal, required this.items});

  final PlanMeal meal;
  final List<PlanItem> items;
}

/// Lectura y escritura del plan de alimentación.
///
/// Reglas que garantiza:
/// - un usuario tiene a lo sumo un plan activo; guardar uno nuevo desactiva
///   el anterior, que se conserva;
/// - el borrado es lógico y en cascada (plan → menús → comidas → alimentos);
/// - los hijos heredan el usuario de su padre;
/// - toda modificación actualiza `updatedAt`.
class NutritionRepository {
  NutritionRepository(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _now;

  // -------------------------------------------------------------------- plan

  /// Guarda un plan completo (capturado o importado) y lo deja como activo.
  /// Todo ocurre en una transacción: o se guarda entero o no se guarda nada.
  Future<String> savePlan(String userId, NutritionPlanDraft draft) {
    return _db.transaction(() async {
      await (_db.update(_db.nutritionPlans)..where(
            (p) =>
                p.userId.equals(userId) &
                p.isActive.equals(true) &
                p.deletedAt.isNull(),
          ))
          .write(
            NutritionPlansCompanion(
              isActive: const Value(false),
              updatedAt: Value(_now()),
            ),
          );

      final plan = await _db
          .into(_db.nutritionPlans)
          .insertReturning(
            NutritionPlansCompanion.insert(
              userId: userId,
              name: draft.name.trim(),
              sourceFileName: Value(draft.sourceFileName),
              weighingNotes: Value(_clean(draft.weighingNotes)),
            ),
          );

      for (final menuDraft in draft.menus) {
        final menu = await _db
            .into(_db.planMenus)
            .insertReturning(
              PlanMenusCompanion.insert(
                userId: userId,
                planId: plan.id,
                dayType: menuDraft.dayType,
                title: menuDraft.title.trim(),
              ),
            );
        for (final (mealIndex, mealDraft) in menuDraft.meals.indexed) {
          final meal = await _db
              .into(_db.planMeals)
              .insertReturning(
                PlanMealsCompanion.insert(
                  userId: userId,
                  menuId: menu.id,
                  position: mealIndex + 1,
                  name: mealDraft.name.trim(),
                  timingNote: Value(_clean(mealDraft.timingNote)),
                ),
              );
          for (final (itemIndex, item) in mealDraft.items.indexed) {
            await _db
                .into(_db.planItems)
                .insert(_itemCompanion(userId, meal.id, itemIndex + 1, item));
          }
        }
      }
      for (final (index, supplement) in draft.supplements.indexed) {
        await _db
            .into(_db.supplementGuidelines)
            .insert(
              _supplementCompanion(userId, plan.id, index + 1, supplement),
            );
      }
      return plan.id;
    });
  }

  /// Crea un plan vacío con sus dos menús, para capturarlo a mano.
  Future<String> createEmptyPlan(String userId, {required String name}) {
    return savePlan(
      userId,
      NutritionPlanDraft(
        name: name,
        menus: const [
          MenuDraft(dayType: DayType.training, title: 'Días de entrenamiento'),
          MenuDraft(dayType: DayType.rest, title: 'Días de descanso'),
        ],
      ),
    );
  }

  /// Borra el plan y todo su contenido (borrado lógico). No reactiva ningún
  /// plan anterior.
  Future<void> deletePlan(String planId) {
    return _db.transaction(() async {
      final now = Value(_now());
      final deleted =
          await (_db.update(
            _db.nutritionPlans,
          )..where((p) => p.id.equals(planId) & p.deletedAt.isNull())).write(
            NutritionPlansCompanion(
              deletedAt: now,
              updatedAt: now,
              isActive: const Value(false),
            ),
          );
      if (deleted == 0) throw RecordNotFound(planId);

      final menuIds = _db.selectOnly(_db.planMenus)
        ..addColumns([_db.planMenus.id])
        ..where(_db.planMenus.planId.equals(planId));
      final mealIds = _db.selectOnly(_db.planMeals)
        ..addColumns([_db.planMeals.id])
        ..where(_db.planMeals.menuId.isInQuery(menuIds));

      await (_db.update(_db.planItems)
            ..where((i) => i.mealId.isInQuery(mealIds) & i.deletedAt.isNull()))
          .write(PlanItemsCompanion(deletedAt: now, updatedAt: now));
      await (_db.update(_db.planMeals)
            ..where((m) => m.menuId.isInQuery(menuIds) & m.deletedAt.isNull()))
          .write(PlanMealsCompanion(deletedAt: now, updatedAt: now));
      await (_db.update(_db.planMenus)
            ..where((m) => m.planId.equals(planId) & m.deletedAt.isNull()))
          .write(PlanMenusCompanion(deletedAt: now, updatedAt: now));
      await (_db.update(_db.supplementGuidelines)
            ..where((s) => s.planId.equals(planId) & s.deletedAt.isNull()))
          .write(SupplementGuidelinesCompanion(deletedAt: now, updatedAt: now));
    });
  }

  /// El plan activo del usuario con todo su contenido; `null` si no tiene.
  Future<NutritionPlanView?> activePlan(String userId) async {
    final plan =
        await (_db.select(_db.nutritionPlans)
              ..where(
                (p) =>
                    p.userId.equals(userId) &
                    p.isActive.equals(true) &
                    p.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (plan == null) return null;

    final menus =
        await (_db.select(_db.planMenus)
              ..where((m) => m.planId.equals(plan.id) & m.deletedAt.isNull())
              ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
            .get();
    final menuIds = menus.map((m) => m.id);
    final meals =
        await (_db.select(_db.planMeals)
              ..where((m) => m.menuId.isIn(menuIds) & m.deletedAt.isNull())
              ..orderBy([(m) => OrderingTerm.asc(m.position)]))
            .get();
    final items =
        await (_db.select(_db.planItems)
              ..where(
                (i) =>
                    i.mealId.isIn(meals.map((m) => m.id)) &
                    i.deletedAt.isNull(),
              )
              ..orderBy([(i) => OrderingTerm.asc(i.position)]))
            .get();
    final supplements =
        await (_db.select(_db.supplementGuidelines)
              ..where((s) => s.planId.equals(plan.id) & s.deletedAt.isNull())
              ..orderBy([(s) => OrderingTerm.asc(s.position)]))
            .get();

    return NutritionPlanView(
      plan: plan,
      supplements: supplements,
      menus: [
        for (final menu in menus)
          MenuView(
            menu: menu,
            meals: [
              for (final meal in meals.where((m) => m.menuId == menu.id))
                MealView(
                  meal: meal,
                  items: [
                    for (final item in items)
                      if (item.mealId == meal.id) item,
                  ],
                ),
            ],
          ),
      ],
    );
  }

  /// Igual que [activePlan], pero vuelve a emitir cada vez que cambia
  /// cualquiera de las tablas del plan.
  Stream<NutritionPlanView?> watchActivePlan(String userId) {
    final changes = _db.tableUpdates(
      TableUpdateQuery.onAllTables([
        _db.nutritionPlans,
        _db.planMenus,
        _db.planMeals,
        _db.planItems,
        _db.supplementGuidelines,
      ]),
    );
    late final StreamController<NutritionPlanView?> controller;
    StreamSubscription<void>? subscription;

    Future<void> emit() async {
      final view = await activePlan(userId);
      if (!controller.isClosed) controller.add(view);
    }

    controller = StreamController<NutritionPlanView?>(
      onListen: () {
        // Primero se escuchan los cambios y luego se lee, para no perder
        // una modificación que ocurra durante la primera lectura.
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

  // ----------------------------------------------------------------- comidas

  Future<PlanMeal> addMeal(
    String menuId, {
    required String name,
    String? timingNote,
  }) {
    return _db.transaction(() async {
      final menu =
          await (_db.select(_db.planMenus)
                ..where((m) => m.id.equals(menuId) & m.deletedAt.isNull()))
              .getSingleOrNull();
      if (menu == null) throw RecordNotFound(menuId);

      return _db
          .into(_db.planMeals)
          .insertReturning(
            PlanMealsCompanion.insert(
              userId: menu.userId,
              menuId: menuId,
              position: await _nextPosition(
                _db.planMeals,
                _db.planMeals.position,
                _db.planMeals.menuId,
                menuId,
              ),
              name: name.trim(),
              timingNote: Value(_clean(timingNote)),
            ),
          );
    });
  }

  Future<void> updateMeal(
    String mealId, {
    required String name,
    required String? timingNote,
  }) async {
    final updated =
        await (_db.update(
          _db.planMeals,
        )..where((m) => m.id.equals(mealId) & m.deletedAt.isNull())).write(
          PlanMealsCompanion(
            name: Value(name.trim()),
            timingNote: Value(_clean(timingNote)),
            updatedAt: Value(_now()),
          ),
        );
    if (updated == 0) throw RecordNotFound(mealId);
  }

  /// Borra una comida junto con sus alimentos.
  Future<void> deleteMeal(String mealId) {
    return _db.transaction(() async {
      final now = Value(_now());
      final deleted =
          await (_db.update(_db.planMeals)
                ..where((m) => m.id.equals(mealId) & m.deletedAt.isNull()))
              .write(PlanMealsCompanion(deletedAt: now, updatedAt: now));
      if (deleted == 0) throw RecordNotFound(mealId);
      await (_db.update(_db.planItems)
            ..where((i) => i.mealId.equals(mealId) & i.deletedAt.isNull()))
          .write(PlanItemsCompanion(deletedAt: now, updatedAt: now));
    });
  }

  // --------------------------------------------------------------- alimentos

  Future<PlanItem> addItem(String mealId, ItemDraft item) {
    return _db.transaction(() async {
      final meal =
          await (_db.select(_db.planMeals)
                ..where((m) => m.id.equals(mealId) & m.deletedAt.isNull()))
              .getSingleOrNull();
      if (meal == null) throw RecordNotFound(mealId);

      final position = await _nextPosition(
        _db.planItems,
        _db.planItems.position,
        _db.planItems.mealId,
        mealId,
      );
      return _db
          .into(_db.planItems)
          .insertReturning(_itemCompanion(meal.userId, mealId, position, item));
    });
  }

  Future<void> updateItem(String itemId, ItemDraft item) async {
    final updated =
        await (_db.update(
          _db.planItems,
        )..where((i) => i.id.equals(itemId) & i.deletedAt.isNull())).write(
          PlanItemsCompanion(
            name: Value(item.name.trim()),
            amount: Value(item.isFree ? null : item.amount),
            unit: Value(item.isFree ? null : item.unit),
            state: Value(item.state),
            isFree: Value(item.isFree),
            note: Value(_clean(item.note)),
            updatedAt: Value(_now()),
          ),
        );
    if (updated == 0) throw RecordNotFound(itemId);
  }

  Future<void> deleteItem(String itemId) async {
    final now = Value(_now());
    final deleted =
        await (_db.update(_db.planItems)
              ..where((i) => i.id.equals(itemId) & i.deletedAt.isNull()))
            .write(PlanItemsCompanion(deletedAt: now, updatedAt: now));
    if (deleted == 0) throw RecordNotFound(itemId);
  }

  // ------------------------------------------------------------- suplementos

  Future<SupplementGuideline> addSupplement(
    String planId,
    SupplementDraft supplement,
  ) {
    return _db.transaction(() async {
      final plan =
          await (_db.select(_db.nutritionPlans)
                ..where((p) => p.id.equals(planId) & p.deletedAt.isNull()))
              .getSingleOrNull();
      if (plan == null) throw RecordNotFound(planId);

      final position = await _nextPosition(
        _db.supplementGuidelines,
        _db.supplementGuidelines.position,
        _db.supplementGuidelines.planId,
        planId,
      );
      return _db
          .into(_db.supplementGuidelines)
          .insertReturning(
            _supplementCompanion(plan.userId, planId, position, supplement),
          );
    });
  }

  Future<void> updateSupplement(
    String supplementId,
    SupplementDraft supplement,
  ) async {
    final updated =
        await (_db.update(_db.supplementGuidelines)
              ..where((s) => s.id.equals(supplementId) & s.deletedAt.isNull()))
            .write(
              SupplementGuidelinesCompanion(
                name: Value(supplement.name.trim()),
                dose: Value(_clean(supplement.dose)),
                timing: Value(_clean(supplement.timing)),
                benefit: Value(_clean(supplement.benefit)),
                updatedAt: Value(_now()),
              ),
            );
    if (updated == 0) throw RecordNotFound(supplementId);
  }

  Future<void> deleteSupplement(String supplementId) async {
    final now = Value(_now());
    final deleted =
        await (_db.update(_db.supplementGuidelines)
              ..where((s) => s.id.equals(supplementId) & s.deletedAt.isNull()))
            .write(
              SupplementGuidelinesCompanion(deletedAt: now, updatedAt: now),
            );
    if (deleted == 0) throw RecordNotFound(supplementId);
  }

  // ---------------------------------------------------------------- internos

  PlanItemsCompanion _itemCompanion(
    String userId,
    String mealId,
    int position,
    ItemDraft item,
  ) {
    return PlanItemsCompanion.insert(
      userId: userId,
      mealId: mealId,
      position: position,
      name: item.name.trim(),
      // Un alimento libre no lleva cantidad, aunque el borrador la traiga.
      amount: Value(item.isFree ? null : item.amount),
      unit: Value(item.isFree ? null : item.unit),
      state: item.state,
      isFree: Value(item.isFree),
      note: Value(_clean(item.note)),
    );
  }

  SupplementGuidelinesCompanion _supplementCompanion(
    String userId,
    String planId,
    int position,
    SupplementDraft supplement,
  ) {
    return SupplementGuidelinesCompanion.insert(
      userId: userId,
      planId: planId,
      position: position,
      name: supplement.name.trim(),
      dose: Value(_clean(supplement.dose)),
      timing: Value(_clean(supplement.timing)),
      benefit: Value(_clean(supplement.benefit)),
    );
  }

  /// Texto opcional: vacío o solo espacios se guarda como nulo.
  String? _clean(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Siguiente posición dentro del padre; cuenta las filas borradas para no
  /// reutilizar una posición.
  Future<int> _nextPosition(
    TableInfo table,
    GeneratedColumn<int> position,
    GeneratedColumn<String> parentColumn,
    String parentId,
  ) async {
    final maxPosition = position.max();
    final query = _db.selectOnly(table)
      ..addColumns([maxPosition])
      ..where(parentColumn.equals(parentId));
    final current = await query.map((row) => row.read(maxPosition)).getSingle();
    return (current ?? 0) + 1;
  }
}
