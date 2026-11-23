import '../domain/nutrition.dart';

/// Resultado de leer un plan: el borrador y lo que no se pudo interpretar.
class ParsedNutritionPlan {
  const ParsedNutritionPlan({required this.draft, required this.warnings});

  final NutritionPlanDraft draft;

  /// Problemas generales del documento (los de un alimento van en su
  /// [ItemDraft.warning]).
  final List<String> warnings;

  /// Cuántas cosas debe revisar el usuario antes de guardar.
  int get warningCount =>
      warnings.length + draft.items.where((i) => i.warning != null).length;
}

/// Convierte el texto de un plan de alimentación en un borrador (ADR-0009).
///
/// Reconoce las dos formas de escribir planes que se han visto:
///
/// ```
/// Título del plan
/// Menú 1: Días de Entrenamiento          🟩 DÍAS ALTOS: Tren inferior
/// Indicaciones de pesaje: …
/// • 1. Desayuno (indicación de horario)  1. Al despertar
/// ◦ Alimento (crudo): 130 g              ◦ 130 g de alimento (en crudo).
/// Guía de Suplementación
/// Nombre del suplemento                  •
/// • Dosis: …   • Momento de toma: …      Nombre:
/// • Beneficio: …                         Dosis: …   Objetivo: …
/// ```
///
/// No adivina: lo que no reconoce lo deja como está y lo marca con una
/// advertencia para que el usuario lo corrija en la revisión.
ParsedNutritionPlan parseNutritionPlan(String text, {String? fileName}) {
  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final supplementsStart = lines.indexWhere(_supplementsHeader.hasMatch);
  final foodLines = supplementsStart < 0
      ? lines
      : lines.sublist(0, supplementsStart);
  final supplementLines = supplementsStart < 0
      ? const <String>[]
      : lines.sublist(supplementsStart + 1);

  final warnings = <String>[];
  final menus = <_Menu>[];
  String? name;
  String? weighingNotes;
  // Recomendaciones al final ("💡 Claves para…", "Recomendaciones"): sus
  // renglones numerados son consejos, no comidas.
  final notes = <String>[];
  var inNotes = false;
  // El renglón anterior terminó en "o": este es su alternativa.
  var pendingAlternative = false;

  for (final line in _joinContinuations(foodLines)) {
    final title = _menuTitle(line);
    if (title != null) {
      menus.add(_Menu(title, _dayTypeOf(title, menus.length, warnings)));
      inNotes = false;
      pendingAlternative = false;
    } else if (inNotes) {
      // Cada viñeta o número empieza un consejo; lo demás lo continúa.
      if (notes.length == 1 || _startsNote.hasMatch(line)) {
        notes.add(line.replaceFirst(_startsNote, ''));
      } else {
        notes[notes.length - 1] = '${notes.last} $line';
      }
    } else if (_weighingHeader.hasMatch(line)) {
      weighingNotes ??= line;
    } else if (name != null && _isNotesHeader(line)) {
      inNotes = true;
      notes.add(line.replaceFirst(_leadingSymbols, ''));
    } else if (line.startsWith('•') || _numberedMeal.hasMatch(line)) {
      if (menus.isEmpty) {
        warnings.add(
          'El plan no indica si es para días de entrenamiento o de '
          'descanso; se guardó como entrenamiento.',
        );
        menus.add(_Menu('Menú', DayType.training));
      }
      menus.last.meals.add(
        _parseMeal(line.startsWith('•') ? line.substring(1) : line),
      );
      pendingAlternative = false;
    } else if (line.startsWith('◦') || line.startsWith('✦')) {
      if (menus.isEmpty || menus.last.meals.isEmpty) {
        warnings.add(
          'Hay un alimento fuera de una comida: "${line.substring(1).trim()}".',
        );
        continue;
      }
      // "180 g de yogur o" + "20 g de almendras", o un renglón que empieza
      // con "o": la alternativa viene en el renglón siguiente.
      var body = line.substring(1).trim();
      final isAlternative = pendingAlternative || _leadingOr.hasMatch(body);
      body = body.replaceFirst(_leadingOr, '');
      pendingAlternative = _trailingOr.hasMatch(body);
      body = body.replaceFirst(_trailingOr, '');
      final items = _parseItems(body);
      final meal = menus.last.meals.last;
      if (isAlternative && meal.items.isNotEmpty && items.isNotEmpty) {
        final previous = meal.items.removeLast();
        meal.items
          ..add(
            previous.copyWith(
              alternatives: [...previous.alternatives, items.first],
            ),
          )
          ..addAll(items.skip(1));
      } else {
        meal.items.addAll(items);
      }
    } else {
      // Lo primero que no es encabezado ni viñeta es el título del plan.
      name ??= line;
    }
  }

  if (menus.every((menu) => menu.meals.isEmpty)) {
    warnings.add('No se encontró ninguna comida en el documento.');
  }

  return ParsedNutritionPlan(
    warnings: warnings,
    draft: NutritionPlanDraft(
      name: name ?? 'Plan de alimentación',
      sourceFileName: fileName,
      // Se muestran juntas en la tarjeta de indicaciones del plan.
      weighingNotes: [?weighingNotes, ...notes].join('\n\n').ifEmptyNull,
      supplements: _parseSupplements(supplementLines),
      menus: [
        for (final menu in menus)
          MenuDraft(
            dayType: menu.dayType,
            title: menu.title,
            meals: [
              for (final meal in menu.meals)
                MealDraft(
                  name: meal.name,
                  timingNote: meal.timingNote,
                  items: meal.items,
                ),
            ],
          ),
      ],
    ),
  );
}

final _menuHeader = RegExp(r'^Men[uú]\s*\d*\s*:\s*(.+)$', caseSensitive: false);

/// "🟩 DÍAS ALTOS: Tren Inferior", "Días bajos en carbohidratos", "Días de
/// descanso", "📈 DÍAS DE MAYOR DEMANDA", "Días de carga".
final _dayHeader = RegExp(
  r'^D[IÍií]AS?\s+(?:DE\s+)?(?:ALT[OA]S?|BAJ[OA]S?|ENTRENAMIENTO|ENTRENO|'
  r'DESCANSO|MAYOR|MENOR|M[AÁ]S|MENOS|CARGA|RECARGA|SIN\s+ENTRENA)',
  caseSensitive: false,
);

/// El inicio de una sección de recomendaciones al final del plan.
final _notesKeyword = RegExp(
  r'^(?:recomendaciones|indicaciones\s+generales|notas?|claves|consejos|'
  r'observaciones|tips|importante)\b',
  caseSensitive: false,
);

/// Un renglón que empieza con emoji: "💡 Claves para…".
final _startsWithEmoji = RegExp(r'^\p{Extended_Pictographic}', unicode: true);

/// Palabras de comida: un "🍳 Desayuno" es una comida, no recomendaciones.
final _mealWord = RegExp(
  r'desayuno|comida|cena|colaci[oó]n|almuerzo|merienda|snack|entreno',
  caseSensitive: false,
);

/// Viñeta o número que empieza un consejo dentro de las recomendaciones.
final _startsNote = RegExp(r'^(?:[•◦✦]\s*|\d+\s*[.)]\s+)');

/// "o" que une un alimento con el del renglón siguiente.
final _leadingOr = RegExp(r'^(?:ó|o|u)\s+', caseSensitive: false);
final _trailingOr = RegExp(r'\s+(?:ó|o|u)\.?$', caseSensitive: false);

/// Si el renglón abre la sección de recomendaciones: un título con emoji o
/// con una palabra como "Recomendaciones", sin viñeta.
bool _isNotesHeader(String line) {
  if (line.startsWith('•') || line.startsWith('◦') || line.startsWith('✦')) {
    return false;
  }
  final text = line.replaceFirst(_leadingSymbols, '');
  if (_notesKeyword.hasMatch(text)) return true;
  return _startsWithEmoji.hasMatch(line) && !_mealWord.hasMatch(text);
}

/// Lo que va antes de la primera letra o número: viñetas y emojis.
final _leadingSymbols = RegExp(r'^[^\p{L}\p{N}]+', unicode: true);

/// "1. Al Despertar": una comida numerada sin viñeta. Se exige que empiece
/// con letra para no confundirla con una cantidad.
final _numberedMeal = RegExp(r'^\d+\s*[.)]\s+\p{L}', unicode: true);

/// El título del menú si el renglón es un encabezado de menú.
String? _menuTitle(String line) {
  if (_menuHeader.firstMatch(line) case final match?) {
    return match.group(1)!.trim();
  }
  final text = line.replaceFirst(_leadingSymbols, '');
  return _dayHeader.hasMatch(text) ? text : null;
}

final _weighingHeader = RegExp(
  r'^Indicaciones de pesaje',
  caseSensitive: false,
);
final _supplementsHeader = RegExp(
  r'^Gu[iíÍI]a de Suplement',
  caseSensitive: false,
);

class _Menu {
  _Menu(this.title, this.dayType);

  final String title;
  final DayType dayType;
  final meals = <_Meal>[];
}

class _Meal {
  _Meal(this.name, this.timingNote);

  final String name;
  final String? timingNote;
  final items = <ItemDraft>[];
}

/// Une cada renglón partido con el anterior. Un renglón empieza algo nuevo
/// solo si arranca con viñeta o con un encabezado conocido; lo demás es la
/// continuación de un texto que no cupo en una línea del PDF.
List<String> _joinContinuations(List<String> lines) {
  final joined = <String>[];
  for (final line in lines) {
    final startsNew =
        line.startsWith('•') ||
        line.startsWith('◦') ||
        line.startsWith('✦') ||
        _numberedMeal.hasMatch(line) ||
        _menuTitle(line) != null ||
        _weighingHeader.hasMatch(line) ||
        (joined.isNotEmpty && _isNotesHeader(line));
    // "Días bajos en carbohidratos" + "(Tríceps, Hombro y Descanso)": el
    // paréntesis completa el título del menú.
    final completesTitle =
        line.startsWith('(') &&
        joined.isNotEmpty &&
        _menuTitle(joined.last) != null;
    if (!startsNew && (_isOpen(joined) || completesTitle)) {
      joined[joined.length - 1] = '${joined.last} $line';
    } else {
      joined.add(line);
    }
  }
  return joined;
}

/// Si el último renglón es una viñeta o encabezado que puede continuar.
bool _isOpen(List<String> joined) {
  if (joined.isEmpty) return false;
  final last = joined.last;
  return last.startsWith('•') ||
      last.startsWith('◦') ||
      last.startsWith('✦') ||
      _weighingHeader.hasMatch(last);
}

DayType _dayTypeOf(String title, int index, List<String> warnings) {
  final text = title.toLowerCase();
  // Alto y bajo van primero: "Días de menor demanda / descanso" es el día
  // bajo de un plan que también tiene día alto. De lo más explícito a lo
  // menos: "Días bajos (Menos carbohidratos, más grasas)" es bajo.
  for (final (high, low) in [
    (r'alt[oa]s?', r'baj[oa]s?'),
    (r'mayor|carga|recarga', r'menor'),
    (r'm[aá]s', r'menos'),
  ]) {
    if (RegExp(
      '(?<![\\p{L}])(?:$high)(?![\\p{L}])',
      unicode: true,
    ).hasMatch(text)) {
      return DayType.high;
    }
    if (RegExp(
      '(?<![\\p{L}])(?:$low)(?![\\p{L}])',
      unicode: true,
    ).hasMatch(text)) {
      return DayType.low;
    }
  }
  // "Descanso / Sin entrenamiento" contiene las dos palabras: va antes.
  if (text.contains('descanso')) return DayType.rest;
  if (text.contains('entren')) return DayType.training;
  warnings.add(
    'No se reconoció si el menú "$title" es de entrenamiento o de descanso.',
  );
  return index == 0 ? DayType.training : DayType.rest;
}

/// "Comida: 150 g de pollo + 120 g de arroz": la comida con sus alimentos en
/// el mismo renglón. El nombre no lleva paréntesis y los dos puntos no son
/// de una hora ("a las 7:30").
final _inlineMeal = RegExp(
  r'^([^:()]{1,40}?)\s*:(?!\d)(?!\s*\d{1,2}[:.]\d{2})\s*(.*\d.*)$',
);

/// "1. Pre-Entreno (30 min antes de entrenar)" → nombre e indicación.
_Meal _parseMeal(String text) {
  final withoutNumber = text.trim().replaceFirst(RegExp(r'^\d+\s*[.)]\s*'), '');
  if (_inlineMeal.firstMatch(withoutNumber) case final inline?) {
    return _Meal(inline.group(1)!.trim(), null)
      ..items.addAll(_parseItems(inline.group(2)!));
  }
  final match = RegExp(r'^(.*?)\s*\((.+)\)$').firstMatch(withoutNumber);
  return match == null
      ? _Meal(withoutNumber, null)
      : _Meal(match.group(1)!.trim(), match.group(2)!.trim());
}

/// Unidades que se reconocen, de la palabra más larga a la más corta para
/// que "cdta" no se lea como "cda".
const _unitWords =
    r'cucharaditas?|cucharadas?|cdtas?|cdas?|mililitros?|ml|tazas?|'
    r'rebanadas?|scoops?|medidas?|piezas?|pzas?|gramos?|gr|g';

/// "130 g de pechuga", "5 ml (1 cdta.) de aceite", "30-40 g de avena".
/// Grupos: cantidad, unidad, paréntesis opcional y alimento.
final _leadingQuantity = RegExp(
  r'^(\d+(?:[.,]\d+)?(?:\s*[-–]\s*\d+(?:[.,]\d+)?)?|\d+/\d+)\s*'
  '($_unitWords)'
  r'\.?\s*(\([^)]*\))?\s+de\s+(.+)$',
  caseSensitive: false,
);

/// La unidad que corresponde a una palabra de [_unitWords].
FoodUnit _unitOf(String word) {
  final w = word.toLowerCase();
  if (w.startsWith('cucharadita') || w.startsWith('cdta')) {
    return FoodUnit.teaspoon;
  }
  if (w.startsWith('cucharada') || w.startsWith('cda')) {
    return FoodUnit.tablespoon;
  }
  if (w.startsWith('mililitro') || w == 'ml') return FoodUnit.ml;
  if (w.startsWith('taza')) return FoodUnit.cup;
  if (w.startsWith('scoop') || w.startsWith('medida')) return FoodUnit.scoop;
  if (w.startsWith('g')) return FoodUnit.gram;
  return FoodUnit.piece; // piezas, pzas, rebanadas
}

/// "(crudo)", "(en crudo)", "(peso en crudo)", "(pesado ya cocido)".
final _stateInParentheses = RegExp(
  r'\s*\((?:[^()]*\s)?(crud[oa]s?|cocid[oa]s?|sec[oa]s?)\)',
  caseSensitive: false,
);

/// "2 tostadas horneadas", "1/4 de aguacate": un número o fracción y luego
/// el alimento.
final _leadingCount = RegExp(
  r'^(\d+/\d+|\d+(?:[.,]\d+)?)\s+(?:de\s+)?(\p{L}.*)$',
  unicode: true,
);

/// "Arroz cocido 180 gr": el nombre y, al final, la cantidad con su unidad.
final _trailingQuantity = RegExp(
  r'^(\p{L}[^\d]*?)\s+(\d+(?:[.,]\d+)?\s*(?:'
  '$_unitWords'
  r'))\.?$',
  caseSensitive: false,
  unicode: true,
);

/// Fracciones de un solo carácter: "½ plátano".
const _fractions = {'½': '1/2', '¼': '1/4', '¾': '3/4', '⅓': '1/3', '⅔': '2/3'};

/// Medidas que no son piezas: con ellas el número no se interpreta.
final _measureWord = RegExp(
  '^($_unitWords|l|kg|oz)'
  r'\b',
  caseSensitive: false,
);

/// Etiquetas que a veces van antes del alimento: "Opcional: pepino".
final _itemLabel = RegExp(r'^(opcional|extra)$', caseSensitive: false);

/// "(1 cdta.)" → "1 cdta."; nada si no hay paréntesis o si solo repite la
/// unidad ("1 medida (scoop)").
String? _parenNote(String? paren) {
  final note = paren?.replaceAll(RegExp(r'^\(|\)$'), '').trim();
  if (note == null ||
      RegExp('^($_unitWords)\$', caseSensitive: false).hasMatch(note)) {
    return null;
  }
  return note.ifEmptyNull;
}

/// Un renglón de alimento, que puede traer varios (ADR-0023):
///
/// - **un plato con ingredientes:** "Sándwich en pan integral (2 rebanadas)
///   con 90 g de pavo u 80 g de panela" → Sándwich, con pan y pavo (o
///   panela);
/// - **alimentos sumados:** "3 claras de huevo + 1 huevo entero" → dos;
/// - **alternativas con su propia cantidad:** "1 manzana ó 1 taza de
///   fresas" → manzana, con fresas como alternativa.
///
/// El formato "Nombre: cantidad" es siempre un solo alimento.
List<ItemDraft> _parseItems(String text) {
  var line = text.trim().replaceFirst(RegExp(r'\.$'), '');
  for (final MapEntry(:key, :value) in _fractions.entries) {
    line = line.replaceAll(RegExp('(?<=\\d)$key'), ' $value');
    line = line.replaceAll(key, value);
  }
  line = _balanceParentheses(line);
  final colon = line.indexOf(':');
  if (colon < 0) return _compound(line);

  final left = line.substring(0, colon).trim();
  final right = line.substring(colon + 1).trim();
  final labeled = _itemLabel.hasMatch(left) || _leadingQuantity.hasMatch(right);
  if (!labeled) return [_parseItem(line)];

  // "Más proteína: 140 g de pechuga", "Opcional: pepino": la etiqueta va
  // como nota del primero.
  final items = _compound(right);
  final first = items.first;
  items[0] = ItemDraft(
    name: first.name,
    amount: first.amount,
    unit: first.unit,
    state: first.state,
    isFree: first.isFree,
    note: [left, ?first.note].join(' · '),
    warning: first.warning,
    ingredients: first.ingredients,
    alternatives: first.alternatives,
  );
  return items;
}

/// "Sándwich … con 90 g de …": el plato y lo que lleva. Lo que sigue a "con"
/// debe empezar con una cantidad; si no, es parte del nombre ("proteína
/// mezclada con agua").
final _dish = RegExp(r'^(.+?)\s+con\s+(?=\d)(.+)$', caseSensitive: false);

/// "Omelet de 1 huevo entero y 4 claras", "Hot cakes (1 huevo, 4 claras y
/// 70 g de avena)": un plato cuyos ingredientes traen su cantidad.
final _dishOf = RegExp(r'^(\p{L}[^\d(]*?)\s+de\s+(?=\d)(.+)$', unicode: true);
final _dishParen = RegExp(r'^(\p{L}[^\d(]*?)\s*\((\d[^()]*)\)$', unicode: true);
final _startsWithNumber = RegExp(r'^\d');

List<ItemDraft> _compound(String body) => [
  for (final part in body.split(RegExp(r'\s*\+\s*')))
    if (part.trim().isNotEmpty) ..._dishOrItem(part.trim()),
];

/// Un paréntesis que el PDF dejó abierto ("3 claras de huevo (") se quita
/// si quedó vacío o se cierra si traía algo.
String _balanceParentheses(String text) {
  final open = '('.allMatches(text).length;
  final close = ')'.allMatches(text).length;
  if (open <= close) return text;
  final trimmed = text.replaceFirst(RegExp(r'\s*\(\s*$'), '');
  return trimmed.length < text.length ? trimmed : '$text)';
}

/// Una parte de un renglón: un plato con ingredientes o un alimento.
List<ItemDraft> _dishOrItem(String body) {
  if ((_dishParen.firstMatch(body) ?? _dishOf.firstMatch(body))
      case final dish?) {
    final name = dish.group(1)!.trim();
    return [
      ItemDraft(
        name: name[0].toUpperCase() + name.substring(1),
        ingredients: _ingredientList(dish.group(2)!),
      ),
    ];
  }
  if (_dish.firstMatch(body) case final dish?) {
    final head = dish.group(1)!.trim();
    final ingredients = _ingredientList(dish.group(2)!);
    if (_startsWithNumber.hasMatch(head)) {
      // "1 scoop de proteína con 200 ml de leche": dos alimentos sueltos.
      return [_withAlternatives(head), ...ingredients];
    }
    // "Sándwich en pan integral (2 rebanadas)": el plato y su base.
    final base = RegExp(r'^(.+?)\s+en\s+(.+)$').firstMatch(head);
    final dishName = base?.group(1) ?? head;
    return [
      ItemDraft(
        name: dishName[0].toUpperCase() + dishName.substring(1),
        ingredients: [?_baseIngredient(base?.group(2)), ...ingredients],
      ),
    ];
  }
  return [_withAlternatives(body)];
}

/// "pan integral (2 rebanadas)" → 2 piezas de pan integral.
ItemDraft? _baseIngredient(String? text) {
  if (text == null) return null;
  final paren = RegExp(r'\s*\(([^)]*?(\d+)[^)]*)\)').firstMatch(text);
  if (paren == null) return _parseItem(text);
  final name = text.replaceRange(paren.start, paren.end, '').trim();
  final inside = paren.group(1)!.trim();
  return ItemDraft(
    name: name,
    amount: double.parse(paren.group(2)!),
    unit: FoodUnit.piece,
    // "2 rebanadas" ya lo dice la cantidad; "solo 1 rebanada abierta" no.
    note: RegExp(r'^\d+\s+\p{L}+$', unicode: true).hasMatch(inside)
        ? inside.replaceFirst(RegExp(r'^\d+\s+'), '')
        : inside,
  );
}

/// "90 g de pavo, 30 g de queso y 1 cdta. de mostaza" → tres ingredientes.
List<ItemDraft> _ingredientList(String text) => [
  for (final part in text.split(RegExp(r'\s*(?:,|\s+y\s+|\s+con\s+)\s*(?=\d)')))
    _withAlternatives(part.trim()),
];

/// "1 manzana verde ó 1 taza de fresas": el primero con los demás como
/// alternativas. Solo se corta donde la alternativa trae su propia cantidad.
ItemDraft _withAlternatives(String text) {
  // "1/2 plátano (o 20 g de Nestum si entrenas)": la alternativa entre
  // paréntesis, con su condición como nota.
  if (_parenAlternative.firstMatch(text) case final m?) {
    final main = _withAlternatives(m.group(1)!);
    return main.copyWith(
      alternatives: [...main.alternatives, _conditional(m.group(2)!)],
    );
  }
  final parts = text.split(
    RegExp(r'\s+(?:ó|o|u)\s+(?=\d)', caseSensitive: false),
  );
  final first = _parseItem(parts.first);
  if (parts.length == 1) return first;
  return first.copyWith(
    alternatives: [for (final part in parts.skip(1)) _parseItem(part)],
  );
}

final _parenAlternative = RegExp(
  r'^(.*?)\s*\(\s*(?:ó|o|u)\s+(\d[^()]*)\)\s*$',
  caseSensitive: false,
);

/// "20 g de Nestum de arroz si entrenas" → el alimento con "Si entrenas"
/// como nota.
ItemDraft _conditional(String text) {
  final m = RegExp(
    r'^(.*?)\s+(si\s+.+)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return _parseItem(text);
  final item = _parseItem(m.group(1)!);
  final condition = m.group(2)!;
  final note = condition[0].toUpperCase() + condition.substring(1);
  return item.copyWith(note: [?item.note, note].join(' · '));
}

/// Un renglón de alimento: "Nombre (crudo): 130 g" y sus variantes.
ItemDraft _parseItem(String text) {
  // El punto final es de redacción, no del nombre.
  final line = text.trim().replaceFirst(RegExp(r'\.$'), '');
  var name = line;
  String? quantity;
  String? label;

  final colon = line.indexOf(':');
  final left = colon >= 0 ? line.substring(0, colon).trim() : '';
  final right = colon >= 0 ? line.substring(colon + 1).trim() : line;
  final quantityFirst = colon >= 0 ? _leadingQuantity.firstMatch(right) : null;
  if (quantityFirst != null) {
    // "Más proteína: 140 g de pechuga": la etiqueta queda como nota.
    label = [left, ?_parenNote(quantityFirst.group(3))].join(' · ');
    name = quantityFirst.group(4)!.trim();
    quantity = '${quantityFirst.group(1)} ${quantityFirst.group(2)}';
  } else if (colon >= 0 && _itemLabel.hasMatch(left)) {
    // "Opcional: pepino con limón": sin cantidad.
    label = left;
    name = right;
  } else if (colon >= 0) {
    name = left;
    quantity = right;
  } else if (_leadingQuantity.firstMatch(line) case final match?) {
    // "1 scoop de Proteína en polvo": la cantidad va antes del nombre.
    label = _parenNote(match.group(3));
    name = match.group(4)!.trim();
    quantity = '${match.group(1)} ${match.group(2)}';
  } else if (_trailingQuantity.firstMatch(line) case final match?) {
    // "Arroz cocido 180 gr": la cantidad al final, sin dos puntos.
    name = match.group(1)!.trim();
    quantity = match.group(2)!;
  } else if (_leadingCount.firstMatch(line) case final match?
      when !_measureWord.hasMatch(match.group(2)!)) {
    // "2 tostadas horneadas": un número sin unidad son piezas.
    name = match.group(2)!.trim();
    quantity = '${match.group(1)} piezas';
  }

  // "(pesadas en seco) cocidas con agua": el paréntesis dice cómo se pesa;
  // lo demás describe cómo se prepara.
  final weighed = _stateInParentheses.allMatches(name).map((m) => m.group(1)!);
  final (state, foundStateWarning) = _stateOf(
    weighed.isEmpty ? name : weighed.join(' '),
  );
  name = name.replaceAll(_stateInParentheses, '').trim();
  // Una cifra que sigue en el nombre es otra cantidad: "1 manzana ó 1 taza
  // de fresas", "pan (2 rebanadas) con 90 g de pavo". No se adivina cuál.
  final stateWarning =
      foundStateWarning ??
      (RegExp(r'\d').hasMatch(name)
          ? 'El renglón trae más de una cantidad; revisa cuál usar.'
          : null);

  if (quantity == null || quantity.isEmpty) {
    // Sin cantidad: "Verduras mixtas", "…alguna otra verdura libre".
    return ItemDraft(
      name: name,
      state: state,
      isFree: RegExp(
        r'\blibres?\b|\bal gusto\b',
        caseSensitive: false,
      ).hasMatch(name),
      note: label,
      warning: stateWarning,
    );
  }

  final q = _parseQuantity(quantity);
  return ItemDraft(
    name: name,
    amount: q.amount,
    unit: q.unit,
    isFree: q.isFree,
    note: [?label, ?q.note].join(' · ').ifEmptyNull,
    state: state,
    warning: q.warning ?? stateWarning,
  );
}

/// Estado de pesaje según las palabras del nombre. Si aparecen dos estados
/// distintos (dos alternativas que se pesan diferente) no elige ninguno.
(FoodState, String?) _stateOf(String name) {
  final text = name.toLowerCase();
  final found = {
    if (RegExp(r'\bcrud[oa]s?\b').hasMatch(text)) FoodState.raw,
    if (RegExp(r'\bcocid[oa]s?\b').hasMatch(text)) FoodState.cooked,
    if (RegExp(r'\bsec[oa]s?\b').hasMatch(text)) FoodState.dry,
  };
  return switch (found.length) {
    0 => (FoodState.unspecified, null),
    1 => (found.single, null),
    _ => (
      FoodState.unspecified,
      'Las alternativas se pesan de forma distinta; indica cómo se pesa.',
    ),
  };
}

typedef _Quantity = ({
  double? amount,
  FoodUnit? unit,
  bool isFree,
  String? note,
  String? warning,
});

/// La parte derecha de "Alimento: …".
_Quantity _parseQuantity(String raw) {
  // Restos de fórmula que a veces deja el editor: "100 \text{ g}" → "100 g".
  final text = raw
      .replaceAllMapped(RegExp(r'\\text\{\s*(.*?)\s*\}'), (m) => m.group(1)!)
      .trim();

  final free = RegExp(
    r'^libres?\b\s*(.*)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (free != null) {
    return (
      amount: null,
      unit: null,
      isFree: true,
      note: _cleanNote(free.group(1)!),
      warning: null,
    );
  }

  // "30-40 g": se toma el mínimo y el rango queda en la nota.
  String? rangeNote;
  final range = RegExp(r'^(\d+(?:[.,]\d+)?)\s*[-–]\s*(\d+(?:[.,]\d+)?)\s*(.*)$')
      .firstMatch(text);
  final source = range == null ? text : '${range.group(1)} ${range.group(3)}';
  if (range != null) {
    rangeNote = 'Entre ${range.group(1)} y ${range.group(2)}';
  }
  final match = RegExp(r'^(\d+/\d+|\d+(?:[.,]\d+)?)\s*(.*)$')
      .firstMatch(source);
  if (match == null) {
    return (
      amount: null,
      unit: null,
      isFree: false,
      note: text,
      warning: 'No se entendió la cantidad "$text".',
    );
  }

  final amount = _parseNumber(match.group(1)!);
  final rest = match.group(2)!.trim();
  if (rest.isEmpty) {
    return (
      amount: amount,
      unit: null,
      isFree: false,
      note: null,
      warning: 'La cantidad no trae unidad; indica si son gramos o piezas.',
    );
  }

  final unitMatch = RegExp(
    '^($_unitWords)'
    r'(?![a-záéíóúñ])\.?\s*(.*)$',
    caseSensitive: false,
  ).firstMatch(rest);
  if (unitMatch == null) {
    return (
      amount: amount,
      unit: null,
      isFree: false,
      note: null,
      warning: 'No se reconoció la unidad "$rest".',
    );
  }

  final unit = _unitOf(unitMatch.group(1)!);
  if (rangeNote != null) rangeNote = '$rangeNote ${unitMatch.group(1)}';
  return (
    amount: amount,
    unit: unit,
    isFree: false,
    note: [
      ?rangeNote,
      ?_cleanNote(unitMatch.group(2)!),
    ].join(' · ').ifEmptyNull,
    warning: null,
  );
}

double _parseNumber(String text) {
  if (text.contains('/')) {
    final [numerator, denominator] = text.split('/');
    return int.parse(numerator) / int.parse(denominator);
  }
  return double.parse(text.replaceAll(',', '.'));
}

/// Lo que queda tras la cantidad: quita separadores y paréntesis sobrantes.
String? _cleanNote(String text) {
  var note = text.trim().replaceFirst(RegExp(r'^[/,;-]\s*'), '');
  final wrapped = RegExp(r'^\((.*)\)$').firstMatch(note);
  if (wrapped != null) note = wrapped.group(1)!.trim();
  return note.isEmpty ? null : note;
}

final _supplementField = RegExp(
  r'^(?:•\s*)?(Dosis(?: diaria)?|Momento(?: de toma)?|Cu[aá]ndo|Beneficios?|'
  r'Objetivos?|Para qu[eé])\s*:\s*(.*)$',
  caseSensitive: false,
);

/// La guía de suplementos: un renglón con el nombre y, debajo, sus campos.
List<SupplementDraft> _parseSupplements(List<String> lines) {
  final supplements = <SupplementDraft>[];
  String? name;
  final fields = <String, String>{};
  String? current;
  // Si los nombres terminan en dos puntos ("Inositol:"), un renglón sin
  // ellos y sin dosis ni momento es un título de sección, no un suplemento.
  final namesEndWithColon = lines.any(
    (line) => line.endsWith(':') && !_supplementField.hasMatch(line),
  );
  var nameHadColon = false;

  void flush() {
    final isHeading = fields.isEmpty && namesEndWithColon && !nameHadColon;
    if (name case final supplementName?
        when supplementName.isNotEmpty && !isHeading) {
      supplements.add(
        SupplementDraft(
          name: supplementName,
          dose: fields['d'],
          timing: fields['m'],
          benefit: fields['b'],
        ),
      );
    }
    fields.clear();
    current = null;
  }

  for (final line in lines) {
    if (line == '•') {
      // Una viñeta sola separa un suplemento del siguiente.
      flush();
      name = null;
      continue;
    }
    final field = _supplementField.firstMatch(line);
    if (field != null) {
      // d, m o b: "cuándo" es el momento; "objetivo" y "para qué", el
      // beneficio.
      final key = field.group(1)!.toLowerCase()[0];
      current = switch (key) {
        'c' => 'm',
        'o' || 'p' => 'b',
        _ => key,
      };
      fields[current!] = field.group(2)!.trim();
    } else if (current != null && !_looksLikeName(line, fields)) {
      // Continuación del campo anterior, partido en dos renglones.
      fields[current!] = '${fields[current!]} $line';
    } else if (name != null &&
        fields.isEmpty &&
        _balanceParentheses(name) != name) {
      // "Soporte Metabólico (Enfoque SOP /" + "Resistencia a la Insulina)".
      name = '$name $line';
      nameHadColon = line.endsWith(':');
    } else {
      flush();
      nameHadColon = line.endsWith(':');
      name = line
          .replaceFirst(RegExp(r'^•\s*'), '')
          .replaceFirst(RegExp(r'^\d+\s*[.)]\s*'), '')
          .replaceFirst(RegExp(r':$'), '')
          .trim();
    }
  }
  flush();
  return supplements;
}

/// Un renglón sin etiqueta es el nombre del siguiente suplemento solo cuando
/// el actual ya tiene su último campo (el beneficio) terminado en punto.
bool _looksLikeName(String line, Map<String, String> fields) {
  // "2. Creatina:": numerado o terminado en dos puntos, es otro suplemento.
  if (RegExp(r'^\d+\s*[.)]\s+\p{L}', unicode: true).hasMatch(line) ||
      line.endsWith(':')) {
    return true;
  }
  final benefit = fields['b'];
  return benefit != null && benefit.trimRight().endsWith('.');
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}
