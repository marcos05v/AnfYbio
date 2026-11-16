import 'package:anfybio/domain/pace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('natación', () {
    test('400 m en 6:20 son 1:35 por cada 100 m', () {
      final pace = swimPaceSecondsPer100m(distanceM: 400, durationMs: 380000);
      expect(pace, 95);
    });

    test('funciona con distancias menores a 100 m', () {
      expect(swimPaceSecondsPer100m(distanceM: 50, durationMs: 40000), 80);
    });

    test('sin distancia o sin tiempo no hay ritmo', () {
      expect(swimPaceSecondsPer100m(distanceM: 0, durationMs: 1000), isNull);
      expect(swimPaceSecondsPer100m(distanceM: 100, durationMs: 0), isNull);
    });
  });

  group('carrera', () {
    test('5 km en 25 minutos son 5:00 por km', () {
      expect(runPaceSecondsPerKm(distanceM: 5000, durationS: 1500), 300);
    });

    test('sin distancia o sin tiempo no hay ritmo', () {
      expect(runPaceSecondsPerKm(distanceM: 0, durationS: 1500), isNull);
      expect(runPaceSecondsPerKm(distanceM: 5000, durationS: 0), isNull);
    });
  });

  group('formato', () {
    test('minutos y segundos con dos dígitos', () {
      expect(formatPace(95), '1:35');
      expect(formatPace(300), '5:00');
      expect(formatPace(65), '1:05');
      expect(formatPace(45), '0:45');
    });

    test('redondea antes de separar: nunca muestra 60 segundos', () {
      expect(formatPace(119.6), '2:00');
      expect(formatPace(119.4), '1:59');
    });
  });
}
