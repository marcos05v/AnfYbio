import 'package:anfybio/domain/training_load.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('carga de sesión (sRPE)', () {
    test('RPE × minutos', () {
      expect(sessionLoad(durationS: 3600, sessionRpe: 7), 420);
      expect(sessionLoad(durationS: 1500, sessionRpe: 6), 150);
    });

    test('cuenta las fracciones de minuto', () {
      expect(sessionLoad(durationS: 90, sessionRpe: 4), 6);
    });

    test('una sesión en curso no tiene carga', () {
      expect(sessionLoad(durationS: null, sessionRpe: 7), isNull);
      expect(sessionLoad(durationS: 3600, sessionRpe: null), isNull);
    });
  });

  group('carga aguda vs crónica', () {
    final today = DateTime(2026, 11, 16);
    LoadEntry daysAgo(int days, double load) => LoadEntry(
      day: today.subtract(Duration(days: days)),
      load: load,
    );

    test('cuatro semanas iguales dan una proporción de 1.0', () {
      final summary = summarizeLoad([
        daysAgo(27, 1000),
        daysAgo(20, 1000),
        daysAgo(13, 1000),
        daysAgo(3, 1000),
      ], asOf: today);

      expect(summary.acute, 1000);
      expect(summary.chronic, 1000);
      expect(summary.ratio, 1.0);
    });

    test('una semana con el triple de carga sube la proporción a 2.0', () {
      final summary = summarizeLoad([
        daysAgo(27, 500),
        daysAgo(20, 500),
        daysAgo(13, 500),
        daysAgo(3, 1500),
      ], asOf: today);

      expect(summary.acute, 1500);
      expect(summary.chronic, 750); // (500 + 500 + 500 + 1500) / 4
      expect(summary.ratio, 2.0);
    });

    test('suma todas las sesiones del mismo día', () {
      final summary = summarizeLoad([
        daysAgo(0, 300), // fuerza por la mañana
        daysAgo(0, 200), // natación por la tarde
      ], asOf: today);

      expect(summary.acute, 500);
    });

    test('la ventana aguda abarca 7 días contando hoy', () {
      expect(summarizeLoad([daysAgo(6, 100)], asOf: today).acute, 100);
      expect(summarizeLoad([daysAgo(7, 100)], asOf: today).acute, 0);
    });

    test('la ventana crónica abarca 28 días contando hoy', () {
      expect(summarizeLoad([daysAgo(27, 400)], asOf: today).chronic, 100);
      expect(summarizeLoad([daysAgo(28, 400)], asOf: today).chronic, 0);
    });

    test('con menos de 28 días de historial no hay proporción', () {
      final summary = summarizeLoad([
        daysAgo(10, 500),
        daysAgo(2, 500),
      ], asOf: today);

      expect(summary.hasEnoughHistory, isFalse);
      expect(summary.ratio, isNull);
      expect(summary.acute, 500); // la carga aguda sí se informa
    });

    test('sin carga crónica no hay proporción (evita dividir entre cero)', () {
      final summary = summarizeLoad([daysAgo(40, 800)], asOf: today);

      expect(summary.hasEnoughHistory, isTrue);
      expect(summary.chronic, 0);
      expect(summary.ratio, isNull);
    });

    test('sin registros todo es cero y no hay proporción', () {
      final summary = summarizeLoad([], asOf: today);

      expect(summary.acute, 0);
      expect(summary.chronic, 0);
      expect(summary.ratio, isNull);
    });

    test('ignora las sesiones posteriores al día consultado', () {
      final summary = summarizeLoad([
        LoadEntry(day: today.add(const Duration(days: 1)), load: 999),
      ], asOf: today);

      expect(summary.acute, 0);
    });

    test('la hora del día no cambia a qué día pertenece una sesión', () {
      final summary = summarizeLoad([
        LoadEntry(
          day: DateTime(2026, 11, 10, 23, 59),
          load: 100,
        ), // hace 6 días
        LoadEntry(day: DateTime(2026, 11, 9, 23, 59), load: 100), // hace 7 días
      ], asOf: DateTime(2026, 11, 16, 0, 1));

      expect(summary.acute, 100);
    });
  });

  group('carga por semana', () {
    final today = DateTime(2026, 11, 16);
    LoadEntry daysAgo(int days, double load) => LoadEntry(
      day: today.subtract(Duration(days: days)),
      load: load,
    );

    test('devuelve las semanas de la más antigua a la actual', () {
      final loads = weeklyLoads([
        daysAgo(0, 100), // semana actual
        daysAgo(6, 50), // semana actual
        daysAgo(7, 300), // semana anterior
        daysAgo(27, 800), // hace 3 semanas
      ], asOf: today);

      expect(loads, [800, 0, 300, 150]);
    });

    test('la semana actual coincide con la carga aguda', () {
      final entries = [daysAgo(2, 420), daysAgo(5, 156), daysAgo(9, 999)];

      expect(
        weeklyLoads(entries, asOf: today).last,
        summarizeLoad(entries, asOf: today).acute,
      );
    });

    test('ignora lo que queda fuera del periodo y lo futuro', () {
      final loads = weeklyLoads([
        daysAgo(28, 500),
        LoadEntry(day: today.add(const Duration(days: 1)), load: 500),
      ], asOf: today);

      expect(loads, [0, 0, 0, 0]);
    });

    test('sin registros, todas las semanas valen cero', () {
      expect(weeklyLoads([], asOf: today, weeks: 3), [0, 0, 0]);
    });
  });

  group('semanas de historial', () {
    final today = DateTime(2026, 11, 16);
    LoadEntry daysAgo(int days) =>
        LoadEntry(day: today.subtract(Duration(days: days)), load: 100);

    test('sin registros no hay semanas', () {
      expect(weeksOfHistory([], asOf: today), 0);
    });

    test('un registro de esta semana cuenta una semana', () {
      expect(weeksOfHistory([daysAgo(0)], asOf: today), 1);
      expect(weeksOfHistory([daysAgo(6)], asOf: today), 1);
    });

    test('crece con el registro más antiguo', () {
      expect(weeksOfHistory([daysAgo(7)], asOf: today), 2);
      expect(weeksOfHistory([daysAgo(2), daysAgo(30)], asOf: today), 5);
    });

    test('ignora los registros futuros', () {
      expect(weeksOfHistory([daysAgo(-3)], asOf: today), 0);
    });
  });
}
