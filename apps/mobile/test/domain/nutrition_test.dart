import 'package:anfybio/domain/nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('menú según el nombre del día de la rutina', () {
    const lowerUpper = {
      DayType.high: 'Días de Tren Inferior (Más carbohidratos)',
      DayType.low: 'Días de Tren Superior / Descanso (Menos carbohidratos)',
    };

    test('el mismo "tren" en los dos nombres', () {
      expect(
        dayTypeByName('Tren Inferior (Glúteo y Femoral)', lowerUpper),
        DayType.high,
      );
      expect(
        dayTypeByName('Tren Superior (Espalda) + HIIT', lowerUpper),
        DayType.low,
      );
    });

    test('los músculos cuentan como su tren', () {
      expect(dayTypeByName('Cuádriceps y Gemelos', lowerUpper), DayType.high);
      expect(dayTypeByName('Pecho y Tríceps', lowerUpper), DayType.low);
    });

    test('un plan que nombra músculos en vez de trenes', () {
      const byMuscle = {
        DayType.low: 'Días bajos (Tríceps, Hombro, Pecho y Descanso)',
        DayType.high: 'Días altos (Espalda y Pierna)',
      };
      expect(dayTypeByName('Espalda y Bíceps', byMuscle), DayType.high);
      expect(dayTypeByName('Hombro completo', byMuscle), DayType.low);
      expect(dayTypeByName('Isquiotibiales y Glúteos', byMuscle), DayType.high);
    });

    test('sin rutina hoy va al menú de descanso', () {
      expect(dayTypeByName(null, lowerUpper), DayType.low);
    });

    test('si no hay pistas o empatan, no adivina', () {
      const neutral = {
        DayType.training: 'Días de entrenamiento (Superávit)',
        DayType.rest: 'Días de descanso',
      };
      expect(dayTypeByName('Pecho y Tríceps', neutral), isNull);
      expect(dayTypeByName('Full body', lowerUpper), isNull);
      expect(
        dayTypeByName('Pierna y Pecho', const {
          DayType.high: 'Tren inferior',
          DayType.low: 'Tren superior',
        }),
        isNull,
      );
    });
  });

  group('menú según el día de la rutina', () {
    const menuDays = {
      DayType.high: [2, 3, 5],
      DayType.low: [1, 4, 6, 7],
    };

    test('el día de la rutina dice qué menú toca', () {
      expect(dayTypeForRoutineDay(3, menuDays), DayType.high);
      expect(dayTypeForRoutineDay(7, menuDays), DayType.low);
    });

    test('sin rutina, o un día que el plan no menciona, no decide', () {
      expect(dayTypeForRoutineDay(null, menuDays), isNull);
      expect(dayTypeForRoutineDay(8, menuDays), isNull);
      expect(dayTypeForRoutineDay(1, const {}), isNull);
    });

    test('se guardan como texto y se leen de vuelta', () {
      expect(encodeRoutineDays([5, 2, 3]), '2,3,5');
      expect(encodeRoutineDays([]), isNull);
      expect(decodeRoutineDays('2,3,5'), [2, 3, 5]);
      expect(decodeRoutineDays(null), isEmpty);
    });
  });

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
      expect(foodOptions('1 pera ó 1 taza de moras'), [
        '1 pera',
        '1 taza de moras',
      ]);
      expect(foodOptions('pechuga de pavo u 80 g de queso panela'), [
        'pechuga de pavo',
        '80 g de queso panela',
      ]);
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
