import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/database.dart';
import '../data/repositories/nutrition_repository.dart';
import '../domain/cooking.dart';
import '../domain/nutrition.dart';
import 'formatting.dart';
import 'theme.dart';
import 'widgets.dart';

/// Lotes de cocción: lo que se cocinó de una vez, con su peso crudo y cocido.
/// De cada lote sale el factor con el que el plan convierte crudo a cocido.
class BatchesScreen extends ConsumerWidget {
  const BatchesScreen({super.key, required this.user});

  final User user;

  /// Los alimentos del plan, para elegir de cuál es el lote. Primero los que
  /// el plan pide en crudo, que son los que se convierten.
  List<_FoodChoice> _choices(WidgetRef ref) {
    final view = ref.watch(activePlanProvider(user.id)).value;
    final byKey = <String, _FoodChoice>{};
    for (final menu in view?.menus ?? const <MenuView>[]) {
      for (final meal in menu.meals) {
        for (final item in meal.items) {
          for (final option in foodOptions(item.name)) {
            final key = normalizeFood(option);
            if (key.isEmpty) continue;
            final isRaw = item.state == FoodState.raw;
            final existing = byKey[key];
            // Si aparece en crudo en algún renglón, se lista como crudo.
            if (existing == null || (isRaw && !existing.isRaw)) {
              byKey[key] = (
                // Con mayúscula inicial y sin aclaraciones entre paréntesis.
                name: _titleCase(
                  option.replaceAll(RegExp(r'\s*\([^)]*\)'), ''),
                ),
                isRaw: isRaw,
              );
            }
          }
        }
      }
    }
    final choices = byKey.values.toList()
      ..sort((a, b) {
        if (a.isRaw != b.isRaw) return a.isRaw ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return choices;
  }

  static String _titleCase(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty
        ? trimmed
        : trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches =
        ref.watch(cookingBatchesProvider(user.id)).value ?? const [];
    final choices = _choices(ref);
    final repository = ref.read(cookingRepositoryProvider);

    void openForm({CookingBatch? editing}) {
      showAppSheet<void>(
        context,
        title: editing == null ? 'Nuevo lote' : 'Editar lote',
        builder: (_) => _BatchForm(
          editing: editing,
          choices: choices,
          onSave: (draft) => editing == null
              ? repository.addBatch(
                  userId: user.id,
                  foodName: draft.foodName,
                  rawWeightG: draft.rawG,
                  cookedWeightG: draft.cookedG,
                  withOtherIngredients: draft.withOtherIngredients,
                  note: draft.note,
                )
              : repository.updateBatch(
                  editing.id,
                  foodName: draft.foodName,
                  rawWeightG: draft.rawG,
                  cookedWeightG: draft.cookedG,
                  withOtherIngredients: draft.withOtherIngredients,
                  note: draft.note,
                ),
          onDelete: editing == null
              ? null
              : () => repository.deleteBatch(editing.id),
        ),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Lotes de cocción'),
        previousPageTitle: 'Atrás',
        border: null,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: batches.isEmpty
                  ? const _NoBatches()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        screenPadding,
                        8,
                        screenPadding,
                        24,
                      ),
                      children: [
                        Text(
                          'El plan usa el lote más reciente de cada alimento '
                          'para decirte cuántos gramos cocidos servir.',
                          style: textStyle(
                            context,
                            size: 15,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CardGroup(
                          children: [
                            for (final batch in batches)
                              _BatchRow(
                                batch: batch,
                                onTap: () => openForm(editing: batch),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
            BottomActionBar(
              child: PrimaryButton(
                label: 'Agregar lote',
                icon: CupertinoIcons.add,
                onPressed: openForm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoBatches extends StatelessWidget {
  const _NoBatches();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.flame,
              size: 44,
              color: resolveColor(context, CupertinoColors.tertiaryLabel),
            ),
            const SizedBox(height: 14),
            Text(
              'Sin lotes todavía',
              style: textStyle(context, size: 20, weight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Cuando cocines varias porciones de una vez, pesa el alimento '
              'en crudo y otra vez ya cocido. Con eso, el plan te dirá '
              'cuántos gramos cocidos equivalen a tu porción en crudo.',
              textAlign: TextAlign.center,
              style: textStyle(
                context,
                size: 15,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchRow extends StatelessWidget {
  const _BatchRow({required this.batch, required this.onTap});

  final CookingBatch batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final factor = yieldFactor(
      rawG: batch.rawWeightG,
      cookedG: batch.cookedWeightG,
    );
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );

    return CupertinoButton(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.foodName,
                  style: textStyle(context, weight: FontWeight.w600),
                ),
                Text(
                  // Sin flecha: la fuente de la app no trae ese carácter.
                  'Crudo ${formatNumber(batch.rawWeightG, decimals: 0)} g · '
                  'cocido ${formatNumber(batch.cookedWeightG, decimals: 0)} g',
                  style: textStyle(context, size: 15),
                ),
                Text(
                  [
                    formatShortDate(batch.cookedAt.toLocal()),
                    if (batch.withOtherIngredients) 'con otros ingredientes',
                    ?batch.note,
                  ].join(' · '),
                  style: secondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (factor != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '× ${formatNumber(factor, decimals: 2)}',
                  style: textStyle(context, size: 20, weight: FontWeight.w700),
                ),
                Text('rendimiento', style: secondary),
              ],
            ),
          const SizedBox(width: 6),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: resolveColor(context, CupertinoColors.tertiaryLabel),
          ),
        ],
      ),
    );
  }
}

/// Un alimento del plan entre los que se puede elegir para un lote.
typedef _FoodChoice = ({String name, bool isRaw});

typedef _BatchDraft = ({
  String foodName,
  double rawG,
  double cookedG,
  bool withOtherIngredients,
  String note,
});

class _BatchForm extends StatefulWidget {
  const _BatchForm({
    required this.onSave,
    required this.choices,
    this.editing,
    this.onDelete,
  });

  final CookingBatch? editing;

  /// Alimentos del plan entre los que elegir.
  final List<_FoodChoice> choices;
  final Future<void> Function(_BatchDraft draft) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<_BatchForm> createState() => _BatchFormState();
}

class _BatchFormState extends State<_BatchForm> {
  static String? _grams(double? value) =>
      value == null ? null : formatNumber(value, decimals: 1);

  late final _food = TextEditingController(text: widget.editing?.foodName);
  late final _raw = TextEditingController(
    text: _grams(widget.editing?.rawWeightG),
  );
  late final _cooked = TextEditingController(
    text: _grams(widget.editing?.cookedWeightG),
  );
  late final _note = TextEditingController(text: widget.editing?.note);
  late bool _withOthers = widget.editing?.withOtherIngredients ?? false;

  /// Se escribe el nombre a mano: no hay plan, se eligió "Otro", o se edita
  /// un lote cuyo alimento no está en el plan.
  late bool _custom =
      widget.choices.isEmpty ||
      (widget.editing != null &&
          !widget.choices.any(
            (c) =>
                normalizeFood(c.name) ==
                normalizeFood(widget.editing!.foodName),
          ));
  String? _error;

  @override
  void initState() {
    super.initState();
    // El factor se recalcula mientras se escriben los pesos.
    _raw.addListener(_refresh);
    _cooked.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _food.dispose();
    _raw.dispose();
    _cooked.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Abre la lista de alimentos del plan, con "Otro" al final.
  Future<void> _pickFood() async {
    const other = '\u0000otro';
    Widget row(BuildContext context, String value, String label) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        onPressed: () => Navigator.of(context).pop(value),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: textStyle(context)),
        ),
      );
    }

    Widget label(BuildContext context, String text) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(
          text,
          style: textStyle(
            context,
            size: 13,
            weight: FontWeight.w600,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      );
    }

    final raw = widget.choices.where((c) => c.isRaw).toList();
    final rest = widget.choices.where((c) => !c.isRaw).toList();
    final choice = await showAppSheet<String>(
      context,
      title: 'Alimento del lote',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (raw.isNotEmpty) ...[
            label(context, 'Tu plan los pide en crudo'),
            CardGroup(
              children: [for (final c in raw) row(context, c.name, c.name)],
            ),
          ],
          if (rest.isNotEmpty) ...[
            label(context, 'Otros alimentos de tu plan'),
            CardGroup(
              children: [for (final c in rest) row(context, c.name, c.name)],
            ),
          ],
          const SizedBox(height: 14),
          CardGroup(children: [row(context, other, 'Otro…')]),
        ],
      ),
    );
    if (choice == null) return;
    setState(() {
      _custom = choice == other;
      _food.text = _custom ? '' : choice;
    });
  }

  Future<void> _save() async {
    final raw = parseNumber(_raw.text);
    final cooked = parseNumber(_cooked.text);

    String? error;
    if (_food.text.trim().isEmpty) {
      error = _custom
          ? 'Escribe qué alimento cocinaste.'
          : 'Elige el alimento del lote.';
    } else if (raw == null || raw <= 0) {
      error = 'Escribe el peso en crudo, en gramos.';
    } else if (cooked == null || cooked <= 0) {
      error = 'Escribe el peso ya cocido, en gramos.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final navigator = Navigator.of(context);
    await widget.onSave((
      foodName: _food.text,
      rawG: raw!,
      cookedG: cooked!,
      withOtherIngredients: _withOthers,
      note: _note.text,
    ));
    navigator.pop();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    await widget.onDelete!();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    const decimal = TextInputType.numberWithOptions(decimal: true);
    final raw = parseNumber(_raw.text);
    final cooked = parseNumber(_cooked.text);
    final factor = raw == null || cooked == null
        ? null
        : yieldFactor(rawG: raw, cookedG: cooked);
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.choices.isNotEmpty) ...[
          CardGroup(
            children: [
              PickerRow(
                key: const Key('batchFoodPicker'),
                label: 'Alimento',
                value: _custom
                    ? 'Otro'
                    : _food.text.isEmpty
                    ? null
                    : _food.text,
                onPressed: _pickFood,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_custom) ...[
          CardTextField(
            key: const Key('batchFood'),
            controller: _food,
            placeholder: 'Nombre del alimento',
            autofocus: widget.editing == null,
          ),
          const SizedBox(height: 12),
        ],
        CardGroup(
          children: [
            FormRow(
              label: 'Peso en crudo (g)',
              child: RowTextField(
                key: const Key('batchRaw'),
                controller: _raw,
                placeholder: '0',
                keyboardType: decimal,
              ),
            ),
            FormRow(
              label: 'Peso cocido (g)',
              child: RowTextField(
                key: const Key('batchCooked'),
                controller: _cooked,
                placeholder: '0',
                keyboardType: decimal,
              ),
            ),
            FormRow(
              label: 'Con otros ingredientes',
              child: CupertinoSwitch(
                value: _withOthers,
                onChanged: (value) => setState(() => _withOthers = value),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(
            factor == null
                ? 'Pesa todo el alimento antes de cocinarlo y otra vez al '
                      'terminar.'
                : _withOthers
                ? 'Rendimiento × ${formatNumber(factor, decimals: 2)}, '
                      'aproximado: el peso cocido incluye lo que agregaste '
                      '(salsa, verduras).'
                : 'Rendimiento × ${formatNumber(factor, decimals: 2)}: '
                      '100 g en crudo quedan en '
                      '${formatNumber(factor * 100, decimals: 0)} g cocidos.',
            key: const Key('batchFactor'),
            style: secondary,
          ),
        ),
        const SizedBox(height: 12),
        CardTextField(
          key: const Key('batchNote'),
          controller: _note,
          placeholder: 'Nota (opcional)',
        ),
        if (_error != null) FormError(_error!),
        FormActions(
          saveLabel: widget.editing == null
              ? 'Guardar lote'
              : 'Guardar cambios',
          onSave: _save,
          deleteLabel: 'Borrar lote',
          onDelete: widget.onDelete == null ? null : _delete,
        ),
      ],
    );
  }
}
