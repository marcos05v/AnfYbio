import 'package:anfybio/domain/routine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('objetivo de un ejercicio', () {
    String target({
      int warmupSets = 0,
      int? workSets,
      int? repsMin,
      int? repsMax,
      String? repsNote,
    }) => formatExerciseTarget(
      warmupSets: warmupSets,
      workSets: workSets,
      repsMin: repsMin,
      repsMax: repsMax,
      repsNote: repsNote,
    );

    test('series por rango de repeticiones', () {
      expect(target(workSets: 4, repsMin: 8, repsMax: 12), '4 × 8–12');
    });

    test('con series de aproximación delante', () {
      expect(
        target(warmupSets: 2, workSets: 4, repsMin: 8, repsMax: 12),
        '2 aprox. + 4 × 8–12',
      );
    });

    test('un número fijo de repeticiones no se muestra como rango', () {
      expect(target(workSets: 3, repsMin: 15, repsMax: 15), '3 × 15');
      expect(target(workSets: 3, repsMin: 15), '3 × 15');
    });

    test('un objetivo que no son repeticiones', () {
      expect(
        target(workSets: 3, repsNote: 'al fallo técnico'),
        '3 × al fallo técnico',
      );
    });

    test('solo series, o nada', () {
      expect(target(workSets: 3), '3 series');
      expect(target(workSets: 1), '1 serie');
      expect(target(), '');
    });
  });

  group('día que toca según el día de la semana', () {
    // 16 de noviembre de 2026 es lunes.
    final monday = DateTime(2026, 11, 16);
    DateTime weekday(int offset) => monday.add(Duration(days: offset));

    test('por defecto el lunes es el Día 1 y cada día avanza uno', () {
      expect(routineDayIndexFor(date: monday, dayCount: 6), 0);
      expect(routineDayIndexFor(date: weekday(1), dayCount: 6), 1);
      expect(routineDayIndexFor(date: weekday(5), dayCount: 6), 5); // sábado
    });

    test('los días de la semana que sobran son de descanso', () {
      expect(routineDayIndexFor(date: weekday(6), dayCount: 6), isNull); // dom
      expect(routineDayIndexFor(date: weekday(3), dayCount: 3), isNull);
    });

    test('la semana siguiente vuelve a empezar', () {
      expect(routineDayIndexFor(date: weekday(7), dayCount: 6), 0);
      expect(routineDayIndexFor(date: weekday(8), dayCount: 6), 1);
    });

    test('se puede recorrer en qué día de la semana cae el Día 1', () {
      // Día 1 en miércoles: el lunes queda como descanso.
      const wednesday = DateTime.wednesday;
      expect(
        routineDayIndexFor(
          date: weekday(2),
          dayCount: 5,
          dayOneWeekday: wednesday,
        ),
        0,
      );
      expect(
        routineDayIndexFor(
          date: weekday(6), // domingo
          dayCount: 5,
          dayOneWeekday: wednesday,
        ),
        4,
      );
      expect(
        routineDayIndexFor(date: monday, dayCount: 5, dayOneWeekday: wednesday),
        isNull,
      );
    });

    test('una rutina sin días nunca tiene día', () {
      expect(routineDayIndexFor(date: monday, dayCount: 0), isNull);
    });
  });

  group('corregir a mano el día que toca', () {
    final wednesday = DateTime(2026, 11, 18);

    test(
      'elegir el Día 1 un miércoles hace que el Día 1 caiga en miércoles',
      () {
        expect(
          dayOneWeekdayFor(today: wednesday, todayIndex: 0),
          DateTime.wednesday,
        );
      },
    );

    test('elegir el Día 3 un miércoles deja el Día 1 en lunes', () {
      expect(
        dayOneWeekdayFor(today: wednesday, todayIndex: 2),
        DateTime.monday,
      );
    });

    test('da la vuelta a la semana cuando hace falta', () {
      // Hoy miércoles toca el Día 5 → el Día 1 fue el sábado anterior.
      expect(
        dayOneWeekdayFor(today: wednesday, todayIndex: 4),
        DateTime.saturday,
      );
    });

    test('el resultado hace que hoy toque justo el día elegido', () {
      for (var index = 0; index < 6; index++) {
        final dayOne = dayOneWeekdayFor(today: wednesday, todayIndex: index);
        expect(
          routineDayIndexFor(
            date: wednesday,
            dayCount: 6,
            dayOneWeekday: dayOne,
          ),
          index,
        );
      }
    });
  });

  group('aproximación', () {
    test('se propone hasta completar las que pide la rutina', () {
      expect(nextSetIsWarmup(warmupSets: 2, loggedWarmups: 0), isTrue);
      expect(nextSetIsWarmup(warmupSets: 2, loggedWarmups: 1), isTrue);
      expect(nextSetIsWarmup(warmupSets: 2, loggedWarmups: 2), isFalse);
    });

    test('si la rutina no pide ninguna, no se propone', () {
      expect(nextSetIsWarmup(warmupSets: 0, loggedWarmups: 0), isFalse);
    });
  });

  group('bloques de biserie', () {
    // Cada ejercicio es (nombre, va con el anterior).
    List<List<String>> blocks(List<(String, bool)> exercises) => [
      for (final block in groupSupersets(exercises, (e) => e.$2))
        [for (final e in block) e.$1],
    ];

    test('sin biseries, cada ejercicio es su propio bloque', () {
      expect(blocks([('A', false), ('B', false)]), [
        ['A'],
        ['B'],
      ]);
    });

    test('une cada ejercicio marcado con el que le precede', () {
      expect(blocks([('A', false), ('B', false), ('C', true), ('D', false)]), [
        ['A'],
        ['B', 'C'],
        ['D'],
      ]);
    });

    test('dos biseries seguidas no se mezclan', () {
      expect(blocks([('A', false), ('B', true), ('C', false), ('D', true)]), [
        ['A', 'B'],
        ['C', 'D'],
      ]);
    });

    test('tres ejercicios encadenados forman un solo bloque', () {
      expect(blocks([('A', false), ('B', true), ('C', true)]), [
        ['A', 'B', 'C'],
      ]);
    });

    test('si el primero viene marcado, abre su propio bloque', () {
      expect(blocks([('A', true), ('B', false)]), [
        ['A'],
        ['B'],
      ]);
    });

    test('una lista vacía no tiene bloques', () {
      expect(blocks([]), isEmpty);
    });
  });
}
