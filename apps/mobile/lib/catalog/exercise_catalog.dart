import 'dart:convert';

import 'catalog_exercise.dart';
import 'exercise_matching.dart';

/// Un catálogo de ejercicios. Es una interfaz para poder cambiar de fuente
/// (otro archivo, un servidor propio) sin tocar las pantallas (ADR-0015).
abstract class ExerciseCatalog {
  /// El ejercicio con ese identificador, o `null` si no existe.
  Future<CatalogExercise?> getById(String id);

  /// Los ejercicios que mejor coinciden con [query], del más parecido al
  /// menos. Entiende nombres en español y en inglés.
  Future<List<CatalogMatch>> search(String query, {int limit = 20});
}

/// El catálogo incluido en la app: un archivo JSON con los ejercicios de
/// free-exercise-db y su traducción.
class BundledExerciseCatalog implements ExerciseCatalog {
  /// [load] devuelve el contenido del archivo: en la app lo lee de los
  /// recursos; en las pruebas, de disco.
  BundledExerciseCatalog(this._load);

  final Future<String> Function() _load;
  Future<_Index>? _index;

  Future<_Index> _ready() => _index ??= () async {
    final entries = jsonDecode(await _load()) as List<dynamic>;
    final exercises = [
      for (final entry in entries)
        CatalogExercise.fromJson(entry as Map<String, dynamic>),
    ];
    return _Index(
      {for (final e in exercises) e.id: e},
      [for (final e in exercises) MatchCandidate.of(e)],
    );
  }();

  /// Todos los ejercicios, en el orden del archivo.
  Future<List<CatalogExercise>> all() async =>
      (await _ready()).byId.values.toList();

  @override
  Future<CatalogExercise?> getById(String id) async =>
      (await _ready()).byId[id];

  @override
  Future<List<CatalogMatch>> search(String query, {int limit = 20}) async {
    final index = await _ready();
    return rankMatches(query, index.candidates, limit: limit);
  }
}

class _Index {
  _Index(this.byId, this.candidates);

  final Map<String, CatalogExercise> byId;
  final List<MatchCandidate> candidates;
}
