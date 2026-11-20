import 'weight.dart';

/// Qué significa el peso que se anota en un ejercicio (ADR-0022).
///
/// El peso se guarda tal como se capturó; esto solo dice cómo leerlo. Así
/// el progreso de cada ejercicio no cambia y el total se calcula cuando hace
/// falta.
enum LoadMode {
  /// El peso completo: barra con discos, Smith, máquina de placa, polea.
  total,

  /// Lo que pesa cada mancuerna o pesa rusa; se usan dos.
  perHand,

  /// Los discos de un lado: prensa, máquinas con dos cargas.
  perSide,

  /// Peso corporal más el lastre que se anota (0 si no hay lastre).
  bodyweight,
}

/// Cómo se mide un ejercicio cuando el usuario no lo ha elegido: según el
/// equipo que indica el catálogo (ADR-0015).
LoadMode loadModeForEquipment(String? equipment) => switch (equipment) {
  'dumbbell' || 'kettlebells' => LoadMode.perHand,
  'body only' => LoadMode.bodyweight,
  _ => LoadMode.total,
};

/// Nombre de cada forma de medir, para elegirla.
String loadModeLabel(LoadMode mode) => switch (mode) {
  LoadMode.total => 'Peso total',
  LoadMode.perHand => 'Por mancuerna',
  LoadMode.perSide => 'Por lado',
  LoadMode.bodyweight => 'Peso corporal + lastre',
};

/// Explicación corta de cada forma, con ejemplos.
String loadModeHint(LoadMode mode) => switch (mode) {
  LoadMode.total => 'Barra, Smith, máquinas y poleas: todo lo que levantas.',
  LoadMode.perHand => 'Lo que pesa cada mancuerna; la app sabe que son dos.',
  LoadMode.perSide => 'Los discos de un solo lado, como en la prensa.',
  LoadMode.bodyweight => 'Dominadas o fondos: anota solo el lastre extra.',
};

/// "60 kg", "20 kg c/u", "50 kg por lado", "+10 kg", "Peso corporal".
String formatLoad(
  double weight,
  WeightUnit unit,
  LoadMode mode, {
  required String Function(double) number,
}) {
  final base = '${number(weight)} ${unit.name}';
  return switch (mode) {
    LoadMode.total => base,
    LoadMode.perHand => '$base c/u',
    LoadMode.perSide => '$base por lado',
    LoadMode.bodyweight => weight == 0 ? 'Peso corporal' : '+$base',
  };
}

/// Lo que se agrega a una cifra en kg para no perder su significado:
/// "1RM ≈ 24 kg c/u".
String loadModeSuffix(LoadMode mode) => switch (mode) {
  LoadMode.total => '',
  LoadMode.perHand => ' c/u',
  LoadMode.perSide => ' por lado',
  LoadMode.bodyweight => ' de lastre',
};

/// El peso real que se mueve, en kg. Con peso corporal hace falta conocerlo;
/// sin él, `null`. Las máquinas por lado no incluyen el peso del carro.
double? totalLoadKg(
  double weight,
  WeightUnit unit,
  LoadMode mode, {
  double? bodyweightKg,
}) {
  final kg = toKg(weight, unit);
  return switch (mode) {
    LoadMode.total => kg,
    LoadMode.perHand || LoadMode.perSide => kg * 2,
    LoadMode.bodyweight => bodyweightKg == null ? null : bodyweightKg + kg,
  };
}
