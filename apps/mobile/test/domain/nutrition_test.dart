import 'package:anfybio/domain/nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tipo de día', () {
    test('con una sesión registrada hoy es día de entrenamiento', () {
      expect(dayTypeFor(hasSessionToday: true), DayType.training);
    });

    test('sin sesiones hoy es día de descanso', () {
      expect(dayTypeFor(hasSessionToday: false), DayType.rest);
    });

    test('la elección manual manda sobre lo detectado', () {
      expect(
        dayTypeFor(hasSessionToday: true, override: DayType.rest),
        DayType.rest,
      );
      expect(
        dayTypeFor(hasSessionToday: false, override: DayType.training),
        DayType.training,
      );
    });
  });

  group('alternativas de un alimento', () {
    test('un alimento sin alternativas es una sola opción', () {
      expect(foodOptions('Aguacate'), ['Aguacate']);
    });

    test('separa las alternativas unidas con "o"', () {
      expect(foodOptions('Pechuga de pollo o filete de res magro'), [
        'Pechuga de pollo',
        'filete de res magro',
      ]);
      expect(
        foodOptions('Espinaca o champiñones o alguna otra verdura libre'),
        ['Espinaca', 'champiñones', 'alguna otra verdura libre'],
      );
    });

    test('separa con diagonal solo si lleva espacios', () {
      expect(foodOptions('Frutos rojos / Fresas'), ['Frutos rojos', 'Fresas']);
      // Sin espacios es una descripción, no una alternativa.
      expect(foodOptions('Papa horneada/cocida'), ['Papa horneada/cocida']);
    });

    test('no corta palabras que contienen la letra o', () {
      expect(foodOptions('Lomo de cerdo'), ['Lomo de cerdo']);
      expect(foodOptions('Yogurt griego natural'), ['Yogurt griego natural']);
    });
  });
}
