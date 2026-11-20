import 'dart:io';

import 'package:anfybio/import/nutrition_plan_parser.dart';
import 'package:anfybio/import/routine_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Revisa planes reales que viven fuera del repositorio. Se salta salvo que
/// se indique la carpeta; lo normal es correrla con tool/revisar_planes.sh.
///
/// Para cada archivo dice si lo leyó como rutina o como plan de
/// alimentación, cuánto encontró y cuánto queda por revisar. Falla si un
/// archivo no se pudo leer en absoluto.
void main() {
  final dir = Platform.environment['ANFYBIO_PLANS_DIR'];

  test(
    'los planes reales se pueden leer',
    () {
      final files =
          Directory(dir!)
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.txt'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      final unreadable = <String>[];

      for (final file in files) {
        final name = file.uri.pathSegments.last.replaceFirst('.txt', '');
        final text = file.readAsStringSync();
        final routine = parseRoutine(text);
        final plan = parseNutritionPlan(text);
        final exercises = routine.draft.exercises.length;
        final foods = plan.draft.items.length;

        // Se queda con la lectura que entendió más: cada lector acepta algo
        // del otro tipo de documento, pero lo marca para revisión.
        final understoodAsRoutine = exercises - routine.warningCount;
        final understoodAsPlan = foods - plan.warningCount;
        final String summary;
        final bool empty;
        if (understoodAsRoutine >= understoodAsPlan) {
          final review = routine.warningCount;
          summary =
              'rutina: ${routine.draft.days.length} días, $exercises '
              'ejercicios, $review por revisar '
              '(${_percent(exercises, review)} % entendido)';
          empty = exercises == 0;
        } else {
          final review = plan.warningCount;
          summary =
              'alimentación: ${plan.draft.menus.length} menús, $foods '
              'alimentos, ${plan.draft.supplements.length} suplementos, '
              '$review por revisar (${_percent(foods, review)} % entendido)';
          empty = foods == 0;
        }
        // ignore: avoid_print
        print('$name → $summary');
        if (empty) unreadable.add(name);
      }

      expect(
        unreadable,
        isEmpty,
        reason:
            'Estos archivos no se pudieron leer; su formato es nuevo: '
            '${unreadable.join(', ')}',
      );
    },
    skip: dir == null
        ? 'Corre tool/revisar_planes.sh <carpeta> para revisar planes reales'
        : false,
  );
}

int _percent(int total, int review) =>
    total == 0 ? 0 : ((total - review.clamp(0, total)) * 100 / total).round();
