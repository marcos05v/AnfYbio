import 'dart:convert';
import 'dart:io';

import 'package:anfybio/catalog/exercise_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas sobre el catálogo real incluido en la app.
void main() {
  final raw = File('assets/catalog/exercises.json').readAsStringSync();
  final entries = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  final catalog = BundledExerciseCatalog(() async => raw);

  group('validación contra el schema.json de free-exercise-db', () {
    final schema = jsonDecode(
      File('tool/catalog/free_exercise_db_schema.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final itemSchema = (schema['items'] ?? schema) as Map<String, dynamic>;

    test('cada ejercicio cumple el esquema original', () {
      final errors = <String>[
        for (final entry in entries)
          ...validate(entry, itemSchema, entry['id'] as String),
      ];
      expect(errors, isEmpty, reason: errors.take(10).join('\n'));
    });

    test('force, mechanic y equipment pueden venir nulos', () {
      for (final field in ['force', 'mechanic', 'equipment']) {
        expect(entries.any((e) => e[field] == null), isTrue, reason: field);
      }
    });
  });

  group('traducción', () {
    test('todos los ejercicios tienen nombre e instrucciones en español', () {
      for (final entry in entries) {
        final es = entry['es'] as Map<String, dynamic>;
        expect(
          (es['name'] as String).trim(),
          isNotEmpty,
          reason: '${entry['id']}',
        );
        expect(
          (es['instructions'] as List).length,
          (entry['instructions'] as List).length,
          reason: '${entry['id']}',
        );
      }
    });
  });

  group('catálogo', () {
    test('trae los 876 ejercicios', () {
      expect(entries, hasLength(876));
    });

    test('busca por identificador', () async {
      final bench = await catalog.getById('Barbell_Bench_Press_-_Medium_Grip');
      expect(bench!.name, 'Press de banca con barra - agarre medio');
      expect(bench.nameEn, 'Barbell Bench Press - Medium Grip');
      expect(bench.images, [
        'Barbell_Bench_Press_-_Medium_Grip/0.jpg',
        'Barbell_Bench_Press_-_Medium_Grip/1.jpg',
      ]);
      expect(await catalog.getById('no-existe'), isNull);
    });
  });

  group('emparejamiento con nombres típicos de una rutina', () {
    // Nombre como lo escribe un entrenador → ejercicio que le corresponde.
    const expected = {
      'Press de Banca Plano con Barra': 'Barbell_Bench_Press_-_Medium_Grip',
      'Press de Banca Inclinado con Mancuernas': 'Incline_Dumbbell_Press',
      'Aperturas con Mancuernas en Banco Plano': 'Dumbbell_Flyes',
      'Press Declinado': 'Decline_Barbell_Bench_Press',
      'Cruces en Polea (de Alta a Baja)': 'Cable_Crossover',
      'Press Francés con barra en Banco Plano': 'Lying_Triceps_Press',
      'Extensiones de Tríceps en Polea Alta con Cuerda':
          'Triceps_Pushdown_-_Rope_Attachment',
      'Fondos en máquina': 'Dip_Machine',
      'Extensiones de Cuádriceps en Máquina': 'Leg_Extensions',
      'Sentadilla con Barra a banco': 'Barbell_Squat_To_A_Bench',
      'Prensa de Piernas': 'Leg_Press',
      'Sentadilla Hack (Pies Cerrados)': 'Hack_Squat',
      'Desplantes Fijos (Split Squats) con Mancuernas':
          'Split_Squat_with_Dumbbells',
      'Elevación de Talones de Pie (Gemelos)': 'Standing_Calf_Raises',
      'Elevación de Talones Sentado (Pantorrillera)': 'Seated_Calf_Raise',
      'Jalón al Pecho (Agarre Pronado)': 'Wide-Grip_Lat_Pulldown',
      'Dominadas Asistidas': 'Band_Assisted_Pull-Up',
      'Remo en Polea Baja con Agarre Estrecho': 'Seated_Cable_Rows',
      'Remo con Mancuerna (Unilateral apoyado en banco)':
          'One-Arm_Dumbbell_Row',
      'Remo en Barra T con apoyo al pecho': 'Lying_T-Bar_Row',
      'Curl en Banco Inclinado con Mancuernas': 'Incline_Dumbbell_Curl',
      'Curl Tipo Martillo con Mancuernas': 'Hammer_Curls',
      'Press militar en Smith': 'Smith_Machine_Overhead_Shoulder_Press',
      'Press Arnold con Mancuernas': 'Arnold_Dumbbell_Press',
      'Elevaciones Laterales con Mancuernas': 'Side_Lateral_Raise',
      'Jalon al mentón con barra Z': 'Upright_Barbell_Row',
      'Elevaciones Frontales con polea baja': 'Front_Cable_Raise',
      'Encogimientos de Hombros con Mancuernas': 'Dumbbell_Shrug',
      'Peso Muerto Rumano con Mancuernas o Barra': 'Romanian_Deadlift',
      'Curl de Pierna Acostado en Máquina': 'Lying_Leg_Curls',
      'Hip Thrust (Empuje de Cadera)': 'Barbell_Hip_Thrust',
      'Abducciones en máquina': 'Thigh_Abductor',
      'Plancha Abdominal (Plank)': 'Plank',
      'Elevación de Piernas Colgado en máquina': 'Hanging_Leg_Raise',
      'Curl de Bíceps con Barra Z de Pie': 'EZ-Bar_Curl',
      'Curl predicador con barra Z': 'Preacher_Curl',
      'Pájaros en Polea': 'Cable_Rear_Delt_Fly',
      'Face pull': 'Face_Pull',
      'Pullover con mancuerna': 'Bent-Arm_Dumbbell_Pullover',
      // Mismo ejercicio con otro nombre (sinónimos del buscador).
      'Pullover en polea': 'Straight-Arm_Pulldown',
      'Pull over con cuerda': 'Rope_Straight-Arm_Pulldown',
      'Jalón de tríceps con cuerda': 'Triceps_Pushdown_-_Rope_Attachment',
      'Activación de Aductores en Máquina o con Banda': 'Thigh_Adductor',
      'Pájaros con Mancuernas en banco inclinado': 'Reverse_Flyes',
      'Curl con barra Z': 'EZ-Bar_Curl',
      'Press francés con barra Z': 'EZ-Bar_Skullcrusher',
    };

    test('los nombres esperados existen en el catálogo', () async {
      for (final id in expected.values) {
        expect(await catalog.getById(id), isNotNull, reason: id);
      }
    });

    test('al menos el 90 % aparece entre las 3 primeras sugerencias', () async {
      final misses = <String>[];
      var first = 0;
      for (final MapEntry(key: name, value: id) in expected.entries) {
        final top = await catalog.search(name, limit: 3);
        final ids = top.map((m) => m.exercise.id).toList();
        if (ids.firstOrNull == id) first++;
        if (!ids.contains(id)) misses.add('$name → ${ids.join(', ')}');
      }
      final hitRate = 1 - misses.length / expected.length;
      // Se imprime para seguir la evolución del algoritmo.
      // ignore: avoid_print
      print(
        'Emparejamiento: ${(hitRate * 100).round()} % entre las 3 primeras, '
        '${(first / expected.length * 100).round()} % en primer lugar. '
        'Fallos:\n  ${misses.join('\n  ')}',
      );
      expect(hitRate, greaterThanOrEqualTo(0.9));
      expect(first / expected.length, greaterThanOrEqualTo(0.7));
    });
  });
}

/// Un validador mínimo de JSON Schema: lo que usa el esquema del catálogo
/// (required, type con nulos, enum, pattern, items).
List<String> validate(Object? value, Map<String, dynamic> schema, String path) {
  final errors = <String>[];
  final types = switch (schema['type']) {
    final String t => [t],
    final List<dynamic> t => t.cast<String>(),
    _ => const <String>[],
  };
  bool isType(String type) => switch (type) {
    'string' => value is String,
    'array' => value is List,
    'object' => value is Map,
    'null' => value == null,
    'number' => value is num,
    'integer' => value is int,
    'boolean' => value is bool,
    _ => true,
  };
  if (types.isNotEmpty && !types.any(isType)) {
    return ['$path: tipo ${value.runtimeType}, se esperaba $types'];
  }
  if (schema['enum'] case final List<dynamic> options
      when !options.contains(value)) {
    errors.add('$path: "$value" no está en $options');
  }
  if (schema['pattern'] case final String pattern when value is String) {
    if (!RegExp(pattern).hasMatch(value)) {
      errors.add('$path: no cumple $pattern');
    }
  }
  if (value is Map<String, dynamic>) {
    for (final field in (schema['required'] as List<dynamic>? ?? const [])) {
      if (!value.containsKey(field)) errors.add('$path: falta "$field"');
    }
    final properties =
        schema['properties'] as Map<String, dynamic>? ?? const {};
    for (final MapEntry(:key, value: sub) in properties.entries) {
      if (value.containsKey(key)) {
        errors.addAll(
          validate(value[key], sub as Map<String, dynamic>, '$path.$key'),
        );
      }
    }
  }
  if (value is List && schema['items'] != null) {
    final items = schema['items'];
    // El esquema usa la forma antigua de items: una lista con un solo
    // esquema que aplica a todos los elementos.
    final itemSchema =
        (items is List ? items.first : items) as Map<String, dynamic>;
    for (final (index, item) in value.indexed) {
      errors.addAll(validate(item, itemSchema, '$path[$index]'));
    }
  }
  return errors;
}
