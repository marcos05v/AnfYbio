import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/catalog.dart';
import '../app/providers.dart';
import '../catalog/exercise_matching.dart';
import '../data/database.dart';
import '../domain/one_rep_max.dart';
import '../domain/routine.dart';
import '../domain/weight.dart';
import 'catalog_exercise_screen.dart';
import 'formatting.dart';
import 'routine_widgets.dart';
import 'session_scaffold.dart';
import 'theme.dart';
import 'widgets.dart';

/// Valores con los que se abre el formulario de una serie.
typedef _Prefill = ({
  String exerciseId,
  WeightUnit unit,
  String weight,
  String reps,
  String rpe,
  bool isWarmup,
});

/// Registro de una sesión de fuerza: series agrupadas por ejercicio.
class StrengthSessionScreen extends ConsumerStatefulWidget {
  const StrengthSessionScreen({
    super.key,
    required this.userId,
    required this.sessionId,
  });

  final String userId;
  final String sessionId;

  @override
  ConsumerState<StrengthSessionScreen> createState() =>
      _StrengthSessionScreenState();
}

class _StrengthSessionScreenState extends ConsumerState<StrengthSessionScreen> {
  /// Abre el formulario de una serie.
  ///
  /// Con [after] (la última serie de un ejercicio) propone ese mismo
  /// ejercicio, peso y repeticiones: repetir la serie es solo guardar.
  Future<void> _addSet({StrengthSet? after}) {
    return showAppSheet<void>(
      context,
      title: 'Nueva serie',
      builder: (_) => _AddSetForm(
        userId: widget.userId,
        sessionId: widget.sessionId,
        initial: after == null
            ? null
            : (
                exerciseId: after.exerciseId,
                unit: after.weightUnit,
                weight: formatNumber(after.weight, decimals: 2),
                reps: '${after.reps}',
                rpe: '', // el RPE es de cada serie: no se copia
                isWarmup: after.isWarmup,
              ),
      ),
    );
  }

  /// Abre una serie ya registrada para corregirla o borrarla.
  Future<void> _editSet(StrengthSet set) {
    return showAppSheet<void>(
      context,
      title: 'Editar serie',
      builder: (_) => _AddSetForm(
        userId: widget.userId,
        sessionId: widget.sessionId,
        editing: set,
        initial: (
          exerciseId: set.exerciseId,
          unit: set.weightUnit,
          weight: formatNumber(set.weight, decimals: 2),
          reps: '${set.reps}',
          rpe: set.rpe == null ? '' : formatNumber(set.rpe!),
          isWarmup: set.isWarmup,
        ),
      ),
    );
  }

  /// Agrega una serie a un ejercicio de la rutina. La primera vez enlaza el
  /// ejercicio; propone el peso de la última vez y marca la serie como
  /// aproximación mientras falten las que pide la rutina.
  Future<void> _addRoutineSet(
    RoutineExercise routineExercise,
    List<StrengthSet> sessionSets,
  ) async {
    final exercise = await ref
        .read(routineRepositoryProvider)
        .exerciseFor(routineExercise.id);
    final done = sessionSets.where((s) => s.exerciseId == exercise.id).toList();
    final last =
        done.lastOrNull ??
        await ref.read(trainingRepositoryProvider).lastSetOf(exercise.id);
    if (!mounted) return;

    await showAppSheet<void>(
      context,
      title: 'Nueva serie',
      builder: (_) => _AddSetForm(
        userId: widget.userId,
        sessionId: widget.sessionId,
        initial: (
          exerciseId: exercise.id,
          unit: last?.weightUnit ?? exercise.defaultUnit,
          weight: last == null ? '' : formatNumber(last.weight, decimals: 2),
          reps: last == null ? '' : '${last.reps}',
          rpe: '',
          isWarmup: nextSetIsWarmup(
            warmupSets: routineExercise.warmupSets,
            loggedWarmups: done.where((s) => s.isWarmup).length,
          ),
        ),
      ),
    );
  }

  Widget _addSetButton(VoidCallback onPressed) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 32),
      onPressed: onPressed,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.plus_circle_fill, size: 20),
          SizedBox(width: 5),
          Text('Serie'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sets =
        ref.watch(strengthSetsProvider(widget.sessionId)).value ?? const [];
    final exercises =
        ref.watch(exercisesProvider(widget.userId)).value ?? const [];
    final names = {for (final e in exercises) e.id: e.name};

    // Si la sesión sigue un día de rutina, se muestra lo que toca.
    final routineDayId = ref
        .watch(sessionProvider(widget.sessionId))
        .value
        ?.routineDayId;
    final routineDay = routineDayId == null
        ? null
        : ref.watch(routineDayProvider(routineDayId)).value;
    final planned = routineDay?.exercises ?? const <RoutineExercise>[];
    final plannedIds = {for (final e in planned) ?e.exerciseId};

    // Agrupa por ejercicio conservando el orden en que apareció cada uno.
    final groups = <String, List<StrengthSet>>{};
    for (final set in sets) {
      groups.putIfAbsent(set.exerciseId, () => []).add(set);
    }

    final aliases =
        ref.watch(exerciseAliasesProvider(widget.userId)).value ?? const {};
    Widget plannedExercise(RoutineExercise routineExercise, {String? marker}) {
      final done = groups[routineExercise.exerciseId] ?? const <StrengthSet>[];
      final catalogId = aliases[normalizeText(routineExercise.name)];
      return _PlannedExercise(
        exercise: routineExercise,
        marker: marker,
        rows: _setRows(done),
        effectiveDone: done.where((s) => !s.isWarmup).length,
        addButton: _addSetButton(() => _addRoutineSet(routineExercise, sets)),
        onShowCatalog: catalogId == null
            ? null
            : () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => CatalogExerciseScreen(catalogId: catalogId),
                ),
              ),
      );
    }

    return SessionScaffold(
      sessionId: widget.sessionId,
      title: 'Fuerza',
      summary: [
        ?routineDay?.day.name,
        switch (sets.length) {
          0 => null,
          1 => '1 serie',
          final n => '$n series',
        },
      ].nonNulls.join(' · '),
      isEmpty: sets.isEmpty && planned.isEmpty,
      emptyIcon: CupertinoIcons.square_list,
      emptyTitle: 'Sin series todavía',
      emptyMessage: 'Toca "Agregar ejercicio" para registrar la primera.',
      actionLabel: 'Agregar ejercicio',
      onAction: _addSet,
      children: [
        // Los ejercicios sueltos van uno tras otro; cada biserie, en su
        // bloque, con sus ejercicios marcados A y B.
        for (final block in groupSupersets(
          planned,
          (e) => e.supersetWithPrevious,
        ))
          if (block.length == 1)
            plannedExercise(block.single)
          else
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: SupersetBlock(
                children: [
                  for (final (index, routineExercise) in block.indexed)
                    plannedExercise(
                      routineExercise,
                      marker: supersetLetter(index),
                    ),
                ],
              ),
            ),
        // Lo registrado que no estaba en la rutina (o toda la sesión libre).
        for (final entry in groups.entries)
          if (!plannedIds.contains(entry.key)) ...[
            SectionHeader(
              names[entry.key] ?? '…',
              trailing: _addSetButton(() => _addSet(after: entry.value.last)),
            ),
            CardGroup(children: _setRows(entry.value)),
          ],
      ],
    );
  }

  /// Las series efectivas se numeran 1, 2, 3…; las de calentamiento no
  /// consumen número y llevan su propia marca.
  List<Widget> _setRows(List<StrengthSet> sets) {
    var number = 0;
    return [
      for (final set in sets)
        _SetRow(
          number: set.isWarmup ? null : ++number,
          set: set,
          onTap: () => _editSet(set),
        ),
    ];
  }
}

/// Un ejercicio que la rutina pide en esta sesión: su objetivo, el avance
/// y las series ya registradas.
class _PlannedExercise extends StatelessWidget {
  const _PlannedExercise({
    required this.exercise,
    required this.rows,
    required this.effectiveDone,
    required this.addButton,
    this.marker,
    this.onShowCatalog,
  });

  /// Abre la ficha del catálogo, si el ejercicio está enlazado.
  final VoidCallback? onShowCatalog;

  final RoutineExercise exercise;
  final List<Widget> rows;

  /// Series efectivas ya registradas en esta sesión.
  final int effectiveDone;
  final Widget addButton;

  /// Letra dentro de su biserie; nula si el ejercicio va suelto.
  final String? marker;

  @override
  Widget build(BuildContext context) {
    final inBlock = marker != null;
    final target = formatExerciseTarget(
      warmupSets: exercise.warmupSets,
      workSets: exercise.workSets,
      repsMin: exercise.repsMin,
      repsMax: exercise.repsMax,
      repsNote: exercise.repsNote,
    );
    final workSets = exercise.workSets;
    final complete = workSets != null && effectiveDone >= workSets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // Dentro de un bloque de biserie el margen lo pone el bloque.
          padding: inBlock
              ? const EdgeInsets.fromLTRB(16, 12, 12, 10)
              : const EdgeInsets.only(top: 22, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inBlock) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: SupersetMarker(marker!),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: textStyle(
                        context,
                        size: inBlock ? 17 : 18,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        if (target.isNotEmpty) target,
                        if (workSets != null)
                          complete
                              ? 'completo'
                              : '$effectiveDone de $workSets hechas',
                      ].join(' · '),
                      style: textStyle(
                        context,
                        size: 14,
                        weight: FontWeight.w500,
                        color: complete
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              if (onShowCatalog != null)
                CupertinoButton(
                  key: Key('howTo-${exercise.id}'),
                  padding: const EdgeInsets.only(right: 6),
                  minimumSize: const Size(36, 32),
                  onPressed: onShowCatalog,
                  child: const Icon(
                    CupertinoIcons.photo,
                    size: 20,
                    semanticLabel: 'Cómo se hace',
                  ),
                ),
              addButton,
            ],
          ),
        ),
        if (rows.isNotEmpty)
          inBlock
              // En el bloque las series van sobre el fondo de la app, para
              // distinguirse de la tarjeta que las contiene.
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: resolveColor(
                        context,
                        CupertinoColors.systemBackground,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: rows),
                  ),
                )
              : CardGroup(children: rows),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.number, required this.set, required this.onTap});

  final VoidCallback onTap;

  /// Número de serie efectiva; `null` si es de calentamiento.
  final int? number;
  final StrengthSet set;

  @override
  Widget build(BuildContext context) {
    final number = this.number;
    final oneRepMax = number == null
        ? null
        : estimateOneRepMaxKg(
            weight: set.weight,
            unit: set.weightUnit,
            reps: set.reps,
          );

    return RecordRow(
      marker: number == null ? const WarmupBadge() : RowNumber(number),
      muted: number == null,
      onTap: onTap,
      title:
          '${formatNumber(set.weight, decimals: 2)} ${set.weightUnit.name}'
          ' × ${set.reps}',
      details: [
        [
          if (number == null) 'Calentamiento',
          if (set.rpe != null) 'RPE ${formatNumber(set.rpe!)}',
          if (oneRepMax != null)
            '1RM ≈ ${formatNumber(oneRepMax)} kg'
                '${isReliableForOneRepMax(set.reps) ? '' : ' (poco confiable)'}',
        ].join(' · '),
      ],
    );
  }
}

/// Formulario de una serie. Al guardar, cierra la hoja.
class _AddSetForm extends ConsumerStatefulWidget {
  const _AddSetForm({
    required this.userId,
    required this.sessionId,
    required this.initial,
    this.editing,
  });

  final String userId;
  final String sessionId;
  final _Prefill? initial;

  /// La serie que se está corrigiendo; `null` si se agrega una nueva.
  final StrengthSet? editing;

  @override
  ConsumerState<_AddSetForm> createState() => _AddSetFormState();
}

class _AddSetFormState extends ConsumerState<_AddSetForm> {
  late final _weight = TextEditingController(text: widget.initial?.weight);
  late final _reps = TextEditingController(text: widget.initial?.reps);
  late final _rpe = TextEditingController(text: widget.initial?.rpe);
  late String? _exerciseId = widget.initial?.exerciseId;
  late WeightUnit _unit = widget.initial?.unit ?? WeightUnit.kg;
  late bool _isWarmup = widget.initial?.isWarmup ?? false;
  String? _error;

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _rpe.dispose();
    super.dispose();
  }

  void _selectExercise(Exercise exercise) {
    setState(() {
      _exerciseId = exercise.id;
      _unit = exercise.defaultUnit; // la unidad habitual de ese ejercicio
    });
  }

  Future<void> _pickExercise(List<Exercise> exercises) async {
    const newExercise = 'new';
    final choice = await showCupertinoModalPopup<Object>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Ejercicio'),
        actions: [
          for (final exercise in exercises)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(exercise),
              child: Text(exercise.name),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(newExercise),
            child: const Text('Nuevo ejercicio…'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (!mounted) return;
    if (choice is Exercise) {
      _selectExercise(choice);
    } else if (choice == newExercise) {
      final created = await showCupertinoDialog<Exercise>(
        context: context,
        builder: (_) => _NewExerciseDialog(userId: widget.userId),
      );
      if (created != null) _selectExercise(created);
    }
  }

  Future<void> _save() async {
    final weight = parseNumber(_weight.text);
    final reps = int.tryParse(_reps.text.trim());
    final rpeText = _rpe.text.trim();
    final rpe = rpeText.isEmpty ? null : parseNumber(rpeText);

    String? error;
    if (_exerciseId == null) {
      error = 'Elige un ejercicio.';
    } else if (weight == null || weight < 0) {
      error = 'Escribe el peso (0 si es peso corporal).';
    } else if (reps == null || reps < 0) {
      error = 'Escribe las repeticiones.';
    } else if (rpeText.isNotEmpty && (rpe == null || rpe < 1 || rpe > 10)) {
      error = 'El RPE va de 1 a 10.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final repository = ref.read(trainingRepositoryProvider);
    final editing = widget.editing;
    if (editing == null) {
      await repository.addStrengthSet(
        sessionId: widget.sessionId,
        exerciseId: _exerciseId!,
        weight: weight!,
        weightUnit: _unit,
        reps: reps!,
        rpe: rpe,
        isWarmup: _isWarmup,
      );
    } else {
      await repository.updateStrengthSet(
        editing.id,
        exerciseId: _exerciseId!,
        weight: weight!,
        weightUnit: _unit,
        reps: reps!,
        rpe: rpe,
        isWarmup: _isWarmup,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await ref
        .read(trainingRepositoryProvider)
        .deleteStrengthSet(widget.editing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final exercises =
        ref.watch(exercisesProvider(widget.userId)).value ?? const [];
    final selected = exercises.where((e) => e.id == _exerciseId).firstOrNull;
    const decimal = TextInputType.numberWithOptions(decimal: true);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardGroup(
          children: [
            PickerRow(
              key: const Key('exercise'),
              label: 'Ejercicio',
              value: selected?.name,
              onPressed: () => _pickExercise(exercises),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CardGroup(
          children: [
            FormRow(
              label: 'Peso',
              child: Row(
                children: [
                  Expanded(
                    child: RowTextField(
                      key: const Key('weight'),
                      controller: _weight,
                      placeholder: '0',
                      keyboardType: decimal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  CupertinoSlidingSegmentedControl<WeightUnit>(
                    groupValue: _unit,
                    children: const {
                      WeightUnit.kg: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('kg'),
                      ),
                      WeightUnit.lb: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('lb'),
                      ),
                    },
                    onValueChanged: (unit) {
                      if (unit != null) setState(() => _unit = unit);
                    },
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Repeticiones',
              child: RowTextField(
                key: const Key('reps'),
                controller: _reps,
                placeholder: '0',
                keyboardType: TextInputType.number,
              ),
            ),
            FormRow(
              label: 'RPE',
              child: RowTextField(
                key: const Key('rpe'),
                controller: _rpe,
                placeholder: 'Opcional',
                keyboardType: decimal,
              ),
            ),
            FormRow(
              label: 'Calentamiento',
              child: CupertinoSwitch(
                value: _isWarmup,
                onChanged: (value) => setState(() => _isWarmup = value),
              ),
            ),
          ],
        ),
        if (_error != null) FormError(_error!),
        FormActions(
          saveLabel: widget.editing == null
              ? 'Guardar serie'
              : 'Guardar cambios',
          onSave: _save,
          deleteLabel: 'Borrar serie',
          onDelete: widget.editing == null ? null : _delete,
        ),
      ],
    );
  }
}

class _NewExerciseDialog extends ConsumerStatefulWidget {
  const _NewExerciseDialog({required this.userId});

  final String userId;

  @override
  ConsumerState<_NewExerciseDialog> createState() => _NewExerciseDialogState();
}

class _NewExerciseDialogState extends ConsumerState<_NewExerciseDialog> {
  final _name = TextEditingController();
  WeightUnit _unit = WeightUnit.kg;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    final exercise = await ref
        .read(exerciseRepositoryProvider)
        .createExercise(
          userId: widget.userId,
          name: _name.text,
          defaultUnit: _unit,
        );
    if (mounted) Navigator.of(context).pop(exercise);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Nuevo ejercicio'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(
              key: const Key('exerciseName'),
              controller: _name,
              placeholder: 'Nombre',
              autofocus: true,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<WeightUnit>(
                groupValue: _unit,
                children: const {
                  WeightUnit.kg: Text('Kilogramos'),
                  WeightUnit.lb: Text('Libras'),
                },
                onValueChanged: (unit) {
                  if (unit != null) setState(() => _unit = unit);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
