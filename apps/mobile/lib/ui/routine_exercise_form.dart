import 'package:flutter/cupertino.dart';

import '../domain/routine.dart';
import 'widgets.dart';

/// Formulario de un ejercicio de la rutina. Trabaja con borradores, así que
/// sirve igual para la rutina guardada que para la revisión de una importada.
class RoutineExerciseForm extends StatefulWidget {
  const RoutineExerciseForm({
    super.key,
    required this.onSave,
    this.initial,
    this.onDelete,
  });

  /// El ejercicio que se corrige; `null` si se agrega uno nuevo.
  final RoutineExerciseDraft? initial;
  final Future<void> Function(RoutineExerciseDraft draft) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<RoutineExerciseForm> createState() => _RoutineExerciseFormState();
}

class _RoutineExerciseFormState extends State<RoutineExerciseForm> {
  static String? _text(int? value) => value?.toString();

  late final _name = TextEditingController(text: widget.initial?.name);
  late final _warmup = TextEditingController(
    text: (widget.initial?.warmupSets ?? 0) == 0
        ? null
        : '${widget.initial!.warmupSets}',
  );
  late final _sets = TextEditingController(
    text: _text(widget.initial?.workSets),
  );
  late final _repsMin = TextEditingController(
    text: _text(widget.initial?.repsMin),
  );
  late final _repsMax = TextEditingController(
    text: _text(widget.initial?.repsMax),
  );
  late final _repsNote = TextEditingController(text: widget.initial?.repsNote);
  late final _note = TextEditingController(text: widget.initial?.note);
  late bool _superset = widget.initial?.supersetWithPrevious ?? false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _warmup,
      _sets,
      _repsMin,
      _repsMax,
      _repsNote,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    /// Vacío → nulo; texto que no es un entero ≥ 0 → error (devuelve -1).
    int? number(TextEditingController controller) {
      final text = controller.text.trim();
      if (text.isEmpty) return null;
      final value = int.tryParse(text);
      return value == null || value < 0 ? -1 : value;
    }

    final warmup = number(_warmup);
    final sets = number(_sets);
    var repsMin = number(_repsMin);
    var repsMax = number(_repsMax);

    String? error;
    if (_name.text.trim().isEmpty) {
      error = 'Escribe el nombre del ejercicio.';
    } else if ([warmup, sets, repsMin, repsMax].contains(-1)) {
      error = 'Series y repeticiones deben ser números enteros.';
    } else if (sets == 0 || repsMin == 0 || repsMax == 0) {
      error = 'Series y repeticiones deben ser mayores que cero.';
    } else if (repsMin != null && repsMax != null && repsMin > repsMax) {
      error = 'El mínimo de repeticiones no puede superar al máximo.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    // Con un solo dato de repeticiones, el objetivo es ese número fijo.
    repsMin ??= repsMax;
    repsMax ??= repsMin;

    final navigator = Navigator.of(context);
    await widget.onSave(
      RoutineExerciseDraft(
        name: _name.text,
        groupLabel: widget.initial?.groupLabel,
        warmupSets: warmup ?? 0,
        workSets: sets,
        repsMin: repsMin,
        repsMax: repsMax,
        repsNote: _repsNote.text,
        supersetWithPrevious: _superset,
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
    Widget numberRow(String label, String key, TextEditingController c) {
      return FormRow(
        label: label,
        child: RowTextField(
          key: Key(key),
          controller: c,
          placeholder: '—',
          keyboardType: TextInputType.number,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardTextField(
          key: const Key('exerciseName'),
          controller: _name,
          placeholder: 'Ejercicio',
          autofocus: widget.initial == null,
        ),
        const SizedBox(height: 12),
        CardGroup(
          children: [
            numberRow('Series de aproximación', 'warmupSets', _warmup),
            numberRow('Series efectivas', 'workSets', _sets),
            numberRow('Repeticiones mínimas', 'repsMin', _repsMin),
            numberRow('Repeticiones máximas', 'repsMax', _repsMax),
            FormRow(
              label: 'Biserie con el anterior',
              child: CupertinoSwitch(
                value: _superset,
                onChanged: (value) => setState(() => _superset = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CardTextField(
          key: const Key('repsNote'),
          controller: _repsNote,
          placeholder: 'Otro objetivo (al fallo, 30 segundos…)',
        ),
        const SizedBox(height: 12),
        CardTextField(
          key: const Key('exerciseNote'),
          controller: _note,
          placeholder: 'Indicaciones (opcional)',
          maxLines: 3,
        ),
        if (_error != null) FormError(_error!),
        FormActions(
          saveLabel: widget.initial == null
              ? 'Guardar ejercicio'
              : 'Guardar cambios',
          onSave: _save,
          deleteLabel: 'Borrar ejercicio',
          onDelete: widget.onDelete == null ? null : _delete,
        ),
      ],
    );
  }
}
