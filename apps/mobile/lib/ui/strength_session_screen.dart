import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/database.dart';
import '../domain/one_rep_max.dart';
import '../domain/weight.dart';
import 'formatting.dart';

/// Registro de una sesión de fuerza: lista de series y formulario para
/// agregar la siguiente.
class StrengthSessionScreen extends ConsumerWidget {
  const StrengthSessionScreen({
    super.key,
    required this.userId,
    required this.sessionId,
  });

  final String userId;
  final String sessionId;

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    final result = await showDialog<({int minutes, int rpe})>(
      context: context,
      builder: (_) => _FinishDialog(session: session),
    );
    if (result == null) return;
    await ref
        .read(trainingRepositoryProvider)
        .finishSession(
          sessionId,
          durationS: result.minutes * 60,
          sessionRpe: result.rpe,
        );
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar la sesión?'),
        content: const Text('Se borrarán también todas sus series.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // Se sale primero: al borrarse, la sesión deja de existir para esta pantalla.
    if (context.mounted) Navigator.of(context).pop();
    await ref.read(trainingRepositoryProvider).deleteSession(sessionId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(sessionId)).value;
    final sets = ref.watch(strengthSetsProvider(sessionId)).value ?? const [];
    final exercises = ref.watch(exercisesProvider(userId)).value ?? const [];
    final names = {for (final e in exercises) e.id: e.name};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesión de fuerza'),
        actions: [
          if (session != null)
            TextButton(
              onPressed: () => _finish(context, ref, session),
              child: Text(
                session.durationS == null ? 'Terminar' : 'Editar cierre',
              ),
            ),
          IconButton(
            tooltip: 'Borrar sesión',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: sets.isEmpty
                  ? const Center(child: Text('Agrega tu primera serie.'))
                  : ListView.builder(
                      itemCount: sets.length,
                      itemBuilder: (context, index) => _SetTile(
                        set: sets[index],
                        exerciseName: names[sets[index].exerciseId] ?? '…',
                      ),
                    ),
            ),
            const Divider(height: 1),
            _AddSetForm(
              userId: userId,
              sessionId: sessionId,
              exercises: exercises,
            ),
          ],
        ),
      ),
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({required this.set, required this.exerciseName});

  final StrengthSet set;
  final String exerciseName;

  @override
  Widget build(BuildContext context) {
    final oneRepMax = set.isWarmup
        ? null
        : estimateOneRepMaxKg(
            weight: set.weight,
            unit: set.weightUnit,
            reps: set.reps,
          );
    final details = [
      '${formatNumber(set.weight, decimals: 2)} ${set.weightUnit.name} × ${set.reps}',
      if (set.rpe != null) 'RPE ${formatNumber(set.rpe!)}',
      if (oneRepMax != null)
        '1RM ≈ ${formatNumber(oneRepMax)} kg'
            '${isReliableForOneRepMax(set.reps) ? '' : ' (poco confiable)'}',
    ].join(' · ');

    return ListTile(
      dense: true,
      leading: CircleAvatar(radius: 14, child: Text('${set.position}')),
      title: Text(exerciseName),
      subtitle: Text(details),
      trailing: set.isWarmup ? const Chip(label: Text('Calentamiento')) : null,
    );
  }
}

class _AddSetForm extends ConsumerStatefulWidget {
  const _AddSetForm({
    required this.userId,
    required this.sessionId,
    required this.exercises,
  });

  final String userId;
  final String sessionId;
  final List<Exercise> exercises;

  @override
  ConsumerState<_AddSetForm> createState() => _AddSetFormState();
}

class _AddSetFormState extends ConsumerState<_AddSetForm> {
  final _weight = TextEditingController();
  final _reps = TextEditingController();
  final _rpe = TextEditingController();
  String? _exerciseId;
  WeightUnit _unit = WeightUnit.kg;
  bool _isWarmup = false;
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

  Future<void> _newExercise() async {
    final created = await showDialog<Exercise>(
      context: context,
      builder: (_) => _NewExerciseDialog(userId: widget.userId),
    );
    if (created != null) _selectExercise(created);
  }

  Future<void> _add() async {
    final weight = parseNumber(_weight.text);
    final reps = int.tryParse(_reps.text.trim());
    final rpe = _rpe.text.trim().isEmpty ? null : parseNumber(_rpe.text);

    final error = switch ((_exerciseId, weight, reps, rpe)) {
      (null, _, _, _) => 'Elige un ejercicio.',
      (_, null, _, _) => 'Escribe el peso (0 si es peso corporal).',
      (_, final w?, _, _) when w < 0 => 'El peso no puede ser negativo.',
      (_, _, null, _) => 'Escribe las repeticiones.',
      (_, _, final r?, _) when r < 0 =>
        'Las repeticiones no pueden ser negativas.',
      _ when _rpe.text.trim().isNotEmpty && rpe == null => 'RPE no válido.',
      (_, _, _, final e?) when e < 1 || e > 10 => 'El RPE va de 1 a 10.',
      _ => null,
    };
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    await ref
        .read(trainingRepositoryProvider)
        .addStrengthSet(
          sessionId: widget.sessionId,
          exerciseId: _exerciseId!,
          weight: weight!,
          weightUnit: _unit,
          reps: reps!,
          rpe: rpe,
          isWarmup: _isWarmup,
        );
    // Se conservan ejercicio, peso y repeticiones: la siguiente serie suele
    // ser igual o casi igual. Solo se limpia el RPE.
    setState(() {
      _error = null;
      _rpe.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    const numeric = TextInputType.numberWithOptions(decimal: true);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_exerciseId),
                  initialValue: _exerciseId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ejercicio',
                    isDense: true,
                  ),
                  items: [
                    for (final exercise in widget.exercises)
                      DropdownMenuItem(
                        value: exercise.id,
                        child: Text(
                          exercise.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) => _selectExercise(
                    widget.exercises.firstWhere((e) => e.id == id),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Nuevo ejercicio',
                icon: const Icon(Icons.add),
                onPressed: _newExercise,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: numeric,
                  decoration: const InputDecoration(
                    labelText: 'Peso',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<WeightUnit>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                  ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                ],
                selected: {_unit},
                onSelectionChanged: (s) => setState(() => _unit = s.first),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _reps,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Reps',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _rpe,
                  keyboardType: numeric,
                  decoration: const InputDecoration(
                    labelText: 'RPE',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Switch(
                value: _isWarmup,
                onChanged: (v) => setState(() => _isWarmup = v),
              ),
              const Expanded(child: Text('Calentamiento')),
              FilledButton(onPressed: _add, child: const Text('Agregar serie')),
            ],
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
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
    return AlertDialog(
      title: const Text('Nuevo ejercicio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 8),
          const Text('Unidad habitual'),
          const SizedBox(height: 4),
          SegmentedButton<WeightUnit>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
              ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
            ],
            selected: {_unit},
            onSelectionChanged: (s) => setState(() => _unit = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

/// Pide la duración y el RPE de la sesión completa (los dos datos del sRPE).
class _FinishDialog extends StatefulWidget {
  const _FinishDialog({required this.session});

  final Session session;

  @override
  State<_FinishDialog> createState() => _FinishDialogState();
}

class _FinishDialogState extends State<_FinishDialog> {
  late final TextEditingController _minutes;
  late int _rpe;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    // Propone el tiempo transcurrido desde el inicio; se puede corregir.
    final elapsed = DateTime.now().toUtc().difference(session.startedAt);
    final minutes = session.durationS != null
        ? session.durationS! ~/ 60
        : elapsed.inMinutes.clamp(1, 600);
    _minutes = TextEditingController(text: '$minutes');
    _rpe = session.sessionRpe ?? 7;
  }

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  void _save() {
    final minutes = int.tryParse(_minutes.text.trim());
    if (minutes == null || minutes < 1) return;
    Navigator.of(context).pop((minutes: minutes, rpe: _rpe));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Terminar sesión'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Duración (minutos)'),
          ),
          const SizedBox(height: 16),
          Text('Esfuerzo de toda la sesión: $_rpe de 10'),
          Slider(
            value: _rpe.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$_rpe',
            onChanged: (v) => setState(() => _rpe = v.round()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
