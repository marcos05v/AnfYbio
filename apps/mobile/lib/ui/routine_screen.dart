import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/catalog.dart';
import '../app/plan_import.dart';
import '../app/providers.dart';
import '../data/database.dart';
import '../data/repositories/routine_repository.dart';
import '../catalog/catalog_exercise.dart';
import '../catalog/exercise_matching.dart';
import '../domain/routine.dart';
import '../import/routine_parser.dart';
import 'catalog_link_screens.dart';
import 'routine_exercise_form.dart';
import 'routine_review_screen.dart';
import 'routine_widgets.dart';
import 'theme.dart';
import 'widgets.dart';

/// La rutina de entrenamiento: sus días y lo que toca en cada uno.
class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key, required this.user});

  final User user;

  Future<String?> _askName(
    BuildContext context, {
    required String title,
    required String placeholder,
    String initial = '',
    String action = 'Guardar',
  }) async {
    final controller = TextEditingController(text: initial);
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            key: const Key('nameField'),
            controller: controller,
            placeholder: placeholder,
            autofocus: true,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
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
            child: Text(action),
          ),
        ],
      ),
    );
    controller.dispose();
    return name;
  }

  Future<void> _explain(BuildContext context, String title, String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  /// Elige un PDF, lo interpreta y abre la revisión antes de guardar nada.
  Future<void> _importPdf(BuildContext context, WidgetRef ref) async {
    final PickedPdf? picked;
    try {
      picked = await ref.read(pdfTextPickerProvider)();
    } catch (_) {
      if (context.mounted) {
        await _explain(
          context,
          'No se pudo leer el PDF',
          'Prueba con otro archivo.',
        );
      }
      return;
    }
    if (picked == null || !context.mounted) return;

    final parsed = parseRoutine(picked.text, fileName: picked.fileName);
    if (parsed.draft.exercises.isEmpty) {
      await _explain(
        context,
        'No se encontró una rutina',
        picked.text.trim().isEmpty
            ? 'El PDF no contiene texto; puede ser una imagen escaneada. '
                  'Captura la rutina a mano.'
            : 'El PDF no tiene el formato esperado. Captura la rutina a mano.',
      );
      return;
    }
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => RoutineReviewScreen(userId: user.id, parsed: parsed),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _askName(
      context,
      title: 'Nueva rutina',
      placeholder: 'Nombre de la rutina',
      initial: 'Mi rutina',
      action: 'Crear',
    );
    if (name == null) return;
    await ref
        .read(routineRepositoryProvider)
        .saveRoutine(user.id, RoutineDraft(name: name));
  }

  /// Descarga las fotos de los ejercicios ya enlazados de la rutina.
  Future<void> _downloadImages(BuildContext context, WidgetRef ref) async {
    final view = ref.read(activeRoutineProvider(user.id)).value;
    final aliases =
        ref.read(exerciseAliasesProvider(user.id)).value ?? const {};
    final ids = {
      for (final day in view?.days ?? const <RoutineDayView>[])
        for (final exercise in day.exercises)
          ?aliases[normalizeText(exercise.name)],
    }.where(isCatalogLink).toList();
    if (ids.isEmpty) {
      return _explain(
        context,
        'Aún no hay fotos que descargar',
        'Primero enlaza los ejercicios de tu rutina con el catálogo.',
      );
    }
    await showAppSheet<void>(
      context,
      title: 'Fotos de la rutina',
      builder: (_) => DownloadImagesSheet(catalogIds: ids),
    );
  }

  Future<void> _showMenu(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(routine.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('images'),
            child: const Text('Descargar fotos de la rutina'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('import'),
            child: const Text('Importar otra rutina (PDF)'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop('delete'),
            child: const Text('Borrar rutina'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'import') return _importPdf(context, ref);
    if (action == 'images') return _downloadImages(context, ref);
    if (action != 'delete') return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('¿Borrar la rutina?'),
        content: const Text(
          'Se borrarán sus días y ejercicios. Las sesiones que ya '
          'registraste se conservan.',
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
      await ref.read(routineRepositoryProvider).deleteRoutine(routine.id);
    }
  }

  /// Renombrar o borrar un día.
  Future<void> _editDay(
    BuildContext context,
    WidgetRef ref,
    RoutineDay day,
  ) async {
    final repository = ref.read(routineRepositoryProvider);
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(day.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('rename'),
            child: const Text('Cambiar nombre'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop('delete'),
            child: const Text('Borrar día'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'rename') {
      final name = await _askName(
        context,
        title: 'Nombre del día',
        placeholder: 'Pecho y tríceps',
        initial: day.name,
      );
      if (name != null) await repository.updateDay(day.id, name: name);
    } else if (action == 'delete') {
      await repository.deleteDay(day.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeRoutineProvider(user.id));
    final view = state.value;
    final repository = ref.read(routineRepositoryProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Rutina'),
        previousPageTitle: 'Atrás',
        border: null,
        trailing: view == null
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showMenu(context, ref, view.routine),
                child: const Icon(
                  CupertinoIcons.ellipsis_circle,
                  semanticLabel: 'Opciones de la rutina',
                ),
              ),
      ),
      child: SafeArea(
        child: view == null
            ? state.isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _NoRoutine(
                      onImport: () => _importPdf(context, ref),
                      onCreate: () => _create(context, ref),
                    )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  screenPadding,
                  8,
                  screenPadding,
                  32,
                ),
                children: [
                  Text(
                    view.routine.name,
                    style: textStyle(
                      context,
                      size: 26,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${view.days.length} ${view.days.length == 1 ? 'día' : 'días'} · '
                    '${view.days.expand((d) => d.exercises).length} ejercicios',
                    style: textStyle(
                      context,
                      size: 15,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  _PendingLinksBanner(user: user, routine: view),
                  for (final (index, day) in view.days.indexed)
                    _DaySection(
                      userId: user.id,
                      number: index + 1,
                      day: day,
                      onEditDay: () => _editDay(context, ref, day.day),
                    ),
                  const SizedBox(height: 20),
                  OutlineAddButton(
                    label: 'Agregar día',
                    onPressed: () async {
                      final name = await _askName(
                        context,
                        title: 'Nuevo día',
                        placeholder: 'Pecho y tríceps',
                      );
                      if (name != null) {
                        await repository.addDay(view.routine.id, name: name);
                      }
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

/// Cuántos ejercicios de la rutina faltan por enlazar con el catálogo, con
/// acceso a la revisión.
class _PendingLinksBanner extends ConsumerWidget {
  const _PendingLinksBanner({required this.user, required this.routine});

  final User user;
  final RoutineView routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aliases =
        ref.watch(exerciseAliasesProvider(user.id)).value ?? const {};
    final pending = {
      for (final day in routine.days)
        for (final exercise in day.exercises)
          if (!aliases.containsKey(normalizeText(exercise.name)))
            normalizeText(exercise.name),
    }.length;
    if (pending == 0) return const SizedBox.shrink();

    final accent = resolveColor(context, accentColor);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: CupertinoButton(
        key: const Key('pendingLinks'),
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => LinkReviewScreen(userId: user.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.photo_on_rectangle, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pending == 1
                          ? '1 ejercicio sin enlazar'
                          : '$pending ejercicios sin enlazar',
                      style: textStyle(context, weight: FontWeight.w600),
                    ),
                    Text(
                      'Enlázalos con el catálogo para ver sus fotos e '
                      'instrucciones.',
                      style: textStyle(
                        context,
                        size: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_forward, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoRoutine extends StatelessWidget {
  const _NoRoutine({required this.onImport, required this.onCreate});

  final VoidCallback onImport;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(screenPadding + 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.calendar,
            size: 44,
            color: resolveColor(context, CupertinoColors.tertiaryLabel),
          ),
          const SizedBox(height: 14),
          Text(
            'Aún no tienes una rutina',
            style: textStyle(context, size: 20, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Con una rutina, cada sesión de fuerza te muestra lo que toca: '
            'ejercicios, series y repeticiones.',
            textAlign: TextAlign.center,
            style: textStyle(
              context,
              size: 15,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Importar desde PDF',
            icon: CupertinoIcons.doc_text,
            onPressed: onImport,
          ),
          const SizedBox(height: 10),
          SecondaryButton(label: 'Crear rutina a mano', onPressed: onCreate),
        ],
      ),
    );
  }
}

class _DaySection extends ConsumerWidget {
  const _DaySection({
    required this.userId,
    required this.number,
    required this.day,
    required this.onEditDay,
  });

  final String userId;
  final int number;
  final RoutineDayView day;
  final VoidCallback onEditDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(routineRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                // El título del día se toca para renombrarlo o borrarlo.
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  alignment: Alignment.centerLeft,
                  onPressed: onEditDay,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Día $number',
                        style: textStyle(
                          context,
                          size: 13,
                          weight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                      Text(
                        day.day.name,
                        style: textStyle(
                          context,
                          size: 20,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 32),
                onPressed: () => showAppSheet<void>(
                  context,
                  title: 'Nuevo ejercicio',
                  builder: (_) => RoutineExerciseForm(
                    onSave: (draft) =>
                        repository.addExercise(day.day.id, draft),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.plus_circle_fill, size: 20),
                    SizedBox(width: 5),
                    Text('Ejercicio'),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (day.exercises.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: resolveColor(context, cardColor),
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            child: Text(
              'Sin ejercicios.',
              style: textStyle(context, color: CupertinoColors.secondaryLabel),
            ),
          )
        else
          RoutineExerciseList(
            entries: [
              for (final exercise in day.exercises)
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
                  trailing: CatalogLinkButton(
                    userId: userId,
                    routineExercise: exercise,
                  ),
                  onTap: () => showAppSheet<void>(
                    context,
                    title: 'Editar ejercicio',
                    builder: (_) => RoutineExerciseForm(
                      initial: RoutineExerciseDraft(
                        name: exercise.name,
                        groupLabel: exercise.groupLabel,
                        warmupSets: exercise.warmupSets,
                        workSets: exercise.workSets,
                        repsMin: exercise.repsMin,
                        repsMax: exercise.repsMax,
                        repsNote: exercise.repsNote,
                        supersetWithPrevious: exercise.supersetWithPrevious,
                        note: exercise.note,
                      ),
                      onSave: (draft) =>
                          repository.updateExercise(exercise.id, draft),
                      onDelete: () => repository.deleteExercise(exercise.id),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
