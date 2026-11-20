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
        menus.last.meals.last.items.add(_parseItem(line.substring(1)));
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

final _leadingQuantity = RegExp(
  r'^(\d+(?:[.,]\d+)?|\d+/\d+)\s*(scoops?|piezas?|pzas?|g|gr|gramos?)\s+de\s+(.+)$',
  caseSensitive: false,
);
final _stateInParentheses = RegExp(
  r'\s*\((?:en\s+)?(crud[oa]s?|cocid[oa]s?|seco)\)',
  caseSensitive: false,
);

/// "2 tostadas horneadas": número entero y luego el alimento.
final _leadingCount = RegExp(r'^(\d+)\s+(\p{L}.*)$', unicode: true);

/// Medidas que no son piezas: con ellas el número no se interpreta.
final _measureWord = RegExp(
  r'^(ml|l|kg|oz|tazas?|cdas?|cdtas?|cucharadas?|cucharaditas?|scoops?|g|gr|gramos?)\b',
  caseSensitive: false,
);

/// Etiquetas que a veces van antes del alimento: "Opcional: pepino".
final _itemLabel = RegExp(r'^(opcional|extra)$', caseSensitive: false);

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
    label = left;
    name = quantityFirst.group(3)!.trim();
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
    name = match.group(3)!.trim();
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

  final match = RegExp(r'^(\d+/\d+|\d+(?:[.,]\d+)?)\s*(.*)$').firstMatch(text);
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
    r'^(gramos?|gr|g|piezas?|pzas?|scoops?)(?![a-záéíóúñ])\s*(.*)$',
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

  final unit = switch (unitMatch.group(1)!.toLowerCase()[0]) {
    'g' => FoodUnit.gram,
    'p' => FoodUnit.piece,
    _ => FoodUnit.scoop,
  };
  return (
    amount: amount,
    unit: unit,
    isFree: false,
    note: _cleanNote(unitMatch.group(2)!),
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
