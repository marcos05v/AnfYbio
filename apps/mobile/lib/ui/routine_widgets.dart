import 'package:flutter/cupertino.dart';

import '../domain/routine.dart';
import 'theme.dart';
import 'widgets.dart';

/// Indicaciones generales de la rutina: descansos, calentamiento, cómo
/// progresar.
class RoutineNotesCard extends StatelessWidget {
  const RoutineNotesCard(this.notes, {super.key});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('routineNotes'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: resolveColor(context, cardColor),
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.info_circle,
            size: 20,
            color: resolveColor(context, CupertinoColors.secondaryLabel),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notes,
              style: textStyle(
                context,
                size: 14,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta "Básico · descansa 2–3 min" o "Accesorio · descansa 60–90 s".
class ExerciseRoleTag extends StatelessWidget {
  const ExerciseRoleTag({super.key, required this.role, this.rest});

  final ExerciseRole role;
  final String? rest;

  @override
  Widget build(BuildContext context) {
    final compound = role == ExerciseRole.compound;
    final color = compound ? accentColor : CupertinoColors.secondaryLabel;
    return Row(
      key: const Key('exerciseRole'),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: resolveColor(context, color)),
          ),
          child: Text(
            exerciseRoleLabel(role),
            style: textStyle(
              context,
              size: 12,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        if (rest != null) ...[
          const SizedBox(width: 6),
          Icon(
            CupertinoIcons.timer,
            size: 14,
            color: resolveColor(context, CupertinoColors.secondaryLabel),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              'descansa $rest',
              style: textStyle(
                context,
                size: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Básico" o "Accesorio".
String exerciseRoleLabel(ExerciseRole role) => switch (role) {
  ExerciseRole.compound => 'Básico',
  ExerciseRole.accessory => 'Accesorio',
};

/// Un ejercicio de la rutina tal como se muestra en una lista.
class RoutineEntry {
  const RoutineEntry({
    required this.name,
    required this.target,
    required this.supersetWithPrevious,
    this.note,
    this.role,
    this.rest,
    this.warning,
    this.onTap,
    this.trailing,
  });

  final String name;

  /// Básico o accesorio; nulo si no se sabe.
  final ExerciseRole? role;

  /// Descanso entre series que le toca: "2–3 min".
  final String? rest;

  /// Objetivo ya formateado: "2 aprox. + 4 × 8–12".
  final String target;
  final bool supersetWithPrevious;
  final String? note;

  /// Lo que la lectura no entendió; se muestra en naranja.
  final String? warning;
  final VoidCallback? onTap;

  /// Algo a la derecha de la fila, como el acceso al catálogo.
  final Widget? trailing;
}

/// Los ejercicios de un día. Los sueltos van juntos en una tarjeta; cada
/// biserie va en su propio bloque, con sus ejercicios marcados A y B.
class RoutineExerciseList extends StatelessWidget {
  const RoutineExerciseList({super.key, required this.entries});

  final List<RoutineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    var loose = <Widget>[];

    void flushLoose() {
      if (loose.isEmpty) return;
      sections.add(CardGroup(children: loose));
      loose = [];
    }

    for (final block in groupSupersets(
      entries,
      (e) => e.supersetWithPrevious,
    )) {
      if (block.length == 1) {
        loose.add(_RoutineExerciseTile(entry: block.single));
      } else {
        flushLoose();
        sections.add(
          SupersetBlock(
            children: [
              for (final (index, entry) in block.indexed)
                _RoutineExerciseTile(
                  entry: entry,
                  marker: supersetLetter(index),
                  // Se descansa al terminar la vuelta, no entre ejercicios.
                  showRest: index == block.length - 1,
                ),
            ],
          ),
        );
      }
    }
    flushLoose();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, section) in sections.indexed) ...[
          if (index > 0) const SizedBox(height: 10),
          section,
        ],
      ],
    );
  }
}

/// Letra de un ejercicio dentro de su biserie: A, B, C…
String supersetLetter(int index) => String.fromCharCode(65 + index);

/// Bloque que agrupa los ejercicios de una biserie: borde de color, el rótulo
/// "Biserie" arriba y los ejercicios dentro, separados por una línea.
class SupersetBlock extends StatelessWidget {
  const SupersetBlock({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final accent = resolveColor(context, accentColor);
    return Container(
      decoration: BoxDecoration(
        color: resolveColor(context, cardColor),
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: accent, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.arrow_2_squarepath,
                  size: 15,
                  color: resolveColor(context, onAccentColor),
                ),
                const SizedBox(width: 7),
                Text(
                  'Biserie',
                  style: textStyle(
                    context,
                    size: 13,
                    weight: FontWeight.w600,
                    color: onAccentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Uno tras otro, sin descanso',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle(context, size: 12, color: onAccentColor),
                  ),
                ),
              ],
            ),
          ),
          for (final (index, child) in children.indexed) ...[
            if (index > 0)
              Container(
                height: 0.5,
                margin: const EdgeInsets.only(left: 16),
                color: resolveColor(context, CupertinoColors.separator),
              ),
            child,
          ],
        ],
      ),
    );
  }
}

/// Círculo con la letra de un ejercicio dentro de su biserie.
class SupersetMarker extends StatelessWidget {
  const SupersetMarker(this.letter, {super.key});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final accent = resolveColor(context, accentColor);
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Text(
        letter,
        style: textStyle(
          context,
          size: 12,
          weight: FontWeight.w700,
          color: accentColor,
        ).copyWith(height: 1),
      ),
    );
  }
}

class _RoutineExerciseTile extends StatelessWidget {
  const _RoutineExerciseTile({
    required this.entry,
    this.marker,
    this.showRest = true,
  });

  final RoutineEntry entry;
  final bool showRest;

  /// Letra dentro de la biserie; nula si el ejercicio va suelto.
  final String? marker;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (marker != null) ...[
            SupersetMarker(marker!),
            const SizedBox(width: 12),
          ],
          if (entry.warning != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                CupertinoIcons.exclamationmark_circle_fill,
                size: 20,
                color: resolveColor(context, CupertinoColors.systemOrange),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: textStyle(context, weight: FontWeight.w600),
                ),
                if (entry.target.isNotEmpty)
                  Text(
                    entry.target,
                    style: textStyle(
                      context,
                      size: 15,
                      weight: FontWeight.w500,
                      color: accentColor,
                    ),
                  ),
                if (entry.role case final role?) ...[
                  const SizedBox(height: 4),
                  ExerciseRoleTag(
                    role: role,
                    rest: showRest ? entry.rest : null,
                  ),
                ],
                if (entry.note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.note!,
                    style: textStyle(
                      context,
                      size: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
                if (entry.warning != null)
                  Text(
                    entry.warning!,
                    style: textStyle(
                      context,
                      size: 13,
                      weight: FontWeight.w500,
                      color: CupertinoColors.systemOrange,
                    ),
                  ),
              ],
            ),
          ),
          if (entry.trailing case final trailing?) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
    return entry.onTap == null
        ? content
        : CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: entry.onTap,
            child: content,
          );
  }
}
