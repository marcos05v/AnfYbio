import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/appearance.dart';
import '../app/plan_import.dart';
import '../app/providers.dart';
import '../data/database.dart';
import '../data/repositories/nutrition_repository.dart';
import '../data/repositories/routine_repository.dart';
import '../domain/cooking.dart';
import '../domain/nutrition.dart';
import '../domain/routine.dart';
import '../import/nutrition_plan_parser.dart';
import 'batches_screen.dart';
import 'formatting.dart';
import 'plan_item_form.dart';
import 'plan_review_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Pestaña de alimentación: el plan activo, mostrando el menú que toca hoy.
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key, required this.user});

  final User user;

  Future<void> _createPlan(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: 'Mi plan');
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Nuevo plan'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            key: const Key('planName'),
            controller: controller,
            placeholder: 'Nombre del plan',
            autofocus: true,
            maxLength: 100,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(context).pop(name);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    await ref
        .read(nutritionRepositoryProvider)
        .createEmptyPlan(user.id, name: name);
  }

  /// Elige un PDF, lo interpreta y abre la revisión antes de guardar nada.
  Future<void> _importPdf(BuildContext context, WidgetRef ref) async {
    Future<void> explain(String title, String message) {
      return showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    }

    final PickedPdf? picked;
    try {
      picked = await ref.read(pdfTextPickerProvider)();
    } catch (_) {
      if (context.mounted) {
        await explain('No se pudo leer el PDF', 'Prueba con otro archivo.');
      }
      return;
    }
    if (picked == null || !context.mounted) return;

    final parsed = parseNutritionPlan(picked.text, fileName: picked.fileName);
    if (parsed.draft.items.isEmpty) {
      await explain(
        'No se encontró un plan',
        picked.text.trim().isEmpty
            ? 'El PDF no contiene texto; puede ser una imagen escaneada. '
                  'Captura el plan a mano.'
            : 'El PDF no tiene el formato esperado. Captura el plan a mano.',
      );
      return;
    }

    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PlanReviewScreen(userId: user.id, parsed: parsed),
      ),
    );
  }

  Future<void> _showPlanMenu(
    BuildContext context,
    WidgetRef ref,
    NutritionPlan plan,
  ) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(plan.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('import'),
            child: const Text('Importar otro plan (PDF)'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop('delete'),
            child: const Text('Borrar plan'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'import') return _importPdf(context, ref);
    if (action != 'delete') return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('¿Borrar el plan?'),
        content: const Text(
          'Se borrarán sus comidas, alimentos y suplementos.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(nutritionRepositoryProvider).deletePlan(plan.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(activePlanProvider(user.id));
    final view = planState.value;

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Alimentación'),
            border: null,
            trailing: view == null
                ? null
                : CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showPlanMenu(context, ref, view.plan),
                    child: const Icon(
                      CupertinoIcons.ellipsis_circle,
                      semanticLabel: 'Opciones del plan',
                    ),
                  ),
          ),
          if (view == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: planState.isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _NoPlan(
                      onImport: () => _importPdf(context, ref),
                      onCreate: () => _createPlan(context, ref),
                    ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: screenPadding),
              sliver: SliverList.list(
                children: [_PlanBody(user: user, view: view)],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoPlan extends StatelessWidget {
  const _NoPlan({required this.onImport, required this.onCreate});

  final VoidCallback onImport;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(screenPadding + 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.square_list,
            size: 44,
            color: resolveColor(context, CupertinoColors.tertiaryLabel),
          ),
          const SizedBox(height: 14),
          Text(
            'Aún no tienes un plan',
            style: textStyle(context, size: 20, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Importa el PDF de tu nutrióloga o captura el plan a mano.',
            textAlign: TextAlign.center,
            style: textStyle(
              context,
              size: 15,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Importar desde PDF',
            icon: CupertinoIcons.doc_text,
            onPressed: onImport,
          ),
          const SizedBox(height: 10),
          SecondaryButton(label: 'Crear plan a mano', onPressed: onCreate),
        ],
      ),
    );
  }
}

class _PlanBody extends ConsumerWidget {
  const _PlanBody({required this.user, required this.view});

  final User user;
  final NutritionPlanView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider(user.id)).value ?? const [];
    final now = DateTime.now();
    final hasSessionToday = sessions.any((session) {
      final start = session.startedAt.toLocal();
      return start.year == now.year &&
          start.month == now.month &&
          start.day == now.day;
    });
    // Solo los tipos de día que trae este plan, en su orden.
    final planDayTypes = [
      for (final type in DayType.values)
        if (view.menuFor(type) != null) type,
    ];
    // Si el plan dice en qué días de la rutina va cada menú ("días altos:
    // 2, 3 y 5"), manda el día de la rutina que toca hoy.
    final routine = ref.watch(activeRoutineProvider(user.id)).value;
    final routineIndex = routine == null || routine.days.isEmpty
        ? null
        : routineDayIndexFor(
            date: now,
            dayCount: routine.days.length,
            dayOneWeekday: ref.watch(routineDayOneProvider),
          );
    final byRoutine = dayTypeForRoutineDay(
      routineIndex == null ? null : routineIndex + 1,
      {
        for (final menu in view.menus)
          menu.menu.dayType: decodeRoutineDays(menu.menu.routineDays),
      },
    );
    final bySession = canDetectDayType(planDayTypes);
    final canDetect = byRoutine != null || bySession;
    final detected =
        byRoutine ??
        (bySession
            ? dayTypeFor(hasSessionToday: hasSessionToday)
            : planDayTypes.firstOrNull ?? DayType.training);
    // Lo elegido a mano solo cuenta si difiere de lo que la app detecta: si
    // coincide (por ejemplo, se eligió antes de indicar los días de la
    // rutina), es lo mismo que automático.
    final saved = ref.watch(dayTypeOverrideProvider);
    final override =
        planDayTypes.contains(saved) && !(canDetect && saved == detected)
        ? saved
        : null;
    final routineLine = byRoutine == null
        ? null
        : 'Hoy toca el Día ${routineIndex! + 1} de tu rutina '
              '(${routine!.days[routineIndex].day.name}): '
              '${dayTypeLabel(byRoutine).toLowerCase()}.';
    final hasRoutineDays = view.menus.any(
      (m) => decodeRoutineDays(m.menu.routineDays).isNotEmpty,
    );
    final dayType = override ?? detected;
    final menu = view.menuFor(dayType);
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );
    final repository = ref.read(nutritionRepositoryProvider);
    final batches =
        ref.watch(cookingBatchesProvider(user.id)).value ?? const [];
    final batchInfo = <BatchInfo>[
      for (final batch in batches)
        (
          foodName: batch.foodName,
          rawG: batch.rawWeightG,
          cookedG: batch.cookedWeightG,
          withOtherIngredients: batch.withOtherIngredients,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            view.plan.name,
            style: textStyle(context, color: CupertinoColors.secondaryLabel),
          ),
        ),
        // Con un solo menú no hay nada que elegir.
        if (planDayTypes.length >= 2) ...[
          CupertinoSlidingSegmentedControl<DayType>(
            groupValue: dayType,
            padding: const EdgeInsets.all(4),
            children: {
              for (final type in planDayTypes)
                type: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    dayTypeLabel(type),
                    style: textStyle(context, size: 15),
                  ),
                ),
            },
            onValueChanged: (selected) {
              if (selected == null) return;
              // Elegir lo mismo que se detecta equivale a volver a automático.
              // Sin detección (días altos y bajos), se recuerda siempre.
              ref
                  .read(dayTypeOverrideProvider.notifier)
                  .select(canDetect && selected == detected ? null : selected);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              key: const Key('dayTypeStatus'),
              override != null && routineLine != null
                  ? '$routineLine Elegiste otro menú para hoy; toca '
                        '«${dayTypeLabel(detected)}» para volver.'
                  : override != null
                  ? 'Elegido por ti para hoy.'
                  : routineLine ??
                        (!canDetect
                            ? 'Toca el menú que te toca hoy; la app lo recuerda hasta '
                                  'mañana.'
                            : hasSessionToday
                            ? 'Hoy registraste una sesión: toca el menú de entrenamiento.'
                            : 'Hoy no has registrado sesiones: toca el menú de descanso.'),
              style: secondary,
            ),
          ),
          if (routine != null && routine.days.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: CupertinoButton(
                key: const Key('menuRoutineDays'),
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                minimumSize: Size.zero,
                onPressed: () => showAppSheet<void>(
                  context,
                  title: 'Menú de cada día de la rutina',
                  builder: (_) => _MenuDaysForm(
                    routine: routine,
                    menus: [for (final m in view.menus) m.menu],
                    onSave: repository.setMenuRoutineDays,
                  ),
                ),
                child: Text(
                  hasRoutineDays
                      ? 'Cambiar el menú de cada día de la rutina'
                      : 'Elegir el menú de cada día de la rutina',
                  style: textStyle(context, size: 14, color: accentColor),
                ),
              ),
            ),
        ],
        if (view.plan.weighingNotes case final notes?) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: resolveColor(context, cardColor),
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            child: Text(notes, style: secondary.copyWith(fontSize: 14)),
          ),
        ],
        const SizedBox(height: 14),
        CardGroup(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => BatchesScreen(user: user),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: resolveColor(
                        context,
                        accentColor,
                      ).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CupertinoIcons.flame_fill,
                      size: 20,
                      color: resolveColor(context, accentColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lotes de cocción',
                          style: textStyle(context, weight: FontWeight.w600),
                        ),
                        Text(
                          batches.isEmpty
                              ? 'Pesa lo que cocinas y sabrás cuánto servir'
                              : batches.length == 1
                              ? '1 lote registrado'
                              : '${batches.length} lotes registrados',
                          style: secondary,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: resolveColor(context, CupertinoColors.tertiaryLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (menu != null) ...[
          for (final (index, meal) in menu.meals.indexed)
            _MealSection(number: index + 1, meal: meal, batches: batchInfo),
          const SizedBox(height: 20),
          OutlineAddButton(
            label: 'Agregar comida',
            onPressed: () => showAppSheet<void>(
              context,
              title: 'Nueva comida',
              builder: (_) => _MealForm(
                onSave: (name, timing) => repository.addMeal(
                  menu.menu.id,
                  name: name,
                  timingNote: timing,
                ),
              ),
            ),
          ),
        ],
        SectionHeader(
          'Suplementos',
          trailing: _HeaderButton(
            label: 'Suplemento',
            onPressed: () => showAppSheet<void>(
              context,
              title: 'Nuevo suplemento',
              builder: (_) => _SupplementForm(
                onSave: (draft) =>
                    repository.addSupplement(view.plan.id, draft),
              ),
            ),
          ),
        ),
        if (view.supplements.isEmpty)
          const _EmptyCard('Sin suplementos.')
        else
          CardGroup(
            children: [
              for (final supplement in view.supplements)
                _SupplementRow(supplement: supplement),
            ],
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// Botón pequeño "+ algo" para el encabezado de una sección.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 32),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.plus_circle_fill, size: 20),
          const SizedBox(width: 5),
          Text(label),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: resolveColor(context, cardColor),
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Text(
        text,
        style: textStyle(context, color: CupertinoColors.secondaryLabel),
      ),
    );
  }
}

class _MealSection extends ConsumerWidget {
  const _MealSection({
    required this.number,
    required this.meal,
    required this.batches,
  });

  /// Lotes de cocción, del más reciente al más antiguo.
  final List<BatchInfo> batches;

  final int number;
  final MealView meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(nutritionRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                // El título de la comida se toca para renombrarla o borrarla.
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  alignment: Alignment.centerLeft,
                  onPressed: () => showAppSheet<void>(
                    context,
                    title: 'Editar comida',
                    builder: (_) => _MealForm(
                      editing: meal.meal,
                      onSave: (name, timing) => repository.updateMeal(
                        meal.meal.id,
                        name: name,
                        timingNote: timing,
                      ),
                      onDelete: () => repository.deleteMeal(meal.meal.id),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$number. ${meal.meal.name}',
                        style: textStyle(
                          context,
                          size: 20,
                          weight: FontWeight.w600,
                        ),
                      ),
                      if (meal.meal.timingNote case final timing?)
                        Text(
                          timing,
                          style: textStyle(
                            context,
                            size: 13,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _HeaderButton(
                label: 'Alimento',
                onPressed: () => showAppSheet<void>(
                  context,
                  title: 'Nuevo alimento',
                  builder: (_) => PlanItemForm(
                    onSave: (draft) => repository.addItem(meal.meal.id, draft),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (meal.items.isEmpty)
          const _EmptyCard('Sin alimentos.')
        else
          CardGroup(children: _rows(meal.entries, depth: 0)),
      ],
    );
  }

  /// Cada alimento, sus alternativas ("o …") y, si es un plato, sus
  /// ingredientes con sangría (ADR-0023).
  List<Widget> _rows(List<ItemNode> nodes, {required int depth}) {
    Widget row(PlanItem item, {bool alternative = false, bool dish = false}) =>
        _ItemRow(
          item: item,
          depth: depth,
          isAlternative: alternative,
          isDish: dish,
          serving: cookedServingFor(
            itemName: item.name,
            amount: item.amount,
            unit: item.unit,
            state: item.state,
            batches: batches,
          ),
        );
    return [
      for (final node in nodes) ...[
        row(node.item, dish: node.ingredients.isNotEmpty),
        for (final alternative in node.alternatives)
          row(alternative, alternative: true),
        ..._rows(node.ingredients, depth: depth + 1),
      ],
    ];
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({
    required this.item,
    required this.serving,
    this.depth = 0,
    this.isAlternative = false,
    this.isDish = false,
  });

  final PlanItem item;

  /// 0 si va suelto en la comida; 1 si es ingrediente de un plato.
  final int depth;

  /// Es otra opción del alimento de arriba: se lee "o 80 g de panela".
  final bool isAlternative;

  /// Es un plato: lo que lleva va debajo.
  final bool isDish;

  /// Cuánto servir ya cocido, si hay un lote de este alimento.
  final CookedServing? serving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(nutritionRepositoryProvider);
    final amount = formatFoodAmount(
      amount: item.amount,
      unit: item.unit,
      isFree: item.isFree,
    );
    final details = [
      if (item.state != FoodState.unspecified) foodStateLabel(item.state),
      ?item.note,
    ].join(' · ');

    return CupertinoButton(
      padding: EdgeInsets.fromLTRB(
        16 + depth * 18.0,
        isAlternative ? 4 : 12,
        16,
        12,
      ),
      onPressed: () => showAppSheet<void>(
        context,
        title: 'Editar alimento',
        builder: (_) => PlanItemForm(
          initial: ItemDraft(
            name: item.name,
            amount: item.amount,
            unit: item.unit,
            state: item.state,
            isFree: item.isFree,
            note: item.note,
          ),
          onSave: (draft) => repository.updateItem(item.id, draft),
          onDelete: () => repository.deleteItem(item.id),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      if (isAlternative)
                        TextSpan(
                          text: 'o ',
                          style: textStyle(
                            context,
                            weight: FontWeight.w600,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      TextSpan(text: item.name),
                    ],
                  ),
                  style: textStyle(
                    context,
                    weight: isDish ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: textStyle(
                      context,
                      size: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                if (serving case final serving?)
                  Text(
                    serving.isApproximate
                        ? 'Sirve aprox. ${formatNumber(serving.cookedG, decimals: 0)} g cocido'
                        : 'Sirve ${formatNumber(serving.cookedG, decimals: 0)} g cocido',
                    style: textStyle(
                      context,
                      size: 13,
                      weight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: textStyle(
              context,
              weight: FontWeight.w600,
              color: item.isFree
                  ? CupertinoColors.secondaryLabel
                  : CupertinoColors.label,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplementRow extends ConsumerWidget {
  const _SupplementRow({required this.supplement});

  final SupplementGuideline supplement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(nutritionRepositoryProvider);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => showAppSheet<void>(
        context,
        title: 'Editar suplemento',
        builder: (_) => _SupplementForm(
          editing: supplement,
          onSave: (draft) => repository.updateSupplement(supplement.id, draft),
          onDelete: () => repository.deleteSupplement(supplement.id),
        ),
      ),
      child: SupplementTile(
        name: supplement.name,
        dose: supplement.dose,
        timing: supplement.timing,
      ),
    );
  }
}

// ------------------------------------------------------------- formularios

class _MealForm extends StatefulWidget {
  const _MealForm({required this.onSave, this.editing, this.onDelete});

  final PlanMeal? editing;
  final Future<void> Function(String name, String? timingNote) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<_MealForm> createState() => _MealFormState();
}

class _MealFormState extends State<_MealForm> {
  late final _name = TextEditingController(text: widget.editing?.name);
  late final _timing = TextEditingController(text: widget.editing?.timingNote);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _timing.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el nombre de la comida.');
      return;
    }
    final navigator = Navigator.of(context);
    await widget.onSave(_name.text, _timing.text);
    navigator.pop();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    await widget.onDelete!();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardTextField(
          key: const Key('mealName'),
          controller: _name,
          placeholder: 'Nombre (Desayuno, Cena…)',
          autofocus: widget.editing == null,
        ),
        const SizedBox(height: 12),
        CardTextField(
          key: const Key('mealTiming'),
          controller: _timing,
          placeholder: 'Horario o indicación (opcional)',
        ),
        if (_error != null) FormError(_error!),
        FormActions(
          saveLabel: widget.editing == null
              ? 'Guardar comida'
              : 'Guardar cambios',
          onSave: _save,
          deleteLabel: 'Borrar comida',
          onDelete: widget.onDelete == null ? null : _delete,
        ),
      ],
    );
  }
}

class _SupplementForm extends StatefulWidget {
  const _SupplementForm({required this.onSave, this.editing, this.onDelete});

  final SupplementGuideline? editing;
  final Future<void> Function(SupplementDraft draft) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<_SupplementForm> createState() => _SupplementFormState();
}

class _SupplementFormState extends State<_SupplementForm> {
  late final _name = TextEditingController(text: widget.editing?.name);
  late final _dose = TextEditingController(text: widget.editing?.dose);
  late final _timing = TextEditingController(text: widget.editing?.timing);
  late final _benefit = TextEditingController(text: widget.editing?.benefit);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _timing.dispose();
    _benefit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el nombre del suplemento.');
      return;
    }
    final navigator = Navigator.of(context);
    await widget.onSave(
      SupplementDraft(
        name: _name.text,
        dose: _dose.text,
        timing: _timing.text,
        benefit: _benefit.text,
      ),
    );
    navigator.pop();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    await widget.onDelete!();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardTextField(
          key: const Key('supplementName'),
          controller: _name,
          placeholder: 'Suplemento',
          autofocus: widget.editing == null,
        ),
        const SizedBox(height: 12),
        CardTextField(
          key: const Key('supplementDose'),
          controller: _dose,
          placeholder: 'Dosis (5 g al día)',
        ),
        const SizedBox(height: 12),
        CardTextField(
          key: const Key('supplementTiming'),
          controller: _timing,
          placeholder: 'Momento de toma',
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        CardTextField(
          key: const Key('supplementBenefit'),
          controller: _benefit,
          placeholder: 'Beneficio (opcional)',
          maxLines: 3,
        ),
        if (_error != null) FormError(_error!),
        FormActions(
          saveLabel: widget.editing == null
              ? 'Guardar suplemento'
              : 'Guardar cambios',
          onSave: _save,
          deleteLabel: 'Borrar suplemento',
          onDelete: widget.onDelete == null ? null : _delete,
        ),
      ],
    );
  }
}

/// Para cada día de la rutina, qué menú del plan toca. Sirve para planes
/// que no traen los números de día ("Días de Tren Inferior") o que se
/// guardaron antes de leerlos.
class _MenuDaysForm extends StatefulWidget {
  const _MenuDaysForm({
    required this.routine,
    required this.menus,
    required this.onSave,
  });

  final RoutineView routine;
  final List<PlanMenu> menus;
  final Future<void> Function(Map<String, List<int>> daysByMenu) onSave;

  @override
  State<_MenuDaysForm> createState() => _MenuDaysFormState();
}

class _MenuDaysFormState extends State<_MenuDaysForm> {
  /// Día de la rutina (desde 1) → id del menú; sin entrada, ninguno.
  late final Map<int, String> _menuOfDay = {
    for (final menu in widget.menus)
      for (final day in decodeRoutineDays(menu.routineDays)) day: menu.id,
  };

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await widget.onSave({
      for (final menu in widget.menus)
        menu.id: [
          for (final MapEntry(key: day, value: menuId) in _menuOfDay.entries)
            if (menuId == menu.id) day,
        ],
    });
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: CardGroup(
              children: [
                for (final (index, day) in widget.routine.days.indexed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Día ${index + 1} · ${day.day.name}',
                          style: textStyle(context, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        CupertinoSlidingSegmentedControl<String>(
                          key: Key('menuOfDay${index + 1}'),
                          groupValue: _menuOfDay[index + 1],
                          onValueChanged: (menuId) => setState(() {
                            // Tocar el que ya estaba elegido lo quita.
                            if (menuId == null ||
                                _menuOfDay[index + 1] == menuId) {
                              _menuOfDay.remove(index + 1);
                            } else {
                              _menuOfDay[index + 1] = menuId;
                            }
                          }),
                          children: {
                            for (final menu in widget.menus)
                              menu.id: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(dayTypeLabel(menu.dayType)),
                              ),
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        FormActions(saveLabel: 'Guardar', onSave: _save),
      ],
    );
  }
}
