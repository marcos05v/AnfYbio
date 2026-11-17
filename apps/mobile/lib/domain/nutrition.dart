/// Tipo de día según el plan: los menús cambian entre uno y otro.
enum DayType { training, rest }

/// Unidad en la que el plan expresa una cantidad.
enum FoodUnit { gram, piece, scoop }

/// En qué estado se pesa el alimento. El plan puede no decirlo: entonces
/// queda [unspecified] hasta que el usuario lo indique (no se adivina).
enum FoodState { raw, cooked, dry, unspecified }

/// El menú que corresponde hoy.
///
/// Si el usuario lo eligió a mano ([override]), manda su elección. Si no, es
/// día de entrenamiento cuando ya hay una sesión registrada hoy.
DayType dayTypeFor({required bool hasSessionToday, DayType? override}) =>
    override ?? (hasSessionToday ? DayType.training : DayType.rest);

/// Separa las alternativas que el plan escribe en un mismo renglón:
/// "Pechuga de pollo o filete de res magro" → dos opciones.
///
/// Solo corta en " o " y " / " con espacios, para no partir palabras como
/// "horneada/cocida".
List<String> foodOptions(String name) => name
    .split(RegExp(r'\s+o\s+|\s+/\s+', caseSensitive: false))
    .map((option) => option.trim())
    .where((option) => option.isNotEmpty)
    .toList();

/// Un plan completo todavía sin guardar: lo que produce la captura manual o
/// la lectura de un PDF, y lo que la pantalla de revisión deja corregir.
class NutritionPlanDraft {
  const NutritionPlanDraft({
    required this.name,
    this.sourceFileName,
    this.weighingNotes,
    this.menus = const [],
    this.supplements = const [],
  });

  final String name;
  final String? sourceFileName;
  final String? weighingNotes;
  final List<MenuDraft> menus;
  final List<SupplementDraft> supplements;
}

class MenuDraft {
  const MenuDraft({
    required this.dayType,
    required this.title,
    this.meals = const [],
  });

  final DayType dayType;
  final String title;
  final List<MealDraft> meals;
}

class MealDraft {
  const MealDraft({required this.name, this.timingNote, this.items = const []});

  final String name;
  final String? timingNote;
  final List<ItemDraft> items;
}

class ItemDraft {
  const ItemDraft({
    required this.name,
    this.amount,
    this.unit,
    this.state = FoodState.unspecified,
    this.isFree = false,
    this.note,
  });

  final String name;
  final double? amount;
  final FoodUnit? unit;
  final FoodState state;

  /// Consumo libre ("Ensalada verde: Libre"): no lleva cantidad.
  final bool isFree;
  final String? note;
}

class SupplementDraft {
  const SupplementDraft({
    required this.name,
    this.dose,
    this.timing,
    this.benefit,
  });

  final String name;
  final String? dose;
  final String? timing;
  final String? benefit;
}
