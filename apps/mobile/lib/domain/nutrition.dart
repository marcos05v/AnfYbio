/// Tipo de día según el plan: los menús cambian entre uno y otro.
///
/// Unos planes separan días de entrenamiento y de descanso; otros, días
/// altos y bajos en carbohidratos (y se entrena en ambos). Se guardan por
/// nombre, así que agregar tipos no requiere migración.
enum DayType { training, rest, high, low }

/// Unidad en la que el plan expresa una cantidad. Se guarda por nombre, así
/// que agregar unidades no requiere migración.
enum FoodUnit { gram, piece, scoop, ml, cup, tablespoon, teaspoon }

/// En qué estado se pesa el alimento. El plan puede no decirlo: entonces
/// queda [unspecified] hasta que el usuario lo indique (no se adivina).
enum FoodState { raw, cooked, dry, unspecified }

/// El menú que corresponde hoy.
///
/// Si el usuario lo eligió a mano ([override]), manda su elección. Si no, es
/// día de entrenamiento cuando ya hay una sesión registrada hoy.
DayType dayTypeFor({required bool hasSessionToday, DayType? override}) =>
    override ?? (hasSessionToday ? DayType.training : DayType.rest);

/// El menú que toca según el día de la rutina, si el plan lo indica: con
/// "días altos: 2, 3 y 5", el Día 3 de la rutina es alto.
///
/// [routineDay] es el día de la rutina que toca hoy (Día 1 = 1), o `null`
/// si no hay rutina o hoy es descanso. [menuDays] son los días de cada tipo
/// de menú. Devuelve `null` si el plan no dice qué menú va ese día.
DayType? dayTypeForRoutineDay(
  int? routineDay,
  Map<DayType, List<int>> menuDays,
) {
  if (routineDay == null) return null;
  for (final MapEntry(key: type, value: days) in menuDays.entries) {
    if (days.contains(routineDay)) return type;
  }
  return null;
}

/// El menú que toca según el **nombre** del día de la rutina, para planes
/// que no dan números de día: el día "Tren Inferior (Glúteo, Femoral)" va
/// con el menú "Días de Tren Inferior (Más CHO)".
///
/// Compara las partes del cuerpo que nombran el día y cada menú. Glúteo,
/// femoral o pierna cuentan también como "tren inferior"; pecho, espalda o
/// brazo, como "tren superior". [routineDayName] nulo es un día sin rutina
/// (descanso): va con el menú que diga "descanso".
///
/// Gana el menú con más coincidencias; si empatan o ninguno coincide,
/// devuelve `null` (no adivina).
DayType? dayTypeByName(String? routineDayName, Map<DayType, String> menus) {
  final day = _bodyWords(routineDayName ?? 'descanso');
  if (day.isEmpty) return null;
  DayType? best;
  var bestScore = 0;
  var tie = false;
  for (final MapEntry(key: type, value: title) in menus.entries) {
    final score = _bodyWords(title).intersection(day).length;
    if (score > bestScore) {
      (best, bestScore, tie) = (type, score, false);
    } else if (score == bestScore && score > 0) {
      tie = true;
    }
  }
  return tie ? null : best;
}

const _lowerBody = [
  'inferior',
  'pierna',
  'glute',
  'femoral',
  'cuadricep',
  'isquio',
  'pantorrilla',
  'gemelo',
  'cadera',
  'aductor',
  'adductor',
  'abductor',
];
const _upperBody = [
  'superior',
  'pecho',
  'pectoral',
  'espalda',
  'hombro',
  'brazo',
  'bicep',
  'tricep',
  'torso',
  'antebrazo',
  'dorsal',
  'trapecio',
  'deltoide',
];

Set<String> _bodyWords(String text) {
  final words = text
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .split(RegExp('[^a-zñ]+'));
  final found = <String>{};
  for (final word in words) {
    for (final part in [..._lowerBody, ..._upperBody, 'descanso']) {
      if (word.startsWith(part)) found.add(part);
    }
  }
  if (found.any(_lowerBody.contains)) found.add('inferior');
  if (found.any(_upperBody.contains)) found.add('superior');
  return found;
}

/// Convierte los días de la rutina a texto para guardarlos ("2,3,5"), y de
/// vuelta. Vacío ↔ nulo.
String? encodeRoutineDays(List<int> days) =>
    days.isEmpty ? null : ([...days]..sort()).join(',');

List<int> decodeRoutineDays(String? text) => [
  for (final part in (text ?? '').split(',')) ?int.tryParse(part.trim()),
];

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

  /// Todos los alimentos del plan, en orden, incluidos los ingredientes de
  /// cada plato y las alternativas.
  Iterable<ItemDraft> get items => menus
      .expand((menu) => menu.meals)
      .expand((meal) => meal.items)
      .expand((item) => item.flattened);
}

class MenuDraft {
  const MenuDraft({
    required this.dayType,
    required this.title,
    this.routineDays = const [],
    this.meals = const [],
  });

  final DayType dayType;
  final String title;

  /// Los días de la rutina (Día 1 = 1) en que toca este menú, si el plan
  /// los indica ("día: 2, 5 y 3"). Vacío si no.
  final List<int> routineDays;
  final List<MealDraft> meals;

  MenuDraft copyWith({List<MealDraft>? meals}) => MenuDraft(
    dayType: dayType,
    title: title,
    routineDays: routineDays,
    meals: meals ?? this.meals,
  );
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
    this.ingredients = const [],
    this.alternatives = const [],
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

  /// Si es un plato ("Sándwich"), lo que lleva: pan, pechuga…
  final List<ItemDraft> ingredients;

  /// Otras opciones con su propia cantidad: "1 manzana **ó** 1 taza de
  /// fresas". Las que comparten cantidad siguen en el nombre ("pollo o res").
  final List<ItemDraft> alternatives;

  /// Este alimento y todo lo que lleva dentro, en orden.
  Iterable<ItemDraft> get flattened sync* {
    yield this;
    for (final alternative in alternatives) {
      yield* alternative.flattened;
    }
    for (final ingredient in ingredients) {
      yield* ingredient.flattened;
    }
  }

  ItemDraft copyWith({
    String? note,
    List<ItemDraft>? ingredients,
    List<ItemDraft>? alternatives,
  }) => ItemDraft(
    name: name,
    amount: amount,
    unit: unit,
    state: state,
    isFree: isFree,
    note: note ?? this.note,
    warning: warning,
    ingredients: ingredients ?? this.ingredients,
    alternatives: alternatives ?? this.alternatives,
  );

  /// El mismo alimento con los datos de [edited] y conservando lo que lleva
  /// dentro (el formulario solo edita el renglón).
  ItemDraft replacedBy(ItemDraft edited) =>
      edited.copyWith(ingredients: ingredients, alternatives: alternatives);
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
