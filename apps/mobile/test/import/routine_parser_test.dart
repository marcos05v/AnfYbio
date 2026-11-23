import 'dart:io';

import 'package:anfybio/domain/routine.dart';
import 'package:anfybio/import/routine_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// El archivo de ejemplo imita el formato de una rutina real (viñetas de
/// tres niveles, biseries y renglones partidos) con ejercicios inventados.
void main() {
  late ParsedRoutine parsed;
  late RoutineDraft draft;

  setUp(() {
    final text = File('test/fixtures/rutina_ejemplo.txt').readAsStringSync();
    parsed = parseRoutine(text, fileName: 'rutina.pdf');
    draft = parsed.draft;
  });

  RoutineExerciseDraft exercise(String name) =>
      draft.exercises.singleWhere((e) => e.name == name);

  group('estructura', () {
    test('toma el título y el nombre del archivo', () {
      expect(draft.name, 'Rutina de ejemplo');
      expect(draft.sourceFileName, 'rutina.pdf');
    });

    test('lee los días sin su número', () {
      expect(draft.days.map((d) => d.name), ['Empuje', 'Tirón y Core']);
    });

    test('cada ejercicio queda en su día y en orden', () {
      expect(draft.days.first.exercises.map((e) => e.name), [
        'Press con Barra',
        'Press Inclinado',
        'Aperturas en Banco',
        'Press en Máquina',
        'Cruces en Polea (de Alta a Baja)',
        'Elevaciones Laterales',
        'Pájaros con dos agarres',
      ]);
      expect(draft.days.last.exercises, hasLength(5));
    });

    test('asigna a cada ejercicio su grupo muscular', () {
      expect(exercise('Press con Barra').groupLabel, 'Pecho');
      expect(exercise('Elevaciones Laterales').groupLabel, 'Hombro (Bombeo)');
      // El grupo no se arrastra de un día al siguiente.
      expect(exercise('Dominadas').groupLabel, isNull);
      expect(exercise('Plancha').groupLabel, 'Core (Estabilidad)');
    });

    test('"Combinado con:" no forma parte del nombre', () {
      expect(
        draft.exercises.map((e) => e.name),
        contains('Cruces en Polea (de Alta a Baja)'),
      );
    });
  });

  group('series y repeticiones', () {
    test('aproximación más efectivas, con el renglón partido', () {
      final press = exercise('Press con Barra');
      expect((press.warmupSets, press.workSets), (2, 4));
      expect((press.repsMin, press.repsMax), (6, 10));
      expect(
        press.note,
        'Como ejercicio principal, cuidando el recorrido completo',
      );
    });

    test('tolera espacios y palabras repetidas ("de  de 8 a 12")', () {
      final row = exercise('Remo con Barra');
      expect((row.warmupSets, row.workSets), (3, 4));
      expect((row.repsMin, row.repsMax), (8, 12));
    });

    test('rango con "a" o con guion', () {
      expect(exercise('Press Inclinado').repsMax, 12);
      final flyes = exercise('Aperturas en Banco');
      expect((flyes.repsMin, flyes.repsMax), (12, 15));
    });

    test('un número fijo de repeticiones', () {
      final cable = exercise('Cruces en Polea (de Alta a Baja)');
      expect((cable.repsMin, cable.repsMax), (15, 15));
      expect(cable.note, 'Sin descanso previo');
    });

    test('"al fallo" queda como objetivo en texto', () {
      final pullups = exercise('Dominadas');
      expect((pullups.workSets, pullups.repsMin), (3, null));
      expect(pullups.repsNote, 'al fallo técnico');
      expect(pullups.note, 'Para ganar fuerza');

      final plank = exercise('Plancha');
      expect(plank.repsNote, 'al fallo (30 a 60 segundos)');
      expect(plank.note, 'Con el abdomen firme');
    });

    test('un ejercicio sin indicaciones no lleva nota', () {
      expect(exercise('Elevaciones Laterales').note, isNull);
    });
  });

  group('biseries', () {
    test('une los dos ejercicios que siguen a "Biserie:"', () {
      expect(exercise('Press Inclinado').supersetWithPrevious, isFalse);
      expect(exercise('Aperturas en Banco').supersetWithPrevious, isTrue);
    });

    test('funciona en el tercer nivel de viñetas y con "Combinado con"', () {
      expect(exercise('Press en Máquina').supersetWithPrevious, isFalse);
      expect(
        exercise('Cruces en Polea (de Alta a Baja)').supersetWithPrevious,
        isTrue,
      );
    });

    test('acepta "Biserie;" con punto y coma', () {
      expect(exercise('Plancha').supersetWithPrevious, isFalse);
      expect(exercise('Rueda Abdominal').supersetWithPrevious, isTrue);
    });

    test('una biserie solo abarca dos ejercicios', () {
      expect(exercise('Caminata de Granjero').supersetWithPrevious, isFalse);
    });

    test('un grupo muscular nuevo cierra la biserie', () {
      expect(exercise('Elevaciones Laterales').supersetWithPrevious, isFalse);
    });

    test(
      'un título que empieza con "Biserie de…" es un grupo, no una marca',
      () {
        final result = parseRoutine(
          'R\nDía 1: Brazos\n• Biserie de Brazos (Aislamiento)\n'
          '◦Curl: 3 series de 12 repeticiones',
        );
        final curl = result.draft.exercises.single;
        expect(curl.groupLabel, 'Biserie de Brazos (Aislamiento)');
        expect(curl.supersetWithPrevious, isFalse);
      },
    );
  });

  group('lo que no entiende', () {
    test('dos bloques de series en un ejercicio: toma el primero y avisa', () {
      final flyes = exercise('Pájaros con dos agarres');
      expect((flyes.workSets, flyes.repsMin, flyes.repsMax), (4, 10, 12));
      expect(flyes.note, contains('4 series de 10-12 repeticiones'));
      expect(flyes.warning, contains('dos bloques de series'));
    });

    test('sin series reconocibles conserva el texto como nota y avisa', () {
      final carry = exercise('Caminata de Granjero');
      expect(carry.workSets, isNull);
      expect(carry.note, 'Ida y vuelta al pasillo');
      expect(carry.warning, 'No se entendieron las series de este ejercicio.');
    });

    test('series sin repeticiones avisa', () {
      final result = parseRoutine('R\nDía 1: X\n◦Remo: 4 series pesadas');
      final row = result.draft.exercises.single;
      expect(row.workSets, 4);
      expect(row.warning, contains('No se entendieron las repeticiones'));
    });

    test('cuenta todo lo que hay que revisar', () {
      expect(parsed.warningCount, 2);
      expect(parsed.warnings, isEmpty);
    });
  });

  group('documentos inesperados', () {
    test('un texto que no es una rutina avisa que no hay ejercicios', () {
      final result = parseRoutine('Factura 123\nTotal: 500 pesos');

      expect(result.draft.exercises, isEmpty);
      expect(
        result.warnings.single,
        contains('No se encontró ningún ejercicio'),
      );
    });

    test('una rutina sin días se guarda en uno solo y avisa', () {
      final result = parseRoutine(
        'Mi rutina\n◦Sentadilla: 4 series de 8 repeticiones',
      );

      expect(result.draft.days.single.name, 'Día 1');
      expect(result.draft.exercises.single.name, 'Sentadilla');
      expect(result.warnings.single, contains('no separa los días'));
    });

    test('un texto vacío no falla', () {
      final result = parseRoutine('');
      expect(result.draft.name, 'Rutina de entrenamiento');
      expect(result.draft.days, isEmpty);
    });
  });

  group('formato libre (otro entrenador)', () {
    late ParsedRoutine result;
    late RoutineDraft routine;

    setUpAll(() {
      result = parseRoutine(
        File('test/fixtures/rutina_formato_libre_ejemplo.txt')
            .readAsStringSync(),
      );
      routine = result.draft;
    });

    RoutineExerciseDraft find(String name) =>
        routine.exercises.singleWhere((e) => e.name == name);

    test('días en mayúsculas y numeración rota', () {
      expect(routine.name, 'Plan de entrenamiento Ejemplo');
      expect(routine.days.map((d) => d.name), [
        'Pierna (Glúteo y Femoral)',
        'Torso + HIIT',
        'Glúteo',
      ]);
      // "2. 3. Puente…" y el renglón sin número que sigue son dos ejercicios.
      expect(routine.days.first.exercises.map((e) => e.name).take(3), [
        'Calentamiento dinámico',
        'Puente de Glúteo Pesado (con barra)',
        'Peso Muerto con Mancuernas (pies separados)',
      ]);
    });

    test('"N series x A-B reps", también partido en dos renglones', () {
      final bridge = find('Puente de Glúteo Pesado (con barra)');
      expect((bridge.workSets, bridge.repsMin, bridge.repsMax), (5, 8, 10));
      expect(bridge.note, 'Pesadas');

      final deadlift = find('Peso Muerto con Mancuernas (pies separados)');
      expect((deadlift.workSets, deadlift.repsMax), (4, 10));
    });

    test('"4 x15 reps" sin la palabra series', () {
      final dips = find('Fondos asistidos');
      expect((dips.workSets, dips.repsMin, dips.repsMax), (4, 15, 15));
    });

    test('la biserie presta sus series y une los ejercicios con etiqueta', () {
      final lunges = find('Zancadas con mancuernas');
      expect((lunges.workSets, lunges.repsMin), (3, 10));
      expect(lunges.note, 'Por pierna');
      expect(lunges.supersetWithPrevious, isFalse);
      expect(find('Curl Femoral acostado').supersetWithPrevious, isTrue);
    });

    test('un encabezado de biserie partido en varios renglones', () {
      // "1. BISERIE 2" / "-" / "(3 series):"
      final seated = find('Curl Femoral sentado');
      expect(seated.workSets, 3);
      expect(find('Patada de glúteo en polea').repsMax, 15);
      // "3. BISERIE 1" / "-" / "ESPALDA (4 series en total):"
      expect(find('Remo en polea baja').workSets, 4);
      final facePull = find('Face pull');
      expect((facePull.workSets, facePull.repsNote), (4, 'al fallo'));
      expect(facePull.supersetWithPrevious, isTrue);
    });

    test('un ejercicio numerado después de la biserie la cierra', () {
      expect(find('Hiperextensiones').supersetWithPrevious, isFalse);
      expect(find('Fondos asistidos').supersetWithPrevious, isFalse);
      expect(find('Elevaciones de talón').supersetWithPrevious, isFalse);
    });

    test('etiquetas con dos puntos y numeradas ("3. D1: …")', () {
      expect(find('Puente en máquina').supersetWithPrevious, isFalse);
      expect(find('Patada en polea').supersetWithPrevious, isTrue);
    });

    test('drop set y repeticiones extra quedan en la nota', () {
      expect(find('Curl Femoral sentado').note, contains('drop set'));
      expect(find('Remo en polea baja').note, 'Completas + 10 reps parciales');
    });

    test('calentamiento y cardio guardan la duración, sin avisos', () {
      final warmup = find('Calentamiento dinámico');
      expect(warmup.workSets, isNull);
      expect(warmup.repsNote, '10 min');
      expect(warmup.warning, isNull);
      expect(warmup.note, contains('2 series de 20 reps'));

      final cardio = find('Cardio');
      expect((cardio.repsNote, cardio.note), ('30 min', 'Tipo LISS'));
    });

    test('las repeticiones pueden ir antes de las series', () {
      final activation = find('Activación');
      expect((activation.workSets, activation.repsMin), (1, 20));
      expect(activation.note, 'Abducción en polea ligeras por pierna');
    });

    test('un bloque en mayúsculas es un grupo con sus rondas', () {
      final plank = find('Plancha');
      expect(plank.groupLabel, 'ABDOMEN (4 rondas)');
      expect((plank.workSets, plank.repsNote), (4, '1 min'));
      expect(find('Crunch').repsNote, '30 seg');
    });

    test('"todos los días de torso" se copia solo a los días de torso', () {
      final names = [
        for (final day in routine.days) day.exercises.map((e) => e.name),
      ];
      // Va al final del día "Torso + HIIT"…
      expect(names[1].toList().reversed.take(2), ['Crunch', 'Plancha']);
      // …y no se queda en "Glúteo", donde aparecía en el documento.
      expect(names[2], isNot(contains('Plancha')));
      expect(names[0], isNot(contains('Plancha')));
      expect(result.warnings, isEmpty);
    });

    test('nada más queda por revisar', () {
      expect(routine.exercises.where((e) => e.warning != null), isEmpty);
    });
  });

  group('bloques para varios días', () {
    const days =
        'R\n'
        'Día 1: Tren Superior (Pecho)\n'
        '1. Press: 4 series x 10 reps\n'
        'Día 2: Piernas\n'
        '1. Sentadilla: 4 series x 8 reps\n'
        'Día 3: Tren superior (Espalda)\n'
        '1. Remo: 4 series x 10 reps\n';

    List<List<String>> namesByDay(String text) => [
      for (final day in parseRoutine(text).draft.days)
        day.exercises.map((e) => e.name).toList(),
    ];

    test('"todos los días" sin más va en todos', () {
      expect(namesByDay('${days}CORE: TODOS LOS DÍAS\n1. Plancha de 1 min\n'), [
        ['Press', 'Plancha'],
        ['Sentadilla', 'Plancha'],
        ['Remo', 'Plancha'],
      ]);
    });

    test('sin importar acentos, mayúsculas ni plural', () {
      expect(
        namesByDay(
          '${days}ABDOMEN: TODOS LOS DIAS DE PIERNA\n1. Crunch 30 seg\n',
        ),
        [
          ['Press'],
          ['Sentadilla', 'Crunch'],
          ['Remo'],
        ],
      );
    });

    test('puede aparecer antes de los días', () {
      final text =
          'R\nABDOMEN: TODOS LOS DÍAS DE SUPERIOR (3 rondas)\n'
          '1. Plancha de 1 min\n'
          '${days.substring(2)}';
      final routine = parseRoutine(text);
      expect(routine.warnings, isEmpty);
      expect(namesByDay(text), [
        ['Press', 'Plancha'],
        ['Sentadilla'],
        ['Remo', 'Plancha'],
      ]);
      expect(routine.draft.exercises.first.name, 'Press');
    });

    test('si ningún día coincide, se queda donde estaba y avisa', () {
      final result = parseRoutine(
        '${days}MOVILIDAD: TODOS LOS DÍAS DE CARDIO\n1. Gato-camello 1 min\n',
      );
      expect(result.draft.days.last.exercises.last.name, 'Gato-camello');
      expect(result.warnings.single, contains('ningún día se llama así'));
    });
  });

  group(
    'indicaciones generales, rangos de series y biseries en un renglón',
    () {
      const text =
          'Plan de entrenamiento Prueba\n'
          '• Regla general: calentar antes del primer básico. Descansos de\n'
          '2–3 min en básicos y 60–90 seg en accesorios.\n'
          'Día 1: Torso\n'
          '• Press de banca: 4 series × 6–10 reps\n'
          '• Remo sentado: 3–4 series × 8–12 reps (espalda media)\n'
          '• Biserie de Core (Plancha 30–60 seg + Crunch 15 reps): 3 rondas\n'
          'Día 2: Descanso activo\n';

      test('lo que va antes del primer día son indicaciones, no un día', () {
        final routine = parseRoutine(text);
        expect(routine.warnings, isEmpty);
        expect(routine.draft.days.map((d) => d.name), [
          'Torso',
          'Descanso activo',
        ]);
        expect(
          routine.draft.notes,
          'Regla general: calentar antes del primer básico. Descansos de '
          '2–3 min en básicos y 60–90 seg en accesorios.',
        );
      });

      test('"3–4 series" toma el mínimo y deja el rango en la nota', () {
        final row = parseRoutine(text).draft.days.first.exercises[1];
        expect((row.workSets, row.repsMin, row.repsMax), (3, 8, 12));
        expect(row.note, 'Entre 3 y 4 series · (espalda media)');
      });

      test('la biserie en un renglón se separa en sus ejercicios', () {
        final routine = parseRoutine(text);
        final [plank, crunch] = routine.draft.days.first.exercises.sublist(2);
        expect(
          (plank.name, plank.workSets, plank.repsNote),
          ('Plancha', 3, '30–60 seg'),
        );
        expect(
          (crunch.name, crunch.workSets, crunch.repsMin),
          ('Crunch', 3, 15),
        );
        expect(crunch.supersetWithPrevious, isTrue);
        expect(plank.groupLabel, 'Biserie de Core');
        expect(routine.warningCount, 0);
      });

      test('sin días, lo de antes sigue siendo un solo día', () {
        final routine = parseRoutine(
          'Rutina\n• Sentadilla: 3 series de 10 reps\n',
        );
        expect(routine.draft.notes, isNull);
        expect(routine.draft.days.single.exercises.single.name, 'Sentadilla');
      });
    },
  );
}
