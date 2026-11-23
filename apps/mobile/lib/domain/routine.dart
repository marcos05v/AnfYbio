/// Una rutina completa todavía sin guardar: lo que produce la captura manual
/// o la lectura de un PDF.
class RoutineDraft {
  const RoutineDraft({
    required this.name,
    this.sourceFileName,
    this.notes,
    this.days = const [],
  });

  final String name;
  final String? sourceFileName;

  /// Indicaciones generales del plan ("Regla general: descansos de 2–3 min
  /// en básicos…"), que no son de un día.
  final String? notes;
  final List<RoutineDayDraft> days;

  RoutineDraft copyWith({List<RoutineDayDraft>? days}) => RoutineDraft(
    name: name,
    sourceFileName: sourceFileName,
    notes: notes,
    days: days ?? this.days,
  );

  /// Todos los ejercicios de la rutina, en orden.
  Iterable<RoutineExerciseDraft> get exercises =>
      days.expand((day) => day.exercises);
}

class RoutineDayDraft {
  const RoutineDayDraft({required this.name, this.exercises = const []});

  final String name;
  final List<RoutineExerciseDraft> exercises;

  RoutineDayDraft copyWith({List<RoutineExerciseDraft>? exercises}) =>
      RoutineDayDraft(name: name, exercises: exercises ?? this.exercises);
}

/// Lo que la rutina pide para un ejercicio.
class RoutineExerciseDraft {
  const RoutineExerciseDraft({
    required this.name,
    this.groupLabel,
    this.warmupSets = 0,
    this.workSets,
    this.repsMin,
    this.repsMax,
    this.repsNote,
    this.supersetWithPrevious = false,
    this.note,
    this.warning,
  });

  final String name;

  /// Encabezado bajo el que aparece en el plan: "Pecho", "Tríceps"…
  final String? groupLabel;

  /// Series de aproximación antes de las efectivas.
  final int warmupSets;
  final int? workSets;

  /// Rango de repeticiones; si es un número fijo, mínimo y máximo coinciden.
  final int? repsMin;
  final int? repsMax;

  /// Objetivo que no es un rango de repeticiones: "al fallo técnico",
  /// "30 a 60 segundos".
  final String? repsNote;

  /// Forma biserie con el ejercicio anterior del mismo día.
  final bool supersetWithPrevious;
  final String? note;

  /// Lo que la lectura de un archivo no entendió, para la revisión. No se
  /// guarda en la base de datos.
  final String? warning;
}

/// Objetivo de un ejercicio en una línea: "2 aprox. + 4 × 8–12",
/// "3 × al fallo técnico", "4 × 15". Vacío si la rutina no lo indica.
String formatExerciseTarget({
  required int warmupSets,
  required int? workSets,
  required int? repsMin,
  required int? repsMax,
  required String? repsNote,
}) {
  final reps = switch ((repsMin, repsMax)) {
    (null, null) => repsNote,
    (final min?, final max?) when min != max => '$min–$max',
    (final min, final max) => '${min ?? max}',
  };
  final work = switch ((workSets, reps)) {
    (null, null) => null,
    (final sets?, null) => sets == 1 ? '1 serie' : '$sets series',
    (null, final reps?) => reps,
    (final sets?, final reps?) => '$sets × $reps',
  };
  return [if (warmupSets > 0) '$warmupSets aprox.', ?work].join(' + ');
}

/// El día de la rutina que corresponde a una fecha, según el día de la
/// semana: por defecto el lunes es el Día 1, el martes el Día 2, etc.
///
/// [dayOneWeekday] es el día de la semana (1 = lunes … 7 = domingo) en el que
/// cae el Día 1; el usuario puede recorrerlo. Devuelve la posición del día
/// (desde 0), o `null` si ese día de la semana no tiene rutina: es descanso.
int? routineDayIndexFor({
  required DateTime date,
  required int dayCount,
  int dayOneWeekday = DateTime.monday,
}) {
  final slot = (date.weekday - dayOneWeekday) % DateTime.daysPerWeek;
  return slot < dayCount ? slot : null;
}

/// En qué día de la semana debe caer el Día 1 para que **hoy** toque el día
/// de la rutina en la posición [todayIndex] (desde 0). Es lo que se guarda
/// cuando el usuario corrige a mano el día que toca.
int dayOneWeekdayFor({required DateTime today, required int todayIndex}) =>
    (today.weekday - 1 - todayIndex) % DateTime.daysPerWeek + 1;

/// Si la siguiente serie de un ejercicio debe proponerse como aproximación:
/// mientras se hayan registrado menos de las que pide la rutina.
bool nextSetIsWarmup({required int warmupSets, required int loggedWarmups}) =>
    loggedWarmups < warmupSets;

/// Agrupa los ejercicios de un día en bloques: cada bloque es un ejercicio
/// suelto o una biserie (los ejercicios consecutivos unidos con el anterior).
///
/// [withPrevious] indica si un ejercicio va unido al que le precede. Si el
/// primero del día lo dice, no tiene con quién unirse y abre su propio bloque.
List<List<T>> groupSupersets<T>(
  Iterable<T> exercises,
  bool Function(T exercise) withPrevious,
) {
  final blocks = <List<T>>[];
  for (final exercise in exercises) {
    if (blocks.isNotEmpty && withPrevious(exercise)) {
      blocks.last.add(exercise);
    } else {
      blocks.add([exercise]);
    }
  }
  return blocks;
}
