/// Carga de una sesión por el método sRPE: RPE de sesión × minutos.
///
/// Sirve igual para fuerza, natación, carrera y apnea, y por eso permite
/// sumarlas en una sola cifra. Devuelve `null` si la sesión aún no tiene
/// duración o RPE (sesión en curso).
double? sessionLoad({required int? durationS, required int? sessionRpe}) {
  if (durationS == null || sessionRpe == null) return null;
  return sessionRpe * durationS / 60;
}

/// La carga de una sesión ubicada en el día en que ocurrió.
class LoadEntry {
  const LoadEntry({required this.day, required this.load});

  /// Fecha local de la sesión. La hora se ignora.
  final DateTime day;
  final double load;
}

const int acuteDays = 7;
const int chronicDays = 28;

/// Carga aguda (última semana) frente a carga crónica (últimas 4 semanas).
///
/// Es una estimación orientativa del cambio reciente en el entrenamiento, no
/// un diagnóstico ni un predictor de lesiones.
class LoadSummary {
  const LoadSummary({
    required this.acute,
    required this.chronic,
    required this.hasEnoughHistory,
  });

  /// Suma de la carga de los últimos 7 días, incluido el día consultado.
  final double acute;

  /// Promedio semanal de la carga de los últimos 28 días.
  final double chronic;

  /// Falso si el primer registro tiene menos de 28 días: la carga crónica
  /// todavía no representa un hábito y la proporción sería engañosa.
  final bool hasEnoughHistory;

  /// Aguda ÷ crónica. 1.0 significa que esta semana fue como las anteriores.
  /// `null` si no hay historial suficiente o no hubo carga crónica.
  double? get ratio => hasEnoughHistory && chronic > 0 ? acute / chronic : null;
}

/// Resume la carga aguda y crónica vistas desde el día [asOf].
///
/// Los registros posteriores a [asOf] se ignoran.
LoadSummary summarizeLoad(List<LoadEntry> entries, {required DateTime asOf}) {
  final today = _dayNumber(asOf);
  var acute = 0.0;
  var chronicTotal = 0.0;
  int? oldestAge;

  for (final entry in entries) {
    final age = today - _dayNumber(entry.day); // 0 = el mismo día que asOf
    if (age < 0) continue;
    if (oldestAge == null || age > oldestAge) oldestAge = age;
    if (age < acuteDays) acute += entry.load;
    if (age < chronicDays) chronicTotal += entry.load;
  }

  return LoadSummary(
    acute: acute,
    chronic: chronicTotal / (chronicDays / acuteDays),
    hasEnoughHistory: oldestAge != null && oldestAge >= chronicDays - 1,
  );
}

/// Número de día de calendario. Se calcula en UTC a partir de año, mes y día
/// para que un cambio de horario (día de 23 o 25 horas) no desplace la cuenta.
int _dayNumber(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;
