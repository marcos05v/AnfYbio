import 'catalog_exercise.dart';

/// Texto reducido a lo comparable: minúsculas, sin acentos y sin signos.
String normalizeText(String text) {
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  return text
      .toLowerCase()
      .split('')
      .map((char) => accents[char] ?? char)
      .join()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

/// Palabras que no ayudan a distinguir un ejercicio de otro.
const _stopwords = {
  // español
  'de', 'del', 'con', 'en', 'a', 'al', 'la', 'el', 'los', 'las', 'y', 'o',
  'por', 'para', 'un', 'una', 'sobre',
  // inglés
  'the', 'with', 'on', 'to', 'of', 'and', 'an', 'in', 'from',
  // Relleno: "curl tipo martillo", "agarre medio".
  'agarre', 'grip', 'medio', 'medium', 'tipo',
};

/// Variantes que son la versión por defecto: "press de banca plano" es el
/// press de banca. No suman al parecido, pero sí sirven para descartar un
/// candidato que diga lo contrario (inclinado, declinado).
const _defaults = {'plano', 'flat'};

/// Sinónimos en español que se igualan antes de comparar, tanto en la
/// búsqueda como en los nombres del catálogo.
const _spanishSynonyms = {
  'jalon al menton': 'remo al menton',
  'barra z': 'barraz',
  'barra t': 'barrat',
  'press militar': 'press hombro',
  'press de hombros': 'press hombro',
  'press de hombro': 'press hombro',
  // "De pie" es una postura; "pies" a secas (pies cerrados) no.
  'de pie': 'depie',
};

final _synonymKeys = _spanishSynonyms.keys.toList()
  ..sort((a, b) => b.length.compareTo(a.length));

String _withSynonyms(String normalized) {
  var text = ' $normalized ';
  for (final key in _synonymKeys) {
    text = text.replaceAll(' $key ', ' ${_spanishSynonyms[key]} ');
  }
  return text.trim();
}

/// El equipo pesa la mitad: casi nunca es lo que distingue un ejercicio
/// ("elevación lateral con mancuernas" es la elevación lateral).
const _equipment = {
  'mancuerna',
  'barra',
  'polea',
  'maquina',
  'smith',
  'banda',
  'kettlebell',
  'barraz',
  'dumbbell',
  'barbell',
  'cable',
  'machine',
  'band',
  'ez',
};

double _weight(String token) => _equipment.contains(token) ? 0.5 : 1;

/// Glosario de gimnasio español → inglés (ADR-0015). Las frases de varias
/// palabras se aplican antes que las sueltas.
const gymGlossary = {
  'press de banca': 'bench press',
  'peso muerto': 'deadlift',
  'buenos dias': 'good morning',
  'empuje de cadera': 'hip thrust',
  'hip thrust': 'hip thrust',
  'face pull': 'face pull',
  'jalon al menton': 'upright row',
  'remo al menton': 'upright row',
  'barra t': 't bar',
  'barra z': 'ez bar',
  'de pie': 'standing',
  'una pierna': 'one leg',
  'un brazo': 'one arm',
  'elevacion de talones': 'calf raise',
  'elevaciones de talones': 'calf raise',
  'elevacion de piernas': 'leg raise',
  'prensa de piernas': 'leg press',
  'curl de pierna': 'leg curl',
  'extension de cuadriceps': 'leg extension',
  'extensiones de cuadriceps': 'leg extension',
  'press militar': 'military press',
  'press frances': 'skull crusher',
  'pajaros': 'reverse fly',
  'pajaro': 'reverse fly',
  'banca': 'bench',
  'banco': 'bench',
  'barra': 'barbell',
  'mancuernas': 'dumbbell',
  'mancuerna': 'dumbbell',
  'polea': 'cable',
  'poleas': 'cable',
  'cuerda': 'rope',
  'maquina': 'machine',
  'inclinado': 'incline',
  'inclinada': 'incline',
  'declinado': 'decline',
  'declinada': 'decline',
  'plano': 'flat',
  'aperturas': 'fly',
  'apertura': 'fly',
  'cruces': 'crossover',
  'cruce': 'crossover',
  'remo': 'row',
  'jalon': 'pulldown',
  'dominadas': 'pull up',
  'dominada': 'pull up',
  'fondos': 'dip',
  'fondo': 'dip',
  'martillo': 'hammer',
  'predicador': 'preacher',
  'extensiones': 'extension',
  'extension': 'extension',
  'patada': 'kickback',
  'sentadilla': 'squat',
  'sentadillas': 'squat',
  'desplantes': 'lunge',
  'desplante': 'lunge',
  'zancada': 'lunge',
  'rumano': 'romanian',
  'prensa': 'press',
  'piernas': 'leg',
  'pierna': 'leg',
  'elevaciones': 'raise',
  'elevacion': 'raise',
  'talones': 'calf',
  'pantorrilla': 'calf',
  'pantorrillas': 'calf',
  'gemelos': 'calf',
  'pantorrillera': 'calf',
  'encogimientos': 'shrug',
  'encogimiento': 'shrug',
  'laterales': 'lateral',
  'frontales': 'front',
  'frontal': 'front',
  'militar': 'military',
  'hombros': 'shoulder',
  'hombro': 'shoulder',
  'pecho': 'chest',
  'cuadriceps': 'quadriceps',
  'femoral': 'hamstring',
  'abdominales': 'crunch',
  'abdominal': 'crunch',
  'plancha': 'plank',
  'aductores': 'adductor',
  'aductor': 'adductor',
  'abducciones': 'abductor',
  'abduccion': 'abductor',
  'abductores': 'abductor',
  'gluteo': 'glute',
  'gluteos': 'glute',
  'puente': 'bridge',
  'sentado': 'seated',
  'sentada': 'seated',
  'acostado': 'lying',
  'acostada': 'lying',
  'unilateral': 'one arm',
  'alta': 'high',
  'alto': 'high',
  'baja': 'low',
  'bajo': 'low',
  'agarre': 'grip',
  'cerrado': 'close',
  'estrecho': 'close',
  'abierto': 'wide',
  'amplio': 'wide',
  'prono': 'pronated',
  'supino': 'supinated',
  'neutro': 'neutral',
  'asistidas': 'assisted',
  'asistida': 'assisted',
  'trasnuca': 'overhead',
  'tras nuca': 'overhead',
  'cadera': 'hip',
  'pesa rusa': 'kettlebell',
  'banda': 'band',
};

final _glossaryKeys = gymGlossary.keys.toList()
  ..sort((a, b) => b.length.compareTo(a.length));

/// Traduce un nombre en español al vocabulario del catálogo en inglés,
/// frase por frase. Lo que no está en el glosario se deja igual (muchos
/// nombres ya se dicen en inglés: "curl", "press", "hack").
String translateToCatalog(String spanish) {
  var text = ' ${normalizeText(spanish)} ';
  for (final key in _glossaryKeys) {
    text = text.replaceAll(' $key ', ' ${gymGlossary[key]} ');
  }
  return text.trim();
}

/// Una palabra sin su plural: "abducciones" → "abduccion", "laterales" →
/// "lateral", "dumbbells" → "dumbbell". Basta con que singular y plural
/// queden iguales; no hace falta que el resultado sea una palabra real.
String _singular(String word) {
  if (word.length <= 3) return word;
  if (word.endsWith('iones')) return '${word.substring(0, word.length - 5)}ion';
  if (word.length > 4 &&
      word.endsWith('es') &&
      'lrndz'.contains(word[word.length - 3])) {
    return word.substring(0, word.length - 2);
  }
  if (word.endsWith('s') && !word.endsWith('ss')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

/// Palabras de un nombre, sin las que no aportan y en singular.
Set<String> _tokens(String normalized) => {
  for (final word in normalized.split(' '))
    if (word.isNotEmpty && !_stopwords.contains(word)) _singular(word),
};

/// Grupos de variantes excluyentes: si la búsqueda dice "plano" y el
/// candidato "declinado", son ejercicios distintos aunque compartan el
/// resto del nombre.
const _variantGroups = [
  {'plano', 'inclinado', 'inclinada', 'declinado', 'declinada'},
  {'flat', 'incline', 'decline'},
  {'sentado', 'sentada', 'depie', 'acostado', 'acostada'},
  {'seated', 'standing', 'lying'},
  {'mancuerna', 'barra', 'barraz', 'polea', 'maquina', 'smith', 'banda'},
  {'dumbbell', 'barbell', 'ez', 'cable', 'machine', 'smith', 'band'},
];

/// Penalización por variantes: fuerte si el candidato contradice lo que se
/// pidió ("declinado" cuando se buscó "inclinado"); leve si agrega una
/// postura o inclinación que no se pidió (sin decir nada, se busca la
/// versión básica). El equipo no cuenta en el segundo caso: casi nunca se
/// escribe.
double _variantPenalty(Set<String> query, Set<String> candidate) {
  var penalty = 0.0;
  for (final (index, group) in _variantGroups.indexed) {
    final asked = query.intersection(group);
    final offered = candidate.intersection(group);
    // Sin decirlo, el ejercicio es plano: pedir "plano" no choca con nada.
    final askedSpecific = asked.difference(_defaults);
    if (offered.isEmpty) {
      // Se pidió "inclinado" y el candidato no lo es.
      if (index < 4 && askedSpecific.isNotEmpty) penalty += 0.1;
    } else if (asked.isEmpty) {
      if (index < 4) penalty += 0.1;
    } else if (asked.intersection(offered).isEmpty) {
      penalty += 0.2;
    }
  }
  return penalty;
}

/// Qué tanto se parecen dos nombres ya reducidos a palabras (0 a 1).
///
/// Pesa más que las palabras de la búsqueda estén en el candidato
/// (cobertura) que el parecido total: los nombres del catálogo traen
/// detalles de más ("- Medium Grip") que no deben hundirlos.
double _similarity(Set<String> query, Set<String> candidate) {
  final asked = query.difference(_defaults);
  final offered = candidate.difference(_defaults);
  if (asked.isEmpty || offered.isEmpty) return 0;
  final shared = asked.intersection(offered);
  double total(Iterable<String> tokens) =>
      tokens.fold(0, (sum, t) => sum + _weight(t));
  final coverage = total(shared) / total(asked);
  final dice = 2 * shared.length / (asked.length + offered.length);
  final score = 0.6 * coverage + 0.4 * dice - _variantPenalty(query, candidate);
  return score < 0 ? 0 : score;
}

/// Un ejercicio del catálogo preparado para compararse rápido.
class MatchCandidate {
  MatchCandidate._(this.exercise, this._spanish, this._english);

  factory MatchCandidate.of(CatalogExercise exercise) => MatchCandidate._(
    exercise,
    _tokens(_withSynonyms(normalizeText(exercise.name))),
    _tokens(normalizeText(exercise.nameEn)),
  );

  final CatalogExercise exercise;
  final Set<String> _spanish;
  final Set<String> _english;
}

/// Un resultado de búsqueda, con qué tan seguro es (0 a 1).
class CatalogMatch {
  const CatalogMatch(this.exercise, this.score);

  final CatalogExercise exercise;
  final double score;
}

/// Puntuación a partir de la cual una sugerencia se considera confiable.
const double confidentMatchScore = 0.75;

/// Los ejercicios más parecidos a [query], ordenados de mayor a menor
/// parecido. Compara el nombre en español contra el del catálogo en español
/// y, traducido con el glosario, contra el nombre original en inglés; se
/// queda con la mejor de las dos.
List<CatalogMatch> rankMatches(
  String query,
  List<MatchCandidate> candidates, {
  int limit = 5,
}) {
  final spanish = _tokens(_withSynonyms(normalizeText(query)));
  final english = _tokens(translateToCatalog(query));
  if (spanish.difference(_defaults).isEmpty) return const [];

  final scored = [
    for (final candidate in candidates)
      CatalogMatch(
        candidate.exercise,
        [
          _similarity(spanish, candidate._spanish),
          _similarity(english, candidate._english),
          // Por si se busca directamente en inglés.
          _similarity(spanish, candidate._english),
        ].reduce((a, b) => a > b ? a : b),
      ),
  ];
  scored.removeWhere((m) => m.score <= 0);
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    // A igual parecido, el nombre más corto: suele ser la variante básica.
    return a.exercise.nameEn.length.compareTo(b.exercise.nameEn.length);
  });
  return scored.take(limit).toList();
}
