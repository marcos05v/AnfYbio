import '../data/tables/apnea_attempts.dart';
import '../data/tables/sessions.dart';
import '../data/tables/swim.dart';
import '../domain/nutrition.dart';

const _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// Fecha y hora locales: "lunes 16 nov · 18:05".
String formatDateTime(DateTime utc) {
  final d = utc.toLocal();
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}'
      ' · ${_two(d.hour)}:${_two(d.minute)}';
}

const _fullMonths = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Fecha local larga para encabezados: "Lunes 16 de noviembre".
String formatLongDate(DateTime utc) {
  final d = utc.toLocal();
  final weekday = _weekdays[d.weekday - 1];
  return '${weekday[0].toUpperCase()}${weekday.substring(1)} ${d.day}'
      ' de ${_fullMonths[d.month - 1]}';
}

/// Rango de días de calendario: "10–16 nov" o "28 oct – 3 nov".
String formatDayRange(DateTime start, DateTime end) {
  final endText = '${end.day} ${_months[end.month - 1]}';
  return start.month == end.month
      ? '${start.day}–$endText'
      : '${start.day} ${_months[start.month - 1]} – $endText';
}

/// Fecha corta de un día local: "16 nov", o "16 nov 2025" si no es de este año.
String formatShortDate(DateTime local, {DateTime? now}) {
  final text = '${local.day} ${_months[local.month - 1]}';
  return local.year == (now ?? DateTime.now()).year
      ? text
      : '$text ${local.year}';
}

/// Hora local: "18:05".
String formatTime(DateTime utc) {
  final d = utc.toLocal();
  return '${_two(d.hour)}:${_two(d.minute)}';
}

/// Número sin ceros de sobra: 100.0 → "100", 102.5 → "102.5".
String formatNumber(double value, {int decimals = 1}) {
  final text = value.toStringAsFixed(decimals);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}

/// Acepta coma o punto decimal, como los escribe el teclado en español.
double? parseNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

String sessionTypeLabel(SessionType type) => switch (type) {
  SessionType.strength => 'Fuerza',
  SessionType.swim => 'Natación',
  SessionType.run => 'Carrera',
  SessionType.apnea => 'Apnea',
};

/// Qué se registra en cada tipo de sesión, en pocas palabras.
String sessionTypeDescription(SessionType type) => switch (type) {
  SessionType.strength => 'Series, peso y repeticiones',
  SessionType.swim => 'Bloques por estilo y parciales',
  SessionType.run => 'Distancia y ritmo',
  SessionType.apnea => 'Estática y dinámica',
};

/// Descripción del esfuerzo percibido, para orientar al elegir el RPE.
String rpeLabel(int rpe) => switch (rpe) {
  <= 2 => 'Muy suave',
  <= 4 => 'Suave',
  <= 6 => 'Moderado',
  <= 8 => 'Duro',
  9 => 'Muy duro',
  _ => 'Máximo',
};

String swimStrokeLabel(SwimStroke stroke) => switch (stroke) {
  SwimStroke.freestyle => 'Libre',
  SwimStroke.backstroke => 'Dorso',
  SwimStroke.breaststroke => 'Pecho',
  SwimStroke.butterfly => 'Mariposa',
  SwimStroke.medley => 'Combinado',
};

String apneaKindLabel(ApneaKind kind) => switch (kind) {
  ApneaKind.static => 'Estática',
  ApneaKind.dynamic => 'Dinámica',
};

/// Interpreta un tiempo escrito a mano y lo devuelve en milisegundos.
///
/// Acepta "95", "95,5", "1:35", "1:35.2" y "1:02:03". Un número solo son
/// segundos. Devuelve `null` si el texto no es un tiempo válido y positivo.
int? parseDurationMs(String text) {
  final parts = text.trim().replaceAll(',', '.').split(':');
  if (parts.length > 3 || parts.any((p) => p.isEmpty)) return null;

  final seconds = double.tryParse(parts.last);
  if (seconds == null || seconds < 0) return null;
  // Con minutos delante, los segundos no pueden pasar de 59.
  if (parts.length > 1 && seconds >= 60) return null;

  var total = seconds;
  var unit = 60;
  for (final part in parts.reversed.skip(1)) {
    final value = int.tryParse(part);
    if (value == null || value < 0) return null;
    total += value * unit;
    unit *= 60;
  }
  final ms = (total * 1000).round();
  return ms > 0 ? ms : null;
}

/// Duración de una sesión, en segundos. Un número solo son **minutos**
/// ("45"); con dos puntos es minutos:segundos ("45:30") u
/// horas:minutos:segundos ("1:05:00").
int? parseSessionDurationS(String text) {
  final trimmed = text.trim();
  if (!trimmed.contains(':')) {
    final minutes = parseNumber(trimmed);
    if (minutes == null || minutes <= 0) return null;
    return (minutes * 60).round();
  }
  final ms = parseDurationMs(trimmed);
  return ms == null ? null : (ms / 1000).round();
}

/// Tiempo de reloj: 95000 → "1:35", 95200 → "1:35.2", 3723000 → "1:02:03".
/// Las décimas solo se muestran si no son cero.
String formatDurationMs(int ms) {
  final tenths = (ms / 100).round();
  final totalSeconds = tenths ~/ 10;
  final hours = totalSeconds ~/ 3600;
  final minutes = totalSeconds % 3600 ~/ 60;
  final seconds = totalSeconds % 60;
  final fraction = tenths % 10 == 0 ? '' : '.${tenths % 10}';
  final clock = hours > 0
      ? '$hours:${_two(minutes)}:${_two(seconds)}'
      : '$minutes:${_two(seconds)}';
  return '$clock$fraction';
}

/// Distancia en metros o kilómetros según su tamaño: "400 m", "5 km".
String formatDistance(int meters) => meters < 1000
    ? '$meters m'
    : '${formatNumber(meters / 1000, decimals: 2)} km';

String dayTypeLabel(DayType dayType) => switch (dayType) {
  DayType.training => 'Entrenamiento',
  DayType.rest => 'Descanso',
  DayType.high => 'Día alto',
  DayType.low => 'Día bajo',
};

String foodStateLabel(FoodState state) => switch (state) {
  FoodState.raw => 'En crudo',
  FoodState.cooked => 'Cocido',
  FoodState.dry => 'En seco',
  FoodState.unspecified => 'Sin especificar',
};

String foodUnitLabel(FoodUnit unit) => switch (unit) {
  FoodUnit.gram => 'Gramos',
  FoodUnit.piece => 'Piezas',
  FoodUnit.scoop => 'Scoops',
  FoodUnit.ml => 'Mililitros',
  FoodUnit.cup => 'Tazas',
  FoodUnit.tablespoon => 'Cucharadas',
  FoodUnit.teaspoon => 'Cucharaditas',
};

/// Cantidad de un alimento del plan: "100 g", "2 piezas", "1 scoop", "Libre".
/// Vacío si el plan no indica cantidad.
String formatFoodAmount({
  required double? amount,
  required FoodUnit? unit,
  required bool isFree,
}) {
  if (isFree) return 'Libre';
  if (amount == null) return '';
  final number = formatNumber(amount, decimals: 2);
  // Las piezas, tazas y cucharadas se cuentan en fracciones: "1/4 pieza",
  // "1 1/2 tazas".
  final counted = _fraction(amount) ?? number;
  return switch (unit) {
    null => number,
    FoodUnit.gram => '$number g',
    FoodUnit.piece => amount <= 1 ? '$counted pieza' : '$counted piezas',
    FoodUnit.scoop => amount <= 1 ? '$number scoop' : '$number scoops',
    FoodUnit.ml => '$number ml',
    FoodUnit.cup => amount <= 1 ? '$counted taza' : '$counted tazas',
    FoodUnit.tablespoon => '$counted cda.',
    FoodUnit.teaspoon => '$counted cdta.',
  };
}

/// 0.25 → "1/4", 1.5 → "1 1/2"; nulo si no es una fracción común.
String? _fraction(double amount) {
  final whole = amount.floor();
  final part = amount - whole;
  const names = [
    (1 / 4, '1/4'),
    (1 / 3, '1/3'),
    (1 / 2, '1/2'),
    (2 / 3, '2/3'),
    (3 / 4, '3/4'),
  ];
  for (final (value, name) in names) {
    if ((part - value).abs() < 0.01) return whole == 0 ? name : '$whole $name';
  }
  return null;
}

/// Cantidad de un suplemento con su unidad: "285 g", "12 cápsulas".
String formatQuantity(double amount, String unit) =>
    '${formatNumber(amount, decimals: 1)} $unit';

/// Días restantes en palabras: "hoy", "1 día", "57 días".
String formatDaysLeft(int days) => switch (days) {
  0 => 'hoy',
  1 => '1 día',
  _ => '$days días',
};

/// Separa un nombre en título y aclaración entre paréntesis:
/// "Omega 3 (EPAs / DHAs)" → ("Omega 3", "EPAs / DHAs"). Sin paréntesis
/// final, la aclaración es nula.
(String title, String? detail) splitName(String name) {
  final match = RegExp(r'^(.+?)\s*\((.+)\)\s*$').firstMatch(name.trim());
  return match == null
      ? (name.trim(), null)
      : (match.group(1)!, match.group(2)!);
}

/// Hora del día en formato de 12 horas a partir de minutos desde la
/// medianoche: 570 → "9:30 a. m.", 1290 → "9:30 p. m.", 0 → "12:00 a. m.".
String formatMinuteOfDay(int minutes) {
  final (clock, period) = splitClock12(minutes);
  return '$clock $period';
}

/// La hora en dos partes, para mostrarlas con distinto tamaño:
/// 570 → ("9:30", "a. m.").
(String clock, String period) splitClock12(int minutes) {
  final hour24 = minutes ~/ 60 % 24;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return ('$hour12:${_two(minutes % 60)}', hour24 < 12 ? 'a. m.' : 'p. m.');
}
