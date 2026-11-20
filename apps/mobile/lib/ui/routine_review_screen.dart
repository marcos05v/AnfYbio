import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/routine.dart';
import '../import/routine_parser.dart';
import 'catalog_link_screens.dart';
import 'routine_exercise_form.dart';
import 'routine_widgets.dart';
import 'theme.dart';
import 'widgets.dart';

/// Revisión obligatoria de una rutina leída de un PDF, antes de guardarla.
/// Cada ejercicio se puede corregir o quitar; nada se guarda hasta pulsar
/// "Guardar rutina".
class RoutineReviewScreen extends ConsumerStatefulWidget {
  const RoutineReviewScreen({
    super.key,
    required this.userId,
    required this.parsed,
  });

  final String userId;
  final ParsedRoutine parsed;

  @override
  ConsumerState<RoutineReviewScreen> createState() =>
      _RoutineReviewScreenState();
}

class _RoutineReviewScreenState extends ConsumerState<RoutineReviewScreen> {
  late RoutineDraft _draft = widget.parsed.draft;
  bool _saving = false;

  int get _pending => _draft.exercises.where((e) => e.warning != null).length;

  /// Sustituye (o quita, con `null`) un ejercicio del borrador.
  void _replace(int day, int index, RoutineExerciseDraft? replacement) {
    setState(() {
      _draft = _draft.copyWith(
        days: [
          for (final (di, d) in _draft.days.indexed)
            di != day
                ? d
                : d.copyWith(
                    exercises: [
                      for (final (ei, e) in d.exercises.indexed)
                        if (ei != index) e else ?replacement,
                    ],
                  ),
        ],
      );
    });
  }

  Future<void> _save() async {
    if (_pending > 0) {
      final proceed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(
            _pending == 1
                ? 'Queda 1 ejercicio por revisar'
                : 'Quedan $_pending ejercicios por revisar',
          ),
          content: const Text(
            'Puedes guardarla así y corregirla después desde la rutina.',
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
    await ref
        .read(routineRepositoryProvider)
        .saveRoutine(widget.userId, _draft);
    // Recién importada, se pasa directo a enlazar sus ejercicios con el
    // catálogo (los nombres ya confirmados antes se enlazan solos).
    navigator.pushReplacement(
      CupertinoPageRoute<void>(
        builder: (_) => LinkReviewScreen(userId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    final done = pending == 0;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Revisar rutina'),
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
                    '${_draft.days.length} ${_draft.days.length == 1 ? 'día' : 'días'} · '
                    '${_draft.exercises.length} ejercicios',
                    style: textStyle(
                      context,
                      size: 15,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
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
                          size: 24,
                          color: resolveColor(
                            context,
                            done
                                ? CupertinoColors.systemGreen
                                : CupertinoColors.systemOrange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            done
                                ? 'No hay ejercicios marcados. Compara con tu '
                                      'PDF antes de guardar.'
                                : pending == 1
                                ? 'Hay 1 ejercicio que no se entendió. Tócalo '
                                      'para corregirlo.'
                                : 'Hay $pending ejercicios que no se '
                                      'entendieron. Tócalos para corregirlos.',
                            style: textStyle(context, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final warning in widget.parsed.warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        warning,
                        style: textStyle(
                          context,
                          size: 13,
                          weight: FontWeight.w500,
                          color: CupertinoColors.systemOrange,
                        ),
                      ),
                    ),
                  for (final (dayIndex, day) in _draft.days.indexed) ...[
                    SectionHeader('Día ${dayIndex + 1} · ${day.name}'),
                    RoutineExerciseList(
                      entries: [
                        for (final (index, exercise) in day.exercises.indexed)
                          RoutineEntry(
                            name: exercise.name,
                            target: formatExerciseTarget(
                              warmupSets: exercise.warmupSets,
                              workSets: exercise.workSets,
                              repsMin: exercise.repsMin,
                              repsMax: exercise.repsMax,
                              repsNote: exercise.repsNote,
                            ),
                            note: exercise.note,
                            supersetWithPrevious: exercise.supersetWithPrevious,
                            warning: exercise.warning,
                            onTap: () => showAppSheet<void>(
                              context,
                              title: 'Corregir ejercicio',
                              builder: (_) => RoutineExerciseForm(
                                initial: exercise,
                                // El ejercicio corregido ya no lleva aviso.
                                onSave: (edited) async =>
                                    _replace(dayIndex, index, edited),
                                onDelete: () async =>
                                    _replace(dayIndex, index, null),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            BottomActionBar(
              child: PrimaryButton(
                label: 'Guardar rutina',
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
