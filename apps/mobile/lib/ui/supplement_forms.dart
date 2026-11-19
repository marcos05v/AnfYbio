import 'package:flutter/cupertino.dart';

import '../domain/supplement_inventory.dart';
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

  /// Contenido del envase que ya se tiene, en la unidad del suplemento.
  double? initialQuantity,
  DateTime? purchasedAt,

  /// Lo que se calcula ya consumido de ese envase.
  double alreadyConsumed,

  /// Hora del recordatorio diario, en minutos desde la medianoche.
  int? reminderMinute,
});

/// Alta o edición de un suplemento.
///
/// Al dar de alta pregunta la presentación (pastillas, polvo u otra), el
/// contenido del envase, cuándo se compró y si ya se empezó a tomar. Con eso
/// estima lo que queda, para no arrancar el inventario en blanco.
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
    this.initialPurchaseDate,
    this.reminderMinute,
    this.onEnableReminder,
    this.onDelete,
  });

  final bool isEditing;
  final String? name;
  final String? unitLabel;
  final double? dailyDose;
  final String? timing;
  final int restockLeadDays;

  /// Fecha de compra con la que se abre el formulario; hoy si es nula.
  final DateTime? initialPurchaseDate;

  /// Hora del recordatorio con la que se abre; nula si no tiene.
  final int? reminderMinute;

  /// Se llama al activar el recordatorio, para pedir permiso de notificar.
  /// Devuelve si están permitidas.
  final Future<bool> Function()? onEnableReminder;
  final Future<void> Function(SupplementDraftData data) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<SupplementForm> createState() => _SupplementFormState();
}

class _SupplementFormState extends State<SupplementForm> {
  late final _name = TextEditingController(text: widget.name);
  late final _unit = TextEditingController(
    text: _presentation == SupplementPresentation.other ? widget.unitLabel : '',
  );
  late final _dose = TextEditingController(
    text: widget.dailyDose == null
        ? null
        : formatNumber(widget.dailyDose!, decimals: 2),
  );
  late final _lead = TextEditingController(text: '${widget.restockLeadDays}');
  late final _timing = TextEditingController(text: widget.timing);
  final _content = TextEditingController();

  late SupplementPresentation _presentation = widget.unitLabel == null
      ? SupplementPresentation.pills
      : presentationOf(widget.unitLabel!);

  /// El contenido de un polvo se puede escribir en kilos.
  bool _inKilos = false;
  late DateTime _purchasedOn = widget.initialPurchaseDate ?? DateTime.now();
  bool _started = false;

  /// Hora del recordatorio diario; nula si está apagado.
  late int? _reminder = widget.reminderMinute;
  bool _notificationsDenied = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // La estimación de lo que queda se recalcula al escribir.
    _dose.addListener(_refresh);
    _content.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _unit, _dose, _lead, _timing, _content]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _unitLabel => switch (_presentation) {
    SupplementPresentation.pills => pillsUnit,
    SupplementPresentation.powder => powderUnit,
    SupplementPresentation.other => _unit.text.trim(),
  };

  /// Contenido del envase en la unidad del suplemento (los kilos, en gramos).
  double? get _quantity {
    final value = parseNumber(_content.text);
    if (value == null) return null;
    final inKilos = _presentation == SupplementPresentation.powder && _inKilos;
    return inKilos ? value * 1000 : value;
  }

  /// Lo que se calcula ya tomado del envase, si se marcó como empezado.
  double _consumed(double dose, double quantity) => _started
      ? estimatedConsumed(
          dailyDose: dose,
          quantity: quantity,
          purchasedOn: _purchasedOn,
          today: DateTime.now(),
        )
      : 0;

  Future<void> _pickDate() async {
    final today = DateTime.now();
    var picked = _purchasedOn;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: resolveColor(context, sheetColor),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Listo'),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: picked,
                  maximumDate: today,
                  minimumDate: DateTime(today.year - 3),
                  onDateTimeChanged: (date) => picked = date,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    setState(() => _purchasedOn = picked);
  }

  Future<void> _toggleReminder(bool on) async {
    setState(() {
      _reminder = on ? 9 * 60 : null;
      _notificationsDenied = false;
    });
    if (!on || widget.onEnableReminder == null) return;
    final allowed = await widget.onEnableReminder!();
    if (mounted) setState(() => _notificationsDenied = !allowed);
  }

  Future<void> _pickReminderTime() async {
    final current = _reminder ?? 9 * 60;
    var picked = current;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: resolveColor(context, sheetColor),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Listo'),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: false,
                  minuteInterval: 5,
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    current ~/ 60,
                    current % 60 - current % 5,
                  ),
                  onDateTimeChanged: (time) =>
                      picked = time.hour * 60 + time.minute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    setState(() => _reminder = picked);
  }

  Future<void> _save() async {
    final dose = parseNumber(_dose.text);
    final lead = int.tryParse(_lead.text.trim());
    final hasContent = _content.text.trim().isNotEmpty;
    final quantity = _quantity;

    String? error;
    if (_name.text.trim().isEmpty) {
      error = 'Escribe el nombre del suplemento.';
    } else if (_unitLabel.isEmpty) {
      error = 'Escribe en qué se mide: ml, scoops, gotas…';
    } else if (dose == null || dose <= 0) {
      error = 'Escribe cuánto tomas al día.';
    } else if (hasContent && (quantity == null || quantity <= 0)) {
      error = 'El contenido del envase debe ser un número mayor que cero.';
    } else if (lead == null || lead < 0) {
      error = 'Los días de aviso deben ser un número entero.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final navigator = Navigator.of(context);
    await widget.onSave((
      name: _name.text,
      unitLabel: _unitLabel,
      dailyDose: dose!,
      timing: _timing.text,
      restockLeadDays: lead!,
      initialQuantity: quantity,
      // Mediodía local: la fecha no cambia de día al pasar a UTC.
      purchasedAt: quantity == null
          ? null
          : DateTime(
              _purchasedOn.year,
              _purchasedOn.month,
              _purchasedOn.day,
              12,
            ),
      alreadyConsumed: quantity == null ? 0 : _consumed(dose, quantity),
      reminderMinute: _reminder,
    ));
    navigator.pop();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    await widget.onDelete!();
    navigator.pop();
  }

  /// Frase con lo que la app calcula que queda del envase.
  String? _estimate() {
    final dose = parseNumber(_dose.text);
    final quantity = _quantity;
    if (dose == null || dose <= 0 || quantity == null || quantity <= 0) {
      return null;
    }
    final unit = _unitLabel;
    if (!_started) {
      return 'Empiezas con ${formatQuantity(quantity, unit)}: alcanza '
          '${formatDaysLeft((quantity / dose).floor())}.';
    }
    final consumed = _consumed(dose, quantity);
    final left = quantity - consumed;
    return 'Tomando ${formatQuantity(dose, unit)} al día desde el '
        '${formatShortDate(_purchasedOn)}, se calcula que llevas '
        '${formatQuantity(consumed, unit)} y te quedan '
        '${formatQuantity(left, unit)}. Podrás corregirlo después.';
  }

  @override
  Widget build(BuildContext context) {
    const decimal = TextInputType.numberWithOptions(decimal: true);
    final isPowder = _presentation == SupplementPresentation.powder;
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );
    final estimate = widget.isEditing ? null : _estimate();

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
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('¿En qué presentación viene?', style: secondary),
        ),
        CupertinoSlidingSegmentedControl<SupplementPresentation>(
          groupValue: _presentation,
          padding: const EdgeInsets.all(4),
          children: const {
            SupplementPresentation.pills: _Segment('Pastillas'),
            SupplementPresentation.powder: _Segment('Polvo'),
            SupplementPresentation.other: _Segment('Otra'),
          },
          onValueChanged: (value) {
            if (value != null) setState(() => _presentation = value);
          },
        ),
        const SizedBox(height: 12),
        CardGroup(
          children: [
            if (_presentation == SupplementPresentation.other)
              FormRow(
                label: 'Se mide en',
                child: RowTextField(
                  key: const Key('supUnit'),
                  controller: _unit,
                  placeholder: 'ml, scoops, gotas…',
                ),
              ),
            FormRow(
              label: switch (_presentation) {
                SupplementPresentation.pills => 'Pastillas al día',
                SupplementPresentation.powder => 'Gramos al día',
                SupplementPresentation.other => 'Cantidad al día',
              },
              child: RowTextField(
                key: const Key('supDose'),
                controller: _dose,
                placeholder: '0',
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
        const SizedBox(height: 12),
        CardGroup(
          children: [
            FormRow(
              label: 'Recordatorio diario',
              child: CupertinoSwitch(
                key: const Key('supReminder'),
                value: _reminder != null,
                onChanged: _toggleReminder,
              ),
            ),
            if (_reminder case final minute?)
              PickerRow(
                key: const Key('supReminderTime'),
                label: 'Hora',
                value: formatMinuteOfDay(minute),
                onPressed: _pickReminderTime,
              ),
          ],
        ),
        if (_notificationsDenied)
          FormError(
            'Las notificaciones están desactivadas. Actívalas en Ajustes del '
            'iPhone > Notificaciones > AnfYbio.',
          ),
        if (!widget.isEditing) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('El envase que tienes', style: secondary),
          ),
          CardGroup(
            children: [
              FormRow(
                label: switch (_presentation) {
                  SupplementPresentation.pills => 'Pastillas que trae',
                  _ => 'Contenido',
                },
                child: Row(
                  children: [
                    Expanded(
                      child: RowTextField(
                        key: const Key('supContent'),
                        controller: _content,
                        placeholder: '0',
                        keyboardType: decimal,
                      ),
                    ),
                    if (isPowder) ...[
                      const SizedBox(width: 12),
                      CupertinoSlidingSegmentedControl<bool>(
                        groupValue: _inKilos,
                        children: const {
                          false: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text('g'),
                          ),
                          true: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text('kg'),
                          ),
                        },
                        onValueChanged: (value) {
                          if (value != null) setState(() => _inKilos = value);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              PickerRow(
                key: const Key('supPurchaseDate'),
                label: 'Lo compré el',
                value: formatShortDate(_purchasedOn),
                onPressed: _pickDate,
              ),
              FormRow(
                label: 'Ya lo empecé a tomar',
                child: CupertinoSwitch(
                  key: const Key('supStarted'),
                  value: _started,
                  onChanged: (value) => setState(() => _started = value),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              estimate ??
                  'Con el contenido del envase y la fecha de compra, la app '
                      'calcula cuánto te queda.',
              key: const Key('supEstimate'),
              style: secondary,
            ),
          ),
        ],
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

class _Segment extends StatelessWidget {
  const _Segment(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(label, style: textStyle(context, size: 15)),
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

  /// Si la unidad son gramos, deja escribir la cantidad en kilos.
  bool get _canUseKilos =>
      presentationOf(unitLabel) == SupplementPresentation.powder;
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
  bool _inKilos = false;
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
    await widget.onSave(_inKilos ? quantity * 1000 : quantity, _note.text);
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
              label: widget._canUseKilos
                  ? widget.label
                  : '${widget.label} (${widget.unitLabel})',
              child: Row(
                children: [
                  Expanded(
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
                  if (widget._canUseKilos) ...[
                    const SizedBox(width: 12),
                    CupertinoSlidingSegmentedControl<bool>(
                      groupValue: _inKilos,
                      children: const {
                        false: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('g'),
                        ),
                        true: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('kg'),
                        ),
                      },
                      onValueChanged: (value) {
                        if (value != null) setState(() => _inKilos = value);
                      },
                    ),
                  ],
                ],
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

/// Hoja para poner, cambiar o quitar el recordatorio diario de un suplemento.
///
/// La hora se elige con una rueda de 12 horas (a. m. / p. m.) y se confirma
/// con un botón. Antes de guardar pide permiso para notificar: sin permiso,
/// el recordatorio no sonaría.
class ReminderSheet extends StatefulWidget {
  const ReminderSheet({
    super.key,
    required this.supplementName,
    required this.onSave,
    required this.requestPermission,
    this.initialMinute,
  });

  final String supplementName;

  /// Hora actual del recordatorio; nula si aún no tiene.
  final int? initialMinute;

  /// Guarda la hora elegida, o la quita con `null`.
  final Future<void> Function(int? minute) onSave;
  final Future<bool> Function() requestPermission;

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  late int _minute = widget.initialMinute ?? 9 * 60;
  bool _denied = false;

  Future<void> _save() async {
    final allowed = await widget.requestPermission();
    if (!mounted) return;
    if (!allowed) {
      setState(() => _denied = true);
      return;
    }
    final navigator = Navigator.of(context);
    await widget.onSave(_minute);
    navigator.pop();
  }

  Future<void> _remove() async {
    final navigator = Navigator.of(context);
    await widget.onSave(null);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final (clock, period) = splitClock12(_minute);
    final accent = resolveColor(context, accentColor);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Te avisaremos todos los días para tomar tu '
          '${splitName(widget.supplementName).$1}.',
          style: textStyle(
            context,
            size: 15,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: 16),
        // La hora elegida, grande, sobre la rueda.
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                clock,
                key: const Key('reminderClock'),
                style: textStyle(
                  context,
                  size: 48,
                  weight: FontWeight.w700,
                  color: accent,
                ).copyWith(height: 1.1),
              ),
              const SizedBox(width: 8),
              Text(
                period,
                style: textStyle(
                  context,
                  size: 22,
                  weight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: false,
            minuteInterval: 5,
            initialDateTime: DateTime(
              2000,
              1,
              1,
              _minute ~/ 60,
              _minute % 60 - _minute % 5,
            ),
            onDateTimeChanged: (time) =>
                setState(() => _minute = time.hour * 60 + time.minute),
          ),
        ),
        if (_denied)
          FormError(
            'Las notificaciones están desactivadas. Actívalas en Ajustes del '
            'iPhone > Notificaciones > AnfYbio y vuelve a intentarlo.',
          ),
        FormActions(
          saveLabel: widget.initialMinute == null
              ? 'Poner recordatorio'
              : 'Guardar recordatorio',
          onSave: _save,
          deleteLabel: 'Quitar recordatorio',
          onDelete: widget.initialMinute == null ? null : _remove,
        ),
      ],
    );
  }
}
