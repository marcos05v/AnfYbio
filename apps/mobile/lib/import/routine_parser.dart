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
/// (ADR-0010 y ADR-0021).
///
/// No depende de una plantilla: reconoce cada renglón por lo que dice, sin
/// importar qué viñeta o numeración traiga.
///
/// - **Día:** "Día 1: Pecho", "DÍA 2 - Pierna".
/// - **Biserie o circuito:** "Biserie:", "BISERIE 1 (3 series):",
///   "Triserie", "Circuito". Agrupa los ejercicios que siguen (dos en una
///   biserie, tres en una triserie) y les presta sus series.
/// - **Grupo:** "• Pecho" o un título en mayúsculas ("ABDOMEN (4 rondas)").
/// - **Ejercicio:** "Nombre: lo que pide". Se entienden:
///   - "4 series de 8 a 12 repeticiones" y "4 series x 8-12 reps";
///   - "4 x 15", "12 reps", "al fallo", "30 seg";
///   - y "2 series de aproximación + …".
///
/// Igual que el lector del plan de alimentación, no adivina: lo que no
/// reconoce lo conserva y lo marca para la revisión.
ParsedRoutine parseRoutine(String text, {String? fileName}) {
  final warnings = <String>[];
  final days = <_Day>[];
  String? name;
  String? group;
  int? groupSets;
  _Block? block;

  for (final line in _joinContinuations(_markedLines(text))) {
    final content = line.text;

    if (_dayHeader.firstMatch(content) case final day?) {
      days.add(_Day(day.group(1)!.trim()));
      group = null;
      groupSets = null;
      block = null;
      continue;
    }

    if (_blockHeader.firstMatch(content) case final header?) {
      final kind = header.group(1)?.toLowerCase();
      block = _Block(
        size: switch (kind) {
          'bi' => 2,
          'tri' => 3,
          _ => 99,
        },
        sets: _setsIn(content),
      );
      continue;
    }

    final body = content.replaceFirst(_combinedPrefix, '');
    final colon = body.indexOf(':');
    final label = colon < 0 ? body : body.substring(0, colon).trim();

    // Un título: "• Pecho" (viñeta principal sin descripción) o un renglón
    // en mayúsculas ("ABDOMEN: TODOS LOS DÍAS (4 rondas)").
    final isTitle =
        (colon < 0 && line.marker == _Marker.bullet) || _isShouting(label);
    if (isTitle && (days.isNotEmpty || name != null)) {
      group = _cleanTitle(body);
      groupSets = _setsIn(body);
      block = null;
      if (RegExp(r'todos los d[ií]as', caseSensitive: false).hasMatch(body)) {
        warnings.add(
          '"$group" va en varios días; quedó en el día '
          '${days.length}. Cópialo a los demás si hace falta.',
        );
      }
      continue;
    }

    if (colon < 0 && line.marker == _Marker.none && name == null) {
      // Lo primero que no es encabezado ni viñeta es el título.
      name = content;
      continue;
    }

    if (days.isEmpty && line.marker == _Marker.none && !line.labeled) {
      // Texto suelto antes del primer día: no es parte de la rutina.
      continue;
    }
    if (days.isEmpty) {
      warnings.add('La rutina no separa los días; se guardó todo en uno solo.');
      days.add(_Day('Día 1'));
    }

    // ¿Sigue la biserie abierta? Sí, mientras quepa y el renglón sea una
    // subviñeta o lleve etiqueta ("A2."). Un renglón principal la cierra.
    final open = block;
    final inBlock =
        open != null &&
        open.count < open.size &&
        (line.labeled ||
            line.marker == _Marker.subBullet ||
            line.marker == _Marker.none);
    if (!inBlock) block = null;
    final current = inBlock ? open : null;

    final exercise = colon < 0
        ? _parseUnlabeled(body)
        : _parseExercise(
            name: label,
            description: body.substring(colon + 1).trim(),
          );
    days.last.exercises.add(
      _finish(
        exercise,
        groupLabel: group,
        inheritedSets: current?.sets ?? groupSets,
        supersetWithPrevious: (current?.count ?? 0) > 0,
      ),
    );
    current?.count++;
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

final _dayHeader = RegExp(
  r'^D[IÍií]A\s*\d*\s*[:.\-–]\s*(.+)$',
  caseSensitive: false,
);

/// "Biserie:", "BISERIE 2 (3 series):", "Triserie", "Circuito". Tras la
/// palabra debe venir un número, un signo o nada: "Biserie de Brazos" es un
/// grupo, no una marca.
final _blockHeader = RegExp(
  r'^(?:(bi|tri|super|giant)\s*series?|circuito)(?=\s*(?:\d|[:;.(\-–]|$))',
  caseSensitive: false,
);
final _combinedPrefix = RegExp(r'^Combinado con\s*:\s*', caseSensitive: false);

class _Day {
  _Day(this.name);

  final String name;
  final exercises = <RoutineExerciseDraft>[];
}

class _Block {
  _Block({required this.size, required this.sets});

  final int size;
  final int? sets;
  var count = 0;
}

enum _Marker { none, bullet, subBullet, number }

/// Un renglón sin sus viñetas, números ni etiquetas, recordando cuáles traía.
class _Line {
  _Line(this.text, this.marker, {this.labeled = false});

  String text;
  final _Marker marker;

  /// Traía etiqueta de biserie: "A1.", "C2:".
  final bool labeled;
}

final _bulletPrefix = RegExp(r'^([•●▪◦✦\-–*])\s*');
final _numberPrefix = RegExp(r'^\d+\s*[.)]\s+');
final _labelPrefix = RegExp(r'^[A-Z]\d\s*[.:)]\s*');

List<_Line> _markedLines(String text) {
  final result = <_Line>[];
  for (final raw in text.split('\n')) {
    var line = raw.trim();
    var marker = _Marker.none;
    var labeled = false;
    while (true) {
      if (_bulletPrefix.firstMatch(line) case final m?) {
        // La viñeta más externa decide si es principal o secundaria.
        if (marker == _Marker.none) {
          marker = '•●▪'.contains(m.group(1)!)
              ? _Marker.bullet
              : '◦✦'.contains(m.group(1)!)
              ? _Marker.subBullet
              : _Marker.none;
        }
        line = line.substring(m.end);
      } else if (_numberPrefix.firstMatch(line) case final m?) {
        // "1. 2. 3. Calentamiento": numeración repetida que deja el PDF.
        if (marker == _Marker.none) marker = _Marker.number;
        line = line.substring(m.end);
      } else if (_labelPrefix.firstMatch(line) case final m?) {
        labeled = true;
        line = line.substring(m.end);
      } else {
        break;
      }
    }
    if (line.isEmpty) continue; // una viñeta o un guion sueltos
    result.add(_Line(line, marker, labeled: labeled));
  }
  return result;
}

/// Une cada renglón partido con el anterior. Un renglón sin viñeta empieza
/// algo nuevo solo si es un día, una biserie o "Nombre: algo" con mayúscula
/// inicial; si empieza con minúscula, número o paréntesis es continuación.
List<_Line> _joinContinuations(List<_Line> lines) {
  final joined = <_Line>[];
  for (final line in lines) {
    final previous = joined.lastOrNull;
    final text = line.text;
    final continues =
        previous != null &&
        line.marker == _Marker.none &&
        !line.labeled &&
        !_dayHeader.hasMatch(text) &&
        !_blockHeader.hasMatch(text) &&
        !_dayHeader.hasMatch(previous.text) &&
        (
        // "BISERIE 3" + "GEMELOS (3 series):": el encabezado sigue abierto.
        (_blockHeader.hasMatch(previous.text) &&
                !previous.text.endsWith(':')) ||
            RegExp(r'^[\p{Ll}\d(]', unicode: true).hasMatch(text) ||
            !text.contains(':'));
    // El título del documento nunca es continuación.
    final isTitle = joined.isEmpty;
    if (continues && !isTitle) {
      previous.text = '${previous.text} $text';
    } else {
      joined.add(line);
    }
  }
  return joined;
}

/// Un rótulo en mayúsculas: "ABDOMEN", "GEMELOS". Al menos cuatro letras para
/// no confundirlo con siglas como "HIIT" dentro de un nombre.
bool _isShouting(String label) {
  final letters = label.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
  return letters.length >= 4 && letters == letters.toUpperCase();
}

String _cleanTitle(String text) =>
    text.trim().replaceFirst(RegExp(r'[:.]$'), '').trim();

final _setsWord = RegExp(
  r'(\d+)\s*(?:series?|sets?|rondas?|vueltas?)\b',
  caseSensitive: false,
);
final _setsTimes = RegExp(r'(\d+)\s*[x×]\s*(?=\d)', caseSensitive: false);

int? _setsIn(String text) => switch (_setsWord.firstMatch(text)) {
  final m? => int.parse(m.group(1)!),
  null => null,
};

final _warmup = RegExp(
  r'(\d+)\s+series?\s+de\s+aproximaci[oó]n\s*\+?\s*',
  caseSensitive: false,
);
const _repsUnit = r'(?:repeticiones|reps?|pasos)\b';
final _repRange = RegExp(
  r'(\d+)\s*(?:a|-|–)\s*(\d+)\s*' + _repsUnit,
  caseSensitive: false,
);
final _repFixed = RegExp(r'(\d+)\s*' + _repsUnit, caseSensitive: false);

/// "x 8-10" o "x15": repeticiones sin la palabra, después de "4 x".
final _bareRange = RegExp(r'^(\d+)\s*(?:-|–)\s*(\d+)\b');
final _bareFixed = RegExp(r'^(\d+)\b');
final _toFailure = RegExp(
  r'al fallo(?:\s+t[eé]cnico)?(?:\s*\([^)]*\))?',
  caseSensitive: false,
);
final _duration = RegExp(
  r'(\d+)\s*(?:seg(?:undos)?|s|min(?:utos)?)\b',
  caseSensitive: false,
);

/// Calentamiento y cardio: no se leen como series de fuerza.
final _warmupOrCardio = RegExp(
  r'^(calentamiento|cardio|hiit|liss|movilidad|estiramientos?)',
  caseSensitive: false,
);

/// "10,10,8 reps": un drop set o una pirámide; queda como texto.
final _repList = RegExp(
  r'(\d+(?:\s*,\s*\d+)+)\s*' + _repsUnit,
  caseSensitive: false,
);

/// Calentamiento, cardio y similares: no son series de fuerza, así que no
/// se marcan por no traerlas.
final _nonStrength = RegExp(
  r'^(calentamiento|cardio|hiit|liss|movilidad|estiramientos?|activaci[oó]n)',
  caseSensitive: false,
);

/// Objetivo leído de un texto.
class _Target {
  const _Target({
    this.warmupSets = 0,
    this.workSets,
    this.repsMin,
    this.repsMax,
    this.repsNote,
    this.note,
    this.extraSets = false,
  });

  final int warmupSets;
  final int? workSets;
  final int? repsMin;
  final int? repsMax;
  final String? repsNote;
  final String? note;

  /// Trae un segundo bloque de series ("4 series … + 4 series …").
  final bool extraSets;
}

class _Parsed {
  const _Parsed(this.name, this.target);

  final String name;
  final _Target target;
}

_Parsed _parseExercise({required String name, required String description}) {
  if (_warmupOrCardio.hasMatch(name)) {
    // Calentamiento o cardio: solo la duración; lo demás es la nota, aunque
    // mencione series ("activación con 2 series de 25 reps").
    final duration = _duration.firstMatch(description);
    return _Parsed(
      name,
      _Target(
        repsNote: duration?.group(0)!.trim(),
        note: _cleanNote(
          duration == null
              ? description
              : description.replaceRange(duration.start, duration.end, ''),
        ),
      ),
    );
  }
  return _Parsed(name, _parseTarget(description));
}

/// Un ejercicio sin dos puntos: "Plancha de 1 min", "Crunch 30 seg".
_Parsed _parseUnlabeled(String text) {
  final duration = RegExp(
    r'\s*(?:de\s+)?(\d+\s*(?:seg(?:undos)?|s|min(?:utos)?))\b\.?$',
    caseSensitive: false,
  ).firstMatch(text);
  if (duration == null) return _Parsed(text, _parseTarget(''));
  return _Parsed(
    text.substring(0, duration.start).trim(),
    _Target(repsNote: duration.group(1)),
  );
}

/// "2 series de aproximación + 4 series efectivas de 8 a 12 repeticiones
/// como ejercicio principal" → series, rango y nota.
_Target _parseTarget(String description) {
  var text = description;
  var warmupSets = 0;
  if (_warmup.firstMatch(text) case final warmup?) {
    warmupSets = int.parse(warmup.group(1)!);
    text = text.substring(warmup.end);
  }

  // Las series pueden ir antes ("4 series x 10 reps") o después ("20 reps
  // ligeras (1 serie)").
  final setsMatch = _setsWord.firstMatch(text) ?? _setsTimes.firstMatch(text);
  var before = setsMatch == null ? '' : text.substring(0, setsMatch.start);
  var after = setsMatch == null ? text : text.substring(setsMatch.end);
  final workSets = setsMatch == null ? null : int.parse(setsMatch.group(1)!);
  after = after.replaceFirst(RegExp(r'^\s*[x×]\s*'), '');

  int? repsMin;
  int? repsMax;
  String? repsNote;

  /// Busca el objetivo en [source]; devuelve dónde estaba o `null`.
  (int, int)? takeReps(String source) {
    final list = _repList.firstMatch(source);
    final single = _repRange.firstMatch(source) ?? _repFixed.firstMatch(source);
    if (list != null && (single == null || list.start <= single.start)) {
      repsNote = '${list.group(1)} reps';
      return (list.start, list.end);
    }
    if (_repRange.firstMatch(source) case final m?) {
      repsMin = int.parse(m.group(1)!);
      repsMax = int.parse(m.group(2)!);
      return (m.start, m.end);
    }
    if (_repFixed.firstMatch(source) case final m?) {
      repsMin = repsMax = int.parse(m.group(1)!);
      return (m.start, m.end);
    }
    if (_toFailure.firstMatch(source) case final m?) {
      repsNote = m.group(0)!.trim();
      return (m.start, m.end);
    }
    return null;
  }

  String? rest;
  if (takeReps(after) case (_, final end)?) {
    // Lo que va entre las series y el objetivo ("efectivas de") se omite.
    rest = after.substring(end);
  } else if (setsMatch != null) {
    // "4 x15" o "4 series x 8-10" sin la palabra repeticiones.
    final trimmed = after.trimLeft();
    if (_bareRange.firstMatch(trimmed) case final m?) {
      repsMin = int.parse(m.group(1)!);
      repsMax = int.parse(m.group(2)!);
      rest = trimmed.substring(m.end);
    } else if (_setsTimes.hasMatch(text)) {
      if (_bareFixed.firstMatch(trimmed) case final m?) {
        repsMin = repsMax = int.parse(m.group(1)!);
        rest = trimmed.substring(m.end);
      }
    }
  }
  if (rest == null && before.isNotEmpty) {
    // El objetivo venía antes de las series: "20 reps ligeras (1 serie)".
    if (takeReps(before) case (final start, final end)?) {
      before = before.replaceRange(start, end, ' ');
      rest = after;
    }
  }
  if (rest == null) {
    if (_duration.firstMatch(after) case final m?) {
      repsNote = m.group(0)!.trim();
      rest = after.replaceRange(m.start, m.end, ' ');
    }
  }

  final noteSource = [before, rest ?? after].join(' ');
  return _Target(
    warmupSets: warmupSets,
    workSets: workSets,
    repsMin: repsMin,
    repsMax: repsMax,
    repsNote: repsNote,
    note: _cleanNote(noteSource),
    extraSets: rest != null && _setsWord.hasMatch(rest),
  );
}

RoutineExerciseDraft _finish(
  _Parsed parsed, {
  required String? groupLabel,
  required int? inheritedSets,
  required bool supersetWithPrevious,
}) {
  final t = parsed.target;
  final sets = t.workSets ?? inheritedSets;
  final relaxed = _nonStrength.hasMatch(parsed.name);
  final String? warning;
  if (relaxed) {
    warning = null;
  } else if (sets == null) {
    warning = 'No se entendieron las series de este ejercicio.';
  } else if (t.repsMin == null && t.repsNote == null) {
    warning = 'No se entendieron las repeticiones de este ejercicio.';
  } else if (t.extraSets) {
    warning =
        'El ejercicio trae dos bloques de series; solo se tomó el '
        'primero. Revisa la nota.';
  } else {
    warning = null;
  }
  return RoutineExerciseDraft(
    name: parsed.name,
    groupLabel: groupLabel,
    warmupSets: t.warmupSets,
    workSets: sets,
    repsMin: t.repsMin,
    repsMax: t.repsMax,
    repsNote: t.repsNote,
    supersetWithPrevious: supersetWithPrevious,
    note: t.note,
    warning: warning,
  );
}

/// Indicaciones que siguen al objetivo: sin espacios ni puntuación sobrante,
/// y con mayúscula inicial.
String? _cleanNote(String text) {
  final note = text
      .replaceAll(RegExp(r'\(\s*\)'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' )', ')')
      .trim()
      .replaceFirst(RegExp(r'^[,;:.+\-]\s*'), '')
      .replaceFirst(RegExp(r'^\(\s*\)$'), '')
      .replaceFirst(RegExp(r'\.$'), '')
      .trim();
  if (note.isEmpty) return null;
  return note[0].toUpperCase() + note.substring(1);
}
