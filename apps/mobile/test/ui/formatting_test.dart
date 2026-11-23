import 'package:anfybio/domain/nutrition.dart';
import 'package:anfybio/ui/formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDurationMs', () {
    test('un número solo son segundos', () {
      expect(parseDurationMs('95'), 95000);
      expect(parseDurationMs('23.5'), 23500);
      expect(parseDurationMs('23,5'), 23500); // coma decimal
    });

    test('minutos:segundos y horas:minutos:segundos', () {
      expect(parseDurationMs('1:35'), 95000);
      expect(parseDurationMs('1:35.2'), 95200);
      expect(parseDurationMs('2:05'), 125000);
      expect(parseDurationMs('1:02:03'), 3723000);
    });

    test('rechaza lo que no es un tiempo', () {
      expect(parseDurationMs(''), isNull);
      expect(parseDurationMs('abc'), isNull);
      expect(parseDurationMs('1:'), isNull);
      expect(parseDurationMs('1:75'), isNull); // 75 segundos tras minutos
      expect(parseDurationMs('-5'), isNull);
      expect(parseDurationMs('0'), isNull);
      expect(parseDurationMs('1:2:3:4'), isNull);
    });
  });

  group('parseSessionDurationS', () {
    test('un número solo son minutos', () {
      expect(parseSessionDurationS('45'), 2700);
      expect(parseSessionDurationS('22,5'), 1350);
    });

    test('con dos puntos son minutos:segundos u horas', () {
      expect(parseSessionDurationS('25:30'), 1530);
      expect(parseSessionDurationS('1:05:00'), 3900);
    });

    test('rechaza valores vacíos o no positivos', () {
      expect(parseSessionDurationS(''), isNull);
      expect(parseSessionDurationS('0'), isNull);
      expect(parseSessionDurationS('x'), isNull);
    });
  });

  group('formatDurationMs', () {
    test('minutos y segundos, con décimas solo si existen', () {
      expect(formatDurationMs(95000), '1:35');
      expect(formatDurationMs(95200), '1:35.2');
      expect(formatDurationMs(23500), '0:23.5');
      expect(formatDurationMs(150000), '2:30');
    });

    test('incluye horas a partir de 60 minutos', () {
      expect(formatDurationMs(3723000), '1:02:03');
    });

    test('redondea a décimas sin mostrar 60 segundos', () {
      expect(formatDurationMs(59960), '1:00');
    });

    test('es la inversa de parseDurationMs', () {
      for (final text in ['0:23.5', '1:35', '12:00.1', '1:02:03']) {
        expect(formatDurationMs(parseDurationMs(text)!), text);
      }
    });
  });

  test('formatDistance usa metros hasta 999 y kilómetros después', () {
    expect(formatDistance(400), '400 m');
    expect(formatDistance(5000), '5 km');
    expect(formatDistance(5250), '5.25 km');
  });

  test('formatNumber quita los ceros de sobra', () {
    expect(formatNumber(100), '100');
    expect(formatNumber(102.5), '102.5');
    expect(formatNumber(119.068), '119.1');
  });

  test('formatDayRange abrevia cuando los dos días son del mismo mes', () {
    expect(
      formatDayRange(DateTime(2026, 11, 10), DateTime(2026, 11, 16)),
      '10–16 nov',
    );
    expect(
      formatDayRange(DateTime(2026, 10, 28), DateTime(2026, 11, 3)),
      '28 oct – 3 nov',
    );
  });

  test('formatShortDate solo muestra el año si no es el actual', () {
    final now = DateTime(2026, 11, 16);
    expect(formatShortDate(DateTime(2026, 3, 5), now: now), '5 mar');
    expect(formatShortDate(DateTime(2025, 12, 31), now: now), '31 dic 2025');
  });

  test('formatFoodAmount escribe la cantidad con su unidad', () {
    String amount(double? amount, FoodUnit? unit, {bool isFree = false}) =>
        formatFoodAmount(amount: amount, unit: unit, isFree: isFree);

    expect(amount(100, FoodUnit.gram), '100 g');
    expect(amount(2, FoodUnit.piece), '2 piezas');
    expect(amount(1, FoodUnit.piece), '1 pieza');
    expect(amount(1, FoodUnit.scoop), '1 scoop');
    expect(amount(0.5, FoodUnit.scoop), '0.5 scoop');
    expect(amount(2, FoodUnit.scoop), '2 scoops');
    expect(amount(0.25, FoodUnit.piece), '1/4 pieza');
    expect(amount(1.5, FoodUnit.cup), '1 1/2 tazas');
    expect(amount(0.4, FoodUnit.piece), '0.4 pieza');
    expect(amount(150, null), '150'); // el plan no trae unidad
    expect(amount(null, null), '');
    expect(amount(null, null, isFree: true), 'Libre');
  });

  test('splitName separa título y aclaración entre paréntesis', () {
    expect(splitName('Omega 3 (EPAs / DHAs)'), ('Omega 3', 'EPAs / DHAs'));
    expect(
      splitName('Creatina Monohidratada (Sello Creapure de preferencia)'),
      ('Creatina Monohidratada', 'Sello Creapure de preferencia'),
    );
    expect(splitName('  Zinc  '), ('Zinc', null));
    // Un paréntesis que no está al final no es una aclaración.
    expect(splitName('Vitamina (D3) líquida'), ('Vitamina (D3) líquida', null));
  });

  test('formatMinuteOfDay escribe la hora en formato de 12 horas', () {
    expect(formatMinuteOfDay(570), '9:30 a. m.');
    expect(formatMinuteOfDay(21 * 60 + 5), '9:05 p. m.');
    // Medianoche y mediodía son las 12.
    expect(formatMinuteOfDay(0), '12:00 a. m.');
    expect(formatMinuteOfDay(12 * 60), '12:00 p. m.');
    expect(formatMinuteOfDay(12 * 60 + 59), '12:59 p. m.');
    expect(formatMinuteOfDay(23 * 60 + 59), '11:59 p. m.');
  });

  test('splitClock12 separa la hora del periodo', () {
    expect(splitClock12(570), ('9:30', 'a. m.'));
    expect(splitClock12(13 * 60), ('1:00', 'p. m.'));
  });
}
