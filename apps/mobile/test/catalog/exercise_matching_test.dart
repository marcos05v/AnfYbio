import 'package:anfybio/catalog/catalog_exercise.dart';
import 'package:anfybio/catalog/exercise_matching.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogExercise exercise(String id, String nameEn, String nameEs) =>
    CatalogExercise(
      id: id,
      name: nameEs,
      nameEn: nameEn,
      level: 'beginner',
      category: 'strength',
      primaryMuscles: const [],
      secondaryMuscles: const [],
      instructions: const [],
      images: const [],
    );

void main() {
  final candidates = [
    for (final e in [
      exercise(
        'bench',
        'Barbell Bench Press - Medium Grip',
        'Press de banca con barra - agarre medio',
      ),
      exercise(
        'incline_db',
        'Incline Dumbbell Press',
        'Press inclinado con mancuernas',
      ),
      exercise('squat', 'Barbell Squat', 'Sentadilla con barra'),
      exercise('hack', 'Hack Squat', 'Sentadilla hack'),
      exercise('rdl', 'Romanian Deadlift', 'Peso muerto rumano'),
      exercise('lateral', 'Side Lateral Raise', 'Elevación lateral'),
      exercise(
        'rope',
        'Triceps Pushdown - Rope Attachment',
        'Jalón de tríceps con cuerda',
      ),
      exercise('face', 'Face Pull', 'Face pull'),
      exercise('calf', 'Standing Calf Raises', 'Elevación de talones de pie'),
    ])
      MatchCandidate.of(e),
  ];

  String? top(String query) =>
      rankMatches(query, candidates).firstOrNull?.exercise.id;

  group('normalizar y traducir', () {
    test('quita acentos, mayúsculas y signos', () {
      expect(
        normalizeText('Elevación  de TALONES (Pantorrilla)'),
        'elevacion de talones pantorrilla',
      );
    });

    test('traduce primero las frases y luego las palabras sueltas', () {
      expect(
        translateToCatalog('Press de Banca Plano con Barra'),
        'bench press flat con barbell',
      );
      expect(
        translateToCatalog('Peso Muerto Rumano con Mancuernas'),
        'deadlift romanian con dumbbell',
      );
    });

    test('deja igual lo que ya se dice en inglés', () {
      expect(translateToCatalog('Curl predicador'), 'curl preacher');
    });
  });

  group('sugerencias', () {
    test('un nombre del plan en español encuentra su ejercicio', () {
      expect(top('Press de Banca Plano con Barra'), 'bench');
      expect(top('Press de banca inclinado con mancuernas'), 'incline_db');
      expect(top('Peso muerto rumano con barra'), 'rdl');
      expect(top('Sentadilla Hack (Pies Cerrados)'), 'hack');
      expect(top('Elevación de talones de pie (gemelos)'), 'calf');
    });

    test('distingue variantes parecidas', () {
      expect(top('Sentadilla con barra a banco'), 'squat');
      expect(top('Sentadilla hack'), 'hack');
    });

    test('funciona también buscando en inglés', () {
      expect(top('face pull'), 'face');
      expect(top('romanian deadlift'), 'rdl');
    });

    test('las mejores sugerencias van primero y con puntuación', () {
      final matches = rankMatches('Press con mancuernas', candidates);
      expect(matches.first.exercise.id, 'incline_db');
      for (var i = 1; i < matches.length; i++) {
        expect(matches[i].score, lessThanOrEqualTo(matches[i - 1].score));
      }
    });

    test('una coincidencia exacta es confiable; una vaga, no', () {
      expect(
        rankMatches('Face pull', candidates).first.score,
        greaterThanOrEqualTo(confidentMatchScore),
      );
      expect(
        rankMatches('Abdominales en máquina', candidates).firstOrNull?.score ??
            0,
        lessThan(confidentMatchScore),
      );
    });

    test('limita el número de sugerencias', () {
      expect(rankMatches('barra', candidates, limit: 2), hasLength(2));
    });

    test('una búsqueda vacía o sin palabras útiles no sugiere nada', () {
      expect(rankMatches('', candidates), isEmpty);
      expect(rankMatches('de la con', candidates), isEmpty);
    });

    test('lo que no se parece a nada no aparece', () {
      expect(rankMatches('natación crol', candidates), isEmpty);
    });
  });
}
