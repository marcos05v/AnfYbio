import '../domain/routine.dart';

/// Resultado de leer una rutina: el borrador y lo que no se pudo interpretar.
class ParsedRoutine {
  const ParsedRoutine({required this.draft, required this.warnings});

  final RoutineDraft draft;

  /// Problemas generales del documento (los de un ejercicio van en su
  /// [RoutineExerciseDraft.warning]).
  final List<String> warnings;

  /// Cuántas cosas debe revisar el usuario antes de guardar.
  int get warningCount =>
      warnings.length + draft.exercises.where((e) => e.warning != null).length;
}

/// Convierte el texto de una rutina de entrenamiento en un borrador
/// (ADR-0010). Espera esta estructura:
///
/// ```
/// Título de la rutina
/// Día 1: Pecho y Tríceps
/// • Pecho                                  ← grupo muscular
/// ◦ Press de banca: 2 series de aproximación + 4 series efectivas de 8 a 12
///   repeticiones como ejercicio principal.
/// • Biserie:                               ← los dos siguientes van juntos
/// ◦ Ejercicio A: 4 series de 10 a 12 repeticiones
/// ◦ Combinado con: Ejercicio B: 3 series de 12 repeticiones
/// ```
///
/// Igual que el lector del plan de alimentación, no adivina: lo que no
/// reconoce lo conserva y lo marca para la revisión.
ParsedRoutine parseRoutine(String text, {String? fileName}) {
  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final warnings = <String>[];
  final days = <_Day>[];
  String? name;
  String? group;
  // Cuántos de los próximos ejercicios pertenecen a la biserie abierta.
  var supersetSlots = 0;

  for (final line in _joinContinuations(lines)) {
    final dayMatch = _dayHeader.firstMatch(line);
    if (dayMatch != null) {
      days.add(_Day(dayMatch.group(1)!.trim()));
      group = null;
      supersetSlots = 0;
      continue;
    }
    if (!_isBullet(line)) {
      // Lo primero que no es encabezado ni viñeta es el título.
      name ??= line;
      continue;
    }

    final content = line.substring(1).trim();
    if (_supersetMarker.hasMatch(content)) {
      supersetSlots = 2;
      continue;
    }

    final body = content.replaceFirst(_combinedPrefix, '');
    final colon = body.indexOf(':');
    if (colon < 0) {
      // Viñeta sin descripción: un grupo muscular ("Pecho", "Tríceps").
      group = body;
      supersetSlots = 0;
      continue;
    }

    if (days.isEmpty) {
      warnings.add('La rutina no separa los días; se guardó todo en uno solo.');
      days.add(_Day('Día 1'));
    }
    final exercise = _parseExercise(
      name: body.substring(0, colon).trim(),
      description: body.substring(colon + 1).trim(),
      groupLabel: group,
      // El segundo de la pareja es el que "va con el anterior".
      supersetWithPrevious: supersetSlots == 1,
    );
    if (supersetSlots > 0) supersetSlots--;
    days.last.exercises.add(exercise);
  }

  if (days.every((day) => day.exercises.isEmpty)) {
    warnings.add('No se encontró ningún ejercicio en el documento.');
  }

  return ParsedRoutine(
    warnings: warnings,
    draft: RoutineDraft(
      name: name ?? 'Rutina de entrenamiento',
      sourceFileName: fileName,
      days: [
        for (final day in days)
          RoutineDayDraft(name: day.name, exercises: day.exercises),
      ],
    ),
  );
}

final _dayHeader = RegExp(r'^D[ií]a\s*\d*\s*:\s*(.+)$', caseSensitive: false);
final _supersetMarker = RegExp(r'^Biserie\s*[:;.]?$', caseSensitive: false);
final _combinedPrefix = RegExp(r'^Combinado con\s*:\s*', caseSensitive: false);

class _Day {
  _Day(this.name);

  final String name;
  final exercises = <RoutineExerciseDraft>[];
}

bool _isBullet(String line) =>
    line.startsWith('•') || line.startsWith('◦') || line.startsWith('✦');

/// Une cada renglón partido con la viñeta a la que pertenece.
List<String> _joinContinuations(List<String> lines) {
  final joined = <String>[];
  for (final line in lines) {
    final startsNew = _isBullet(line) || _dayHeader.hasMatch(line);
    if (!startsNew && joined.isNotEmpty && _isBullet(joined.last)) {
      joined[joined.length - 1] = '${joined.last} $line';
    } else {
      joined.add(line);
    }
  }
  return joined;
}

final _warmup = RegExp(
  r'(\d+)\s+series?\s+de\s+aproximaci[oó]n\s*\+?\s*',
  caseSensitive: false,
);
final _sets = RegExp(r'(\d+)\s+series?', caseSensitive: false);
final _repRange = RegExp(
  r'(\d+)\s*(?:a|-|–)\s*(\d+)\s+repeticiones',
  caseSensitive: false,
);
final _repFixed = RegExp(r'(\d+)\s+repeticiones', caseSensitive: false);
final _toFailure = RegExp(
  r'al fallo(?:\s+t[eé]cnico)?(?:\s*\([^)]*\))?',
  caseSensitive: false,
);

/// "2 series de aproximación + 4 series efectivas de 8 a 12 repeticiones
/// como ejercicio principal" → series, rango y nota.
RoutineExerciseDraft _parseExercise({
  required String name,
  required String description,
  required String? groupLabel,
  required bool supersetWithPrevious,
}) {
  var rest = description;
  var warmupSets = 0;
  final warmup = _warmup.firstMatch(rest);
  if (warmup != null) {
    warmupSets = int.parse(warmup.group(1)!);
    rest = rest.substring(warmup.end);
  }

  final sets = _sets.firstMatch(rest);
  if (sets == null) {
    return RoutineExerciseDraft(
      name: name,
      groupLabel: groupLabel,
      warmupSets: warmupSets,
      supersetWithPrevious: supersetWithPrevious,
      note: _cleanNote(description),
      warning: 'No se entendieron las series de este ejercicio.',
    );
  }
  final workSets = int.parse(sets.group(1)!);
  rest = rest.substring(sets.end);

  int? repsMin;
  int? repsMax;
  String? repsNote;
  String? warning;
  if (_repRange.firstMatch(rest) case final range?) {
    repsMin = int.parse(range.group(1)!);
    repsMax = int.parse(range.group(2)!);
    rest = rest.substring(range.end);
  } else if (_repFixed.firstMatch(rest) case final fixed?) {
    repsMin = repsMax = int.parse(fixed.group(1)!);
    rest = rest.substring(fixed.end);
  } else if (_toFailure.firstMatch(rest) case final failure?) {
    repsNote = failure.group(0)!.trim();
    rest = rest.substring(failure.end);
  } else {
    warning = 'No se entendieron las repeticiones de este ejercicio.';
  }

  if (_sets.hasMatch(rest)) {
    warning ??=
        'El ejercicio trae dos bloques de series; solo se tomó el '
        'primero. Revisa la nota.';
  }

  return RoutineExerciseDraft(
    name: name,
    groupLabel: groupLabel,
    warmupSets: warmupSets,
    workSets: workSets,
    repsMin: repsMin,
    repsMax: repsMax,
    repsNote: repsNote,
    supersetWithPrevious: supersetWithPrevious,
    note: _cleanNote(rest),
    warning: warning,
  );
}

/// Indicaciones que siguen al objetivo: sin espacios ni puntuación sobrante,
/// y con mayúscula inicial.
String? _cleanNote(String text) {
  final note = text
      .trim()
      .replaceFirst(RegExp(r'^[,;:.+\-]\s*'), '')
      .replaceFirst(RegExp(r'\.$'), '')
      .trim();
  if (note.isEmpty) return null;
  return note[0].toUpperCase() + note.substring(1);
}
