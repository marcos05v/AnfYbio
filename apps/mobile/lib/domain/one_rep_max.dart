import 'weight.dart';

/// Fórmulas para estimar la repetición máxima (1RM) a partir de una serie.
enum OneRepMaxFormula { epley, brzycki }

/// Por encima de estas repeticiones la estimación pierde precisión: la serie
/// depende más de la resistencia muscular que de la fuerza máxima.
const int maxReliableReps = 10;

/// Indica si una serie con [reps] repeticiones da una estimación confiable.
bool isReliableForOneRepMax(int reps) => reps >= 1 && reps <= maxReliableReps;

/// Estima el 1RM en kilogramos a partir de una serie.
///
/// Devuelve `null` cuando no hay nada que estimar: sin repeticiones (serie
/// fallida), sin peso externo (peso corporal) o fuera del dominio de la
/// fórmula. Es una estimación orientativa, no una medición.
double? estimateOneRepMaxKg({
  required double weight,
  required WeightUnit unit,
  required int reps,
  OneRepMaxFormula formula = OneRepMaxFormula.epley,
}) {
  if (reps < 1 || weight <= 0) return null;

  final kg = toKg(weight, unit);

  // Una repetición ya es el 1RM levantado. Epley daría un 3 % de más.
  if (reps == 1) return kg;

  return switch (formula) {
    OneRepMaxFormula.epley => kg * (1 + reps / 30),
    // El denominador llega a cero en 37 repeticiones.
    OneRepMaxFormula.brzycki => reps >= 37 ? null : kg * 36 / (37 - reps),
  };
}
