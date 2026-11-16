/// Unidad en la que se captura un peso. Se guarda como texto: 'kg' o 'lb'.
enum WeightUnit { kg, lb }

/// Definición exacta de la libra internacional en kilogramos.
const double kgPerLb = 0.45359237;

/// Convierte un peso capturado a kilogramos.
///
/// La base de datos guarda el peso en su unidad original (ADR-0002); todos los
/// cálculos pasan por aquí para trabajar siempre en kg.
double toKg(double weight, WeightUnit unit) => switch (unit) {
  WeightUnit.kg => weight,
  WeightUnit.lb => weight * kgPerLb,
};
