import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/nutrition.dart';
import '../import/nutrition_plan_parser.dart';
import 'formatting.dart';
import 'plan_item_form.dart';
import 'theme.dart';
import 'widgets.dart';

/// Revisión obligatoria de un plan leído de un PDF, antes de guardarlo.
///
/// Muestra todo lo que se interpretó y resalta lo que no se entendió. Cada
/// alimento se puede corregir o quitar aquí mismo; nada llega a la base de
/// datos hasta pulsar "Guardar plan".
class PlanReviewScreen extends ConsumerStatefulWidget {
  const PlanReviewScreen({
    super.key,
    required this.userId,
    required this.parsed,
  });

  final String userId;
  final ParsedNutritionPlan parsed;

  @override
  ConsumerState<PlanReviewScreen> createState() => _PlanReviewScreenState();
}

class _PlanReviewScreenState extends ConsumerState<PlanReviewScreen> {
  late NutritionPlanDraft _draft = widget.parsed.draft;
  bool _saving = false;

  int get _pending => _draft.items.where((i) => i.warning != null).length;

  /// Sustituye (o quita, con `null`) un alimento del borrador.
  void _replaceItem(int menu, int meal, int item, ItemDraft? replacement) {
    setState(() {
      _draft = _draft.copyWith(
        menus: [
          for (final (mi, m) in _draft.menus.indexed)
            mi != menu
                ? m
                : m.copyWith(
                    meals: [
                      for (final (ci, c) in m.meals.indexed)
                        ci != meal
                            ? c
                            : c.copyWith(
                                items: [
                                  for (final (ii, i) in c.items.indexed)
                                    if (ii != item) i else ?replacement,
                                ],
                              ),
                    ],
                  ),
        ],
      );
    });
  }

  /// Abre el formulario de un renglón. [commit] guarda el resultado (o
  /// `null` para quitarlo) en el lugar que ocupa: suelto, como alternativa o
  /// como ingrediente de un plato.
  Future<void> _editItem(ItemDraft item, ValueChanged<ItemDraft?> commit) {
    return showAppSheet<void>(
      context,
      title: 'Corregir alimento',
      builder: (_) => PlanItemForm(
        initial: item,
        // El alimento corregido ya no lleva advertencia; conserva lo que
        // lleva dentro.
        onSave: (edited) async => commit(item.replacedBy(edited)),
        onDelete: () async => commit(null),
      ),
    );
  }

  /// El renglón de [item], sus alternativas y sus ingredientes.
  List<Widget> _rowsFor(
    ItemDraft item,
    ValueChanged<ItemDraft?> commit, {
    int depth = 0,
    bool alternative = false,
  }) {
    List<ItemDraft> replaced(List<ItemDraft> list, int at, ItemDraft? value) =>
        [
          for (final (i, x) in list.indexed)
            if (i != at) x else ?value,
        ];
    return [
      _ReviewItemRow(
        item: item,
        depth: depth,
        isAlternative: alternative,
        isDish: item.ingredients.isNotEmpty,
        onTap: () => _editItem(item, commit),
      ),
      for (final (i, other) in item.alternatives.indexed)
        ..._rowsFor(
          other,
          (value) => commit(
            item.copyWith(alternatives: replaced(item.alternatives, i, value)),
          ),
          depth: depth,
          alternative: true,
        ),
      for (final (i, ingredient) in item.ingredients.indexed)
        ..._rowsFor(
          ingredient,
          (value) => commit(
            item.copyWith(ingredients: replaced(item.ingredients, i, value)),
          ),
          depth: depth + 1,
        ),
    ];
  }

  Future<void> _save() async {
    if (_pending > 0) {
      final proceed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(
            _pending == 1
                ? 'Queda 1 renglón por revisar'
                : 'Quedan $_pending renglones por revisar',
          ),
          content: const Text(
            'Puedes guardarlo así y corregirlo después desde el plan.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Seguir revisando'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar así'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    await ref.read(nutritionRepositoryProvider).savePlan(widget.userId, _draft);
    // La guía de suplementos pasa sola al inventario.
    final result = await ref.read(supplementRepositoryProvider).addFromGuide(
      widget.userId,
      [
        for (final s in _draft.supplements)
          (name: s.name, dose: s.dose, timing: s.timing),
      ],
    );
    if (mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Plan guardado'),
          content: Text(supplementImportSummary(result)),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final meals = _draft.menus.expand((m) => m.meals).length;
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Revisar plan'),
        border: null,
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  screenPadding,
                  8,
                  screenPadding,
                  24,
                ),
                children: [
                  Text(
                    _draft.name,
                    style: textStyle(
                      context,
                      size: 26,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_draft.menus.length} menús · $meals comidas · '
                    '${_draft.items.length} alimentos · '
                    '${_draft.supplements.length} suplementos',
                    style: secondary.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 14),
                  _ReviewStatus(pending: _pending),
                  for (final warning in widget.parsed.warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _WarningLine(warning),
                    ),
                  for (final (menuIndex, menu) in _draft.menus.indexed) ...[
                    SectionHeader(
                      [
                        'Días de ${dayTypeLabel(menu.dayType).toLowerCase()}',
                        if (menu.routineDays.isNotEmpty)
                          'días ${formatDayList(menu.routineDays)} de la '
                              'rutina',
                      ].join(' · '),
                    ),
                    for (final (mealIndex, meal) in menu.meals.indexed) ...[
                      Padding(
                        padding: EdgeInsets.only(
                          top: mealIndex == 0 ? 0 : 16,
                          bottom: 8,
                        ),
                        child: Text(
                          [
                            '${mealIndex + 1}. ${meal.name}',
                            ?meal.timingNote,
                          ].join(' · '),
                          style: textStyle(context, weight: FontWeight.w600),
                        ),
                      ),
                      CardGroup(
                        children: [
                          for (final (itemIndex, item) in meal.items.indexed)
                            ..._rowsFor(
                              item,
                              (value) => _replaceItem(
                                menuIndex,
                                mealIndex,
                                itemIndex,
                                value,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                  const SectionHeader('Suplementos'),
                  if (_draft.supplements.isEmpty)
                    Text(
                      'No se encontraron suplementos en el plan.',
                      key: const Key('noSupplements'),
                      style: secondary.copyWith(fontSize: 15),
                    )
                  else ...[
                    CardGroup(
                      children: [
                        for (final supplement in _draft.supplements)
                          SupplementTile(
                            name: supplement.name,
                            dose: supplement.dose,
                            timing: supplement.timing,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            BottomActionBar(
              child: PrimaryButton(
                label: 'Guardar plan',
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado de la revisión: cuántos renglones faltan, o que no falta ninguno.
class _ReviewStatus extends StatelessWidget {
  const _ReviewStatus({required this.pending});

  final int pending;

  @override
  Widget build(BuildContext context) {
    final done = pending == 0;
    final color = resolveColor(
      context,
      done ? CupertinoColors.systemGreen : CupertinoColors.systemOrange,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: resolveColor(context, cardColor),
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Row(
        children: [
          Icon(
            done
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.exclamationmark_circle_fill,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              done
                  ? 'No hay renglones marcados. Compara con tu PDF antes de '
                        'guardar.'
                  : pending == 1
                  ? 'Hay 1 renglón que no se entendió. Tócalo para corregirlo.'
                  : 'Hay $pending renglones que no se entendieron. Tócalos '
                        'para corregirlos.',
              style: textStyle(context, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningLine extends StatelessWidget {
  const _WarningLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: textStyle(
        context,
        size: 13,
        weight: FontWeight.w500,
        color: CupertinoColors.systemOrange,
      ),
    );
  }
}

class _ReviewItemRow extends StatelessWidget {
  const _ReviewItemRow({
    required this.item,
    required this.onTap,
    this.depth = 0,
    this.isAlternative = false,
    this.isDish = false,
  });

  final ItemDraft item;
  final VoidCallback onTap;
  final int depth;
  final bool isAlternative;
  final bool isDish;

  @override
  Widget build(BuildContext context) {
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
      onPressed: onTap,
      child: Row(
        children: [
          if (item.warning != null) ...[
            Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              size: 20,
              color: resolveColor(context, CupertinoColors.systemOrange),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAlternative ? 'o ${item.name}' : item.name,
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
                if (item.warning case final warning?) _WarningLine(warning),
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

/// Qué pasó con la guía de suplementos al guardar el plan.
String supplementImportSummary(
  ({List<String> added, List<String> existing}) result,
) {
  final added = result.added;
  final existing = result.existing;
  if (added.isEmpty && existing.isEmpty) {
    return 'No se encontraron suplementos en el plan.';
  }
  final parts = [
    if (added.length == 1)
      'Se agregó ${added.single} a tus suplementos.'
    else if (added.isNotEmpty)
      'Se agregaron ${added.length} suplementos: ${added.join(', ')}.',
    if (existing.isNotEmpty)
      existing.length == 1
          ? '${existing.single} ya estaba en tu inventario.'
          : '${existing.length} ya estaban en tu inventario.',
    if (added.isNotEmpty)
      'En Suplementos, anota cuánto tienes de cada uno para que la app te '
          'avise cuándo reabastecer.',
  ];
  return parts.join(' ');
}
