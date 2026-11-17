import 'one_rep_max.dart';
import 'weight.dart';

/// Una serie de fuerza con la fecha de su sesión: lo mínimo que hace falta
/// para trazar la progresión de un ejercicio.
class SetSample {
  const SetSample({
    required this.sessionId,
    required this.date,
    required this.weight,
    required this.unit,
    required this.reps,
    required this.isWarmup,
  });

  final String sessionId;

  /// Inicio de la sesión, en hora local.
  final DateTime date;
  final double weight;
  final WeightUnit unit;
  final int reps;
  final bool isWarmup;
}

/// El mejor 1RM estimado de una sesión.
class OneRepMaxPoint {
  const OneRepMaxPoint({required this.date, required this.kg});

  final DateTime date;
  final double kg;
}

/// Progresión del 1RM estimado: un punto por sesión, con el mejor valor de
/// ese día, en orden cronológico.
///
/// Solo cuentan las series efectivas de hasta [maxReliableReps] repeticiones:
/// el calentamiento no refleja la fuerza máxima y las series largas dan una
/// estimación poco confiable que deformaría la gráfica. Una sesión sin
/// ninguna serie que cuente no aporta punto.
List<OneRepMaxPoint> oneRepMaxHistory(
  Iterable<SetSample> sets, {
  OneRepMaxFormula formula = OneRepMaxFormula.epley,
}) {
  final best = <String, OneRepMaxPoint>{};
  for (final set in sets) {
    if (set.isWarmup || !isReliableForOneRepMax(set.reps)) continue;
    final kg = estimateOneRepMaxKg(
      weight: set.weight,
      unit: set.unit,
      reps: set.reps,
      formula: formula,
    );
    if (kg == null) continue;
    final current = best[set.sessionId];
    if (current == null || kg > current.kg) {
      best[set.sessionId] = OneRepMaxPoint(date: set.date, kg: kg);
    }
  }
  return best.values.toList()..sort((a, b) => a.date.compareTo(b.date));
}
