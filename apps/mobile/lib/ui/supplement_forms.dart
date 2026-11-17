import 'package:flutter/cupertino.dart';

import 'formatting.dart';
import 'theme.dart';
import 'widgets.dart';

/// Datos de un suplemento tal como salen de su formulario.
typedef SupplementDraftData = ({
  String name,
  String unitLabel,
  double dailyDose,
  String timing,
  int restockLeadDays,
  double? initialQuantity,
});

/// Alta o edición de un suplemento.
class SupplementForm extends StatefulWidget {
  const SupplementForm({
    super.key,
    required this.onSave,
    this.isEditing = false,
    this.name,
    this.unitLabel,
    this.dailyDose,
    this.timing,
    this.restockLeadDays = 7,
    this.onDelete,
  });

  final bool isEditing;
  final String? name;
  final String? unitLabel;
  final double? dailyDose;
  final String? timing;
  final int restockLeadDays;
  final Future<void> Function(SupplementDraftData data) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<SupplementForm> createState() => _SupplementFormState();
}

class _SupplementFormState extends State<SupplementForm> {
  late final _name = TextEditingController(text: widget.name);
  late final _unit = TextEditingController(text: widget.unitLabel);
  late final _dose = TextEditingController(
    text: widget.dailyDose == null
        ? null
        : formatNumber(widget.dailyDose!, decimals: 2),
  );
  late final _lead = TextEditingController(text: '${widget.restockLeadDays}');
  late final _timing = TextEditingController(text: widget.timing);
  final _initial = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _unit, _dose, _lead, _timing, _initial]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final dose = parseNumber(_dose.text);
    final lead = int.tryParse(_lead.text.trim());
    final initialText = _initial.text.trim();
    final initial = initialText.isEmpty ? null : parseNumber(initialText);

    String? error;
    if (_name.text.trim().isEmpty) {
      error = 'Escribe el nombre del suplemento.';
    } else if (_unit.text.trim().isEmpty) {
      error = 'Escribe la unidad: g, cápsulas, scoops…';
    } else if (dose == null || dose <= 0) {
      error = 'Escribe cuánto tomas al día, en esa unidad.';
    } else if (lead == null || lead < 0) {
      error = 'Los días de aviso deben ser un número entero.';
    } else if (initialText.isNotEmpty && (initial == null || initial <= 0)) {
      error = 'Lo que tienes ahora debe ser un número mayor que cero.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final navigator = Navigator.of(context);
    await widget.onSave((
      name: _name.text,
      unitLabel: _unit.text,
      dailyDose: dose!,
      timing: _timing.text,
      restockLeadDays: lead!,
      initialQuantity: initial,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardTextField(
          key: const Key('supName'),
          controller: _name,
          placeholder: 'Suplemento (Creatina)',
          autofocus: !widget.isEditing && widget.name == null,
        ),
        const SizedBox(height: 12),
        CardGroup(
          children: [
            FormRow(
              label: 'Unidad',
              child: RowTextField(
                key: const Key('supUnit'),
                controller: _unit,
                placeholder: 'g, cápsulas…',
              ),
            ),
            FormRow(
              label: 'Dosis diaria',
              child: RowTextField(
                key: const Key('supDose'),
                controller: _dose,
                placeholder: '0',
                keyboardType: decimal,
              ),
            ),
            if (!widget.isEditing)
              FormRow(
                label: 'Tengo ahora',
                child: RowTextField(
                  key: const Key('supInitial'),
                  controller: _initial,
                  placeholder: 'Opcional',
                  keyboardType: decimal,
                ),
              ),
            FormRow(
              label: 'Avisar con (días)',
              child: RowTextField(
                key: const Key('supLead'),
                controller: _lead,
                placeholder: '7',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(
            'Usa la misma unidad para todo: si el frasco trae 60 cápsulas y '
            'tomas una al día, la unidad es "cápsulas" y la dosis es 1.',
            style: textStyle(
              context,
              size: 13,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ),
        const SizedBox(height: 12),
        CardTextField(
          key: const Key('supTiming'),
          controller: _timing,
          placeholder: 'Cuándo tomarlo (opcional)',
          maxLines: 3,
        ),
        if (_error != null) FormError(_error!),
        FormActions(
          saveLabel: widget.isEditing
              ? 'Guardar cambios'
              : 'Guardar suplemento',
          onSave: _save,
          deleteLabel: 'Borrar suplemento',
          onDelete: widget.onDelete == null ? null : _delete,
        ),
      ],
    );
  }
}

/// Pide una cantidad (y opcionalmente una nota): sirve para registrar una
/// compra y para corregir las existencias.
class QuantityForm extends StatefulWidget {
  const QuantityForm({
    super.key,
    required this.label,
    required this.unitLabel,
    required this.saveLabel,
    required this.onSave,
    this.help,
    this.withNote = false,
    this.allowZero = false,
    this.initial,
  });

  final String label;
  final String unitLabel;
  final String saveLabel;
  final String? help;
  final bool withNote;

  /// Corregir existencias admite cero ("ya no queda nada").
  final bool allowZero;
  final double? initial;
  final Future<void> Function(double quantity, String note) onSave;

  @override
  State<QuantityForm> createState() => _QuantityFormState();
}

class _QuantityFormState extends State<QuantityForm> {
  late final _quantity = TextEditingController(
    text: widget.initial == null
        ? null
        : formatNumber(widget.initial!, decimals: 1),
  );
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final quantity = parseNumber(_quantity.text);
    if (quantity == null ||
        quantity < 0 ||
        (quantity == 0 && !widget.allowZero)) {
      setState(() => _error = 'Escribe una cantidad válida.');
      return;
    }
    final navigator = Navigator.of(context);
    await widget.onSave(quantity, _note.text);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardGroup(
          children: [
            FormRow(
              label: '${widget.label} (${widget.unitLabel})',
              child: RowTextField(
                key: const Key('quantity'),
                controller: _quantity,
                placeholder: '0',
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        if (widget.help != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              widget.help!,
              style: textStyle(
                context,
                size: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
        if (widget.withNote) ...[
          const SizedBox(height: 12),
          CardTextField(
            key: const Key('quantityNote'),
            controller: _note,
            placeholder: 'Nota (opcional)',
          ),
        ],
        if (_error != null) FormError(_error!),
        FormActions(saveLabel: widget.saveLabel, onSave: _save),
      ],
    );
  }
}
