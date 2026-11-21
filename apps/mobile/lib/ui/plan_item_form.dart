import 'package:flutter/cupertino.dart';

import '../domain/nutrition.dart';
import 'formatting.dart';
import 'widgets.dart';

/// Formulario de un alimento del plan. Trabaja con borradores, así que sirve
/// igual para el plan guardado que para la revisión de uno importado.
class PlanItemForm extends StatefulWidget {
  const PlanItemForm({
    super.key,
    required this.onSave,
    this.initial,
    this.onDelete,
  });

  /// El alimento que se corrige; `null` si se agrega uno nuevo.
  final ItemDraft? initial;
  final Future<void> Function(ItemDraft draft) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<PlanItemForm> createState() => _PlanItemFormState();
}

class _PlanItemFormState extends State<PlanItemForm> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _amount = TextEditingController(
    text: widget.initial?.amount == null
        ? null
        : formatNumber(widget.initial!.amount!, decimals: 2),
  );
  late final _note = TextEditingController(text: widget.initial?.note);
  late FoodUnit _unit = widget.initial?.unit ?? FoodUnit.gram;
  late FoodState _state = widget.initial?.state ?? FoodState.unspecified;
  late bool _isFree = widget.initial?.isFree ?? false;
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

  Future<void> _pickUnit() async {
    final unit = await showCupertinoModalPopup<FoodUnit>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Unidad'),
        actions: [
          for (final unit in FoodUnit.values)
            CupertinoActionSheetAction(
              key: Key('unit-${unit.name}'),
              isDefaultAction: unit == _unit,
              onPressed: () => Navigator.of(context).pop(unit),
              child: Text(foodUnitLabel(unit)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (unit != null) setState(() => _unit = unit);
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
          key: const Key('itemName'),
          controller: _name,
          placeholder: 'Alimento',
          autofocus: widget.initial == null,
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
              PickerRow(
                key: const Key('itemUnit'),
                label: 'Unidad',
                value: foodUnitLabel(_unit),
                onPressed: _pickUnit,
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
        FormActions(
          saveLabel: widget.initial == null
              ? 'Guardar alimento'
              : 'Guardar cambios',
          onSave: _save,
          deleteLabel: 'Borrar alimento',
          onDelete: widget.onDelete == null ? null : _delete,
        ),
      ],
    );
  }
}
