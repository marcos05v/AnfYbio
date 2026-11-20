/// Tipo de día según el plan: los menús cambian entre uno y otro.
///
/// Unos planes separan días de entrenamiento y de descanso; otros, días
/// altos y bajos en carbohidratos (y se entrena en ambos). Se guardan por
/// nombre, así que agregar tipos no requiere migración.
enum DayType { training, rest, high, low }

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

/// Si la app puede elegir sola el menú de hoy: solo cuando el plan separa
/// entrenamiento y descanso. Con días altos y bajos (se entrena en los dos)
/// lo elige el usuario.
bool canDetectDayType(Iterable<DayType> planDayTypes) =>
    planDayTypes.contains(DayType.training) &&
    planDayTypes.contains(DayType.rest);

/// Separa las alternativas que el plan escribe en un mismo renglón:
/// "Pechuga de pollo o filete de res magro" → dos opciones.
///
/// Solo corta en " o " (también "ó" y "u") y " / " con espacios, para no
/// partir palabras como "horneada/cocida".
List<String> foodOptions(String name) => name
    .split(RegExp(r'\s+[oóu]\s+|\s+/\s+', caseSensitive: false))
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

  NutritionPlanDraft copyWith({String? name, List<MenuDraft>? menus}) {
    return NutritionPlanDraft(
      name: name ?? this.name,
      sourceFileName: sourceFileName,
      weighingNotes: weighingNotes,
      menus: menus ?? this.menus,
      supplements: supplements,
    );
  }

  /// Todos los alimentos del plan, en orden.
  Iterable<ItemDraft> get items =>
      menus.expand((menu) => menu.meals).expand((meal) => meal.items);
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

  MenuDraft copyWith({List<MealDraft>? meals}) =>
      MenuDraft(dayType: dayType, title: title, meals: meals ?? this.meals);
}

class MealDraft {
  const MealDraft({required this.name, this.timingNote, this.items = const []});

  final String name;
  final String? timingNote;
  final List<ItemDraft> items;

  MealDraft copyWith({List<ItemDraft>? items}) =>
      MealDraft(name: name, timingNote: timingNote, items: items ?? this.items);
}

class ItemDraft {
  const ItemDraft({
    required this.name,
    this.amount,
    this.unit,
    this.state = FoodState.unspecified,
    this.isFree = false,
    this.note,
    this.warning,
  });

  final String name;
  final double? amount;
  final FoodUnit? unit;
  final FoodState state;

  /// Consumo libre ("Ensalada verde: Libre"): no lleva cantidad.
  final bool isFree;
  final String? note;

  /// Lo que la lectura de un archivo no entendió de este renglón, para
  /// mostrarlo en la revisión. No se guarda en la base de datos.
  final String? warning;
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
