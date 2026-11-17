import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/appearance.dart';
import '../app/providers.dart';
import '../data/database.dart';
import '../data/repositories/nutrition_repository.dart';
import '../domain/nutrition.dart';
import 'formatting.dart';
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

  Future<void> _showPlanMenu(
    BuildContext context,
    WidgetRef ref,
    NutritionPlan plan,
  ) async {
    final delete = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(plan.name),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar plan'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (delete != true || !context.mounted) return;

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
                  : _NoPlan(onCreate: () => _createPlan(context, ref)),
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
  const _NoPlan({required this.onCreate});

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
            'Captura el plan de tu nutrióloga: sus comidas, alimentos y '
            'suplementos.',
            textAlign: TextAlign.center,
            style: textStyle(
              context,
              size: 15,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Crear plan a mano', onPressed: onCreate),
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
    final override = ref.watch(dayTypeOverrideProvider);
    final detected = dayTypeFor(hasSessionToday: hasSessionToday);
    final dayType = dayTypeFor(
      hasSessionToday: hasSessionToday,
      override: override,
    );
    final menu = view.menuFor(dayType);
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );
    final repository = ref.read(nutritionRepositoryProvider);

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
        CupertinoSlidingSegmentedControl<DayType>(
          groupValue: dayType,
          padding: const EdgeInsets.all(4),
          children: {
            for (final type in DayType.values)
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
            ref
                .read(dayTypeOverrideProvider.notifier)
                .select(selected == detected ? null : selected);
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            override != null
                ? 'Elegido por ti para hoy.'
                : hasSessionToday
                ? 'Hoy registraste una sesión: toca el menú de entrenamiento.'
                : 'Hoy no has registrado sesiones: toca el menú de descanso.',
            style: secondary,
          ),
        ),
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
        if (menu != null) ...[
          for (final (index, meal) in menu.meals.indexed)
            _MealSection(number: index + 1, meal: meal),
          const SizedBox(height: 20),
          SecondaryButton(
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
  const _MealSection({required this.number, required this.meal});

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
                  builder: (_) => _ItemForm(
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
          CardGroup(
            children: [for (final item in meal.items) _ItemRow(item: item)],
          ),
      ],
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item});

  final PlanItem item;

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: () => showAppSheet<void>(
        context,
        title: 'Editar alimento',
        builder: (_) => _ItemForm(
          editing: item,
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
                Text(item.name, style: textStyle(context)),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: textStyle(
                      context,
                      size: 13,
                      color: CupertinoColors.secondaryLabel,
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
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: () => showAppSheet<void>(
        context,
        title: 'Editar suplemento',
        builder: (_) => _SupplementForm(
          editing: supplement,
          onSave: (draft) => repository.updateSupplement(supplement.id, draft),
          onDelete: () => repository.deleteSupplement(supplement.id),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        supplement.name,
                        style: textStyle(context, weight: FontWeight.w600),
                      ),
                    ),
                    if (supplement.dose case final dose?)
                      Text(
                        dose,
                        style: textStyle(context, weight: FontWeight.w600),
                      ),
                  ],
                ),
                if (supplement.timing case final timing?)
                  Text(timing, style: secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- formularios

/// Botones comunes al pie de un formulario: guardar y, al editar, borrar.
class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.isEditing,
    required this.saveLabel,
    required this.deleteLabel,
    required this.onSave,
    required this.onDelete,
  });

  final bool isEditing;
  final String saveLabel;
  final String deleteLabel;
  final VoidCallback onSave;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        PrimaryButton(
          label: isEditing ? 'Guardar cambios' : saveLabel,
          onPressed: onSave,
        ),
        if (onDelete != null)
          DeleteButton(
            label: deleteLabel,
            onConfirmed: () async {
              final navigator = Navigator.of(context);
              await onDelete!();
              navigator.pop();
            },
          ),
      ],
    );
  }
}

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
        _FormActions(
          isEditing: widget.editing != null,
          saveLabel: 'Guardar comida',
          deleteLabel: 'Borrar comida',
          onSave: _save,
          onDelete: widget.onDelete,
        ),
      ],
    );
  }
}

class _ItemForm extends StatefulWidget {
  const _ItemForm({required this.onSave, this.editing, this.onDelete});

  final PlanItem? editing;
  final Future<void> Function(ItemDraft draft) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  late final _name = TextEditingController(text: widget.editing?.name);
  late final _amount = TextEditingController(
    text: widget.editing?.amount == null
        ? null
        : formatNumber(widget.editing!.amount!, decimals: 2),
  );
  late final _note = TextEditingController(text: widget.editing?.note);
  late FoodUnit _unit = widget.editing?.unit ?? FoodUnit.gram;
  late FoodState _state = widget.editing?.state ?? FoodState.unspecified;
  late bool _isFree = widget.editing?.isFree ?? false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickState() async {
    final state = await showCupertinoModalPopup<FoodState>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('¿Cómo se pesa?'),
        actions: [
          for (final state in FoodState.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(state),
              child: Text(foodStateLabel(state)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (state != null) setState(() => _state = state);
  }

  Future<void> _save() async {
    final amountText = _amount.text.trim();
    final amount = amountText.isEmpty ? null : parseNumber(amountText);

    String? error;
    if (_name.text.trim().isEmpty) {
      error = 'Escribe el nombre del alimento.';
    } else if (!_isFree &&
        amountText.isNotEmpty &&
        (amount == null || amount <= 0)) {
      error = 'La cantidad debe ser un número mayor que cero.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final navigator = Navigator.of(context);
    await widget.onSave(
      ItemDraft(
        name: _name.text,
        amount: amount,
        // Sin cantidad, la unidad no significa nada.
        unit: amount == null ? null : _unit,
        state: _state,
        isFree: _isFree,
        note: _note.text,
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardTextField(
          key: const Key('itemName'),
          controller: _name,
          placeholder: 'Alimento',
          autofocus: widget.editing == null,
        ),
        const SizedBox(height: 12),
        CardGroup(
          children: [
            FormRow(
              label: 'Consumo libre',
              child: CupertinoSwitch(
                value: _isFree,
                onChanged: (value) => setState(() => _isFree = value),
              ),
            ),
            if (!_isFree) ...[
              FormRow(
                label: 'Cantidad',
                child: RowTextField(
                  key: const Key('itemAmount'),
                  controller: _amount,
                  placeholder: 'Opcional',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              FormRow(
                label: 'Unidad',
                child: CupertinoSlidingSegmentedControl<FoodUnit>(
                  groupValue: _unit,
                  children: const {
                    FoodUnit.gram: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('g'),
                    ),
                    FoodUnit.piece: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('piezas'),
                    ),
                    FoodUnit.scoop: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('scoops'),
                    ),
                  },
                  onValueChanged: (unit) {
                    if (unit != null) setState(() => _unit = unit);
                  },
                ),
              ),
            ],
            PickerRow(
              key: const Key('itemState'),
              label: 'Se pesa',
              value: foodStateLabel(_state),
              onPressed: _pickState,
            ),
          ],
        ),
        const SizedBox(height: 12),
        CardTextField(
          key: const Key('itemNote'),
          controller: _note,
          placeholder: 'Nota (opcional)',
        ),
        if (_error != null) FormError(_error!),
        _FormActions(
          isEditing: widget.editing != null,
          saveLabel: 'Guardar alimento',
          deleteLabel: 'Borrar alimento',
          onSave: _save,
          onDelete: widget.onDelete,
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
        _FormActions(
          isEditing: widget.editing != null,
          saveLabel: 'Guardar suplemento',
          deleteLabel: 'Borrar suplemento',
          onSave: _save,
          onDelete: widget.onDelete,
        ),
      ],
    );
  }
}
