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

  for (final line in _joinContinuations(foodLines)) {
    final title = _menuTitle(line);
    if (title != null) {
      menus.add(_Menu(title, _dayTypeOf(title, menus.length, warnings)));
    } else if (_weighingHeader.hasMatch(line)) {
      weighingNotes ??= line;
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
    } else if (line.startsWith('◦') || line.startsWith('✦')) {
      if (menus.isEmpty || menus.last.meals.isEmpty) {
        warnings.add(
          'Hay un alimento fuera de una comida: "${line.substring(1).trim()}".',
        );
      } else {
        menus.last.meals.last.items.addAll(_parseItems(line.substring(1)));
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
      weighingNotes: weighingNotes,
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

/// "🟩 DÍAS ALTOS: Tren Inferior", "Días bajos", "Días de descanso".
final _dayHeader = RegExp(
  r'^D[IÍií]AS?\s+(ALTOS?|BAJOS?|DE\s+ENTRENAMIENTO|DE\s+DESCANSO)\b',
  caseSensitive: false,
);

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
        _weighingHeader.hasMatch(line);
    if (!startsNew && _isOpen(joined)) {
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
  // "Descanso / Sin entrenamiento" contiene las dos palabras: va primero.
  if (text.contains('descanso')) return DayType.rest;
  if (RegExp(r'\baltos?\b').hasMatch(text)) return DayType.high;
  if (RegExp(r'\bbajos?\b').hasMatch(text)) return DayType.low;
  if (text.contains('entren')) return DayType.training;
  warnings.add(
    'No se reconoció si el menú "$title" es de entrenamiento o de descanso.',
  );
  return index == 0 ? DayType.training : DayType.rest;
}

/// "1. Pre-Entreno (30 min antes de entrenar)" → nombre e indicación.
_Meal _parseMeal(String text) {
  final withoutNumber = text.trim().replaceFirst(RegExp(r'^\d+\s*[.)]\s*'), '');
  final match = RegExp(r'^(.*?)\s*\((.+)\)$').firstMatch(withoutNumber);
  return match == null
      ? _Meal(withoutNumber, null)
      : _Meal(match.group(1)!.trim(), match.group(2)!.trim());
}

/// Unidades que se reconocen, de la palabra más larga a la más corta para
/// que "cdta" no se lea como "cda".
const _unitWords =
    r'cucharaditas?|cucharadas?|cdtas?|cdas?|mililitros?|ml|tazas?|'
    r'rebanadas?|scoops?|piezas?|pzas?|gramos?|gr|g';

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
  if (w.startsWith('scoop')) return FoodUnit.scoop;
  if (w.startsWith('g')) return FoodUnit.gram;
  return FoodUnit.piece; // piezas, pzas, rebanadas
}

final _stateInParentheses = RegExp(
  r'\s*\((?:en\s+)?(crud[oa]s?|cocid[oa]s?|seco)\)',
  caseSensitive: false,
);

/// "2 tostadas horneadas": número entero y luego el alimento.
final _leadingCount = RegExp(r'^(\d+)\s+(\p{L}.*)$', unicode: true);

/// Medidas que no son piezas: con ellas el número no se interpreta.
final _measureWord = RegExp(
  '^($_unitWords|l|kg|oz)'
  r'\b',
  caseSensitive: false,
);

/// Etiquetas que a veces van antes del alimento: "Opcional: pepino".
final _itemLabel = RegExp(r'^(opcional|extra)$', caseSensitive: false);

/// "(1 cdta.)" → "1 cdta."; nada si no hay paréntesis.
String? _parenNote(String? paren) =>
    paren?.replaceAll(RegExp(r'^\(|\)$'), '').trim().ifEmptyNull;

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
  final line = text.trim().replaceFirst(RegExp(r'\.$'), '');
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
final _startsWithNumber = RegExp(r'^\d');

List<ItemDraft> _compound(String body) {
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
  final parts = body.split(RegExp(r'\s*\+\s*(?=\d)'));
  return [for (final part in parts) _withAlternatives(part.trim())];
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
  for (final part in text.split(RegExp(r'\s*(?:,|\s+y\s+)\s*(?=\d)')))
    _withAlternatives(part.trim()),
];

/// "1 manzana verde ó 1 taza de fresas": el primero con los demás como
/// alternativas. Solo se corta donde la alternativa trae su propia cantidad.
ItemDraft _withAlternatives(String text) {
  final parts = text.split(
    RegExp(r'\s+(?:ó|o|u)\s+(?=\d)', caseSensitive: false),
  );
  final first = _parseItem(parts.first);
  if (parts.length == 1) return first;
  return first.copyWith(
    alternatives: [for (final part in parts.skip(1)) _parseItem(part)],
  );
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
  } else if (_leadingCount.firstMatch(line) case final match?
      when !_measureWord.hasMatch(match.group(2)!)) {
    // "2 tostadas horneadas": un número sin unidad son piezas.
    name = match.group(2)!.trim();
    quantity = '${match.group(1)} piezas';
  }

  final (state, foundStateWarning) = _stateOf(name);
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
      isFree: RegExp(r'\blibres?\b', caseSensitive: false).hasMatch(name),
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
    if (RegExp(r'\bseco\b').hasMatch(text)) FoodState.dry,
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
  r'^(?:•\s*)?(Dosis(?: diaria)?|Momento(?: de toma)?|Beneficios?|Objetivos?)\s*:\s*(.*)$',
  caseSensitive: false,
);

/// La guía de suplementos: un renglón con el nombre y, debajo, sus campos.
List<SupplementDraft> _parseSupplements(List<String> lines) {
  final supplements = <SupplementDraft>[];
  String? name;
  final fields = <String, String>{};
  String? current;

  void flush() {
    if (name case final supplementName? when supplementName.isNotEmpty) {
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
      // d, m o b; el "objetivo" es el beneficio.
      final key = field.group(1)!.toLowerCase()[0];
      current = key == 'o' ? 'b' : key;
      fields[current!] = field.group(2)!.trim();
    } else if (current != null && !_looksLikeName(line, fields)) {
      // Continuación del campo anterior, partido en dos renglones.
      fields[current!] = '${fields[current!]} $line';
    } else {
      flush();
      name = line
          .replaceFirst(RegExp(r'^•\s*'), '')
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
  final benefit = fields['b'];
  return benefit != null && benefit.trimRight().endsWith('.');
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}
