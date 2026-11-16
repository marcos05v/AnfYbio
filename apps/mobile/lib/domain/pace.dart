/// Ritmo de natación: segundos por cada 100 m.
///
/// Devuelve `null` si la distancia o el tiempo no son positivos.
double? swimPaceSecondsPer100m({
  required int distanceM,
  required int durationMs,
}) {
  if (distanceM <= 0 || durationMs <= 0) return null;
  return durationMs / 1000 / distanceM * 100;
}

/// Ritmo de carrera: segundos por kilómetro.
///
/// Devuelve `null` si la distancia o el tiempo no son positivos.
double? runPaceSecondsPerKm({required int distanceM, required int durationS}) {
  if (distanceM <= 0 || durationS <= 0) return null;
  return durationS / distanceM * 1000;
}

/// Da formato de reloj a un ritmo: 95.0 → "1:35".
///
/// Redondea al segundo más cercano antes de separar minutos y segundos, para
/// que 119.6 sea "2:00" y no "1:60".
String formatPace(double seconds) {
  final total = seconds.round();
  final minutes = total ~/ 60;
  final rest = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}
