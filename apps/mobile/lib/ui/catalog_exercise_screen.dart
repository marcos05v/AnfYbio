import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/catalog.dart';
import '../catalog/catalog_exercise.dart';
import 'exercise_images_view.dart';
import 'theme.dart';
import 'widgets.dart';

/// Ficha de un ejercicio del catálogo: fotos, músculos, equipo e
/// instrucciones en español.
class CatalogExerciseScreen extends ConsumerWidget {
  const CatalogExerciseScreen({
    super.key,
    required this.catalogId,
    this.onChange,
    this.onUnlink,
  });

  final String catalogId;

  /// Si se indican, la ficha ofrece cambiar o quitar el enlace.
  final VoidCallback? onChange;
  final Future<void> Function()? onUnlink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(catalogExerciseProvider(catalogId)).value;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Ejercicio'),
        previousPageTitle: 'Atrás',
        border: null,
        trailing: onChange == null
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showMenu(context),
                child: const Icon(
                  CupertinoIcons.ellipsis_circle,
                  semanticLabel: 'Opciones del enlace',
                ),
              ),
      ),
      child: SafeArea(
        child: exercise == null
            ? const Center(child: CupertinoActivityIndicator())
            : _Body(exercise: exercise),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('change'),
            child: const Text('Elegir otro ejercicio'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop('unlink'),
            child: const Text('Quitar enlace'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'change') {
      Navigator.of(context).pop();
      onChange!();
    } else if (action == 'unlink') {
      final navigator = Navigator.of(context);
      await onUnlink!();
      navigator.pop();
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.exercise});

  final CatalogExercise exercise;

  @override
  Widget build(BuildContext context) {
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );
    final details = [
      ?equipmentLabels[exercise.equipment],
      ?levelLabels[exercise.level],
      ?mechanicLabels[exercise.mechanic],
      ?forceLabels[exercise.force],
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(screenPadding, 8, screenPadding, 32),
      children: [
        ExerciseImagesView(images: exercise.images),
        const SizedBox(height: 16),
        Text(
          exercise.name,
          style: textStyle(context, size: 24, weight: FontWeight.w700),
        ),
        Text(exercise.nameEn, style: secondary),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final muscle in exercise.primaryMuscles)
              _Chip(muscleLabels[muscle] ?? muscle, primary: true),
            for (final muscle in exercise.secondaryMuscles)
              _Chip(muscleLabels[muscle] ?? muscle),
          ],
        ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(details.join(' · '), style: secondary),
        ],
        const SectionHeader('Cómo hacerlo'),
        CardGroup(
          children: [
            for (final (index, step) in exercise.instructions.indexed)
              if (step.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${index + 1}',
                          style: textStyle(
                            context,
                            weight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(step, style: textStyle(context, size: 15)),
                      ),
                    ],
                  ),
                ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(
            'Fotos e instrucciones de free-exercise-db (dominio público).',
            style: secondary,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.primary = false});

  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final accent = resolveColor(context, accentColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primary
            ? accent.withValues(alpha: 0.14)
            : resolveColor(context, cardColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textStyle(
          context,
          size: 13,
          weight: FontWeight.w600,
          color: primary ? accentColor : CupertinoColors.secondaryLabel,
        ),
      ),
    );
  }
}
