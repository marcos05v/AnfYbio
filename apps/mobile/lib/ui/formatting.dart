import '../data/tables/sessions.dart';

const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
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

/// Fecha y hora locales: "lun 16 nov · 18:05".
String formatDateTime(DateTime utc) {
  final d = utc.toLocal();
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}'
      ' · ${_two(d.hour)}:${_two(d.minute)}';
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
