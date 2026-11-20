import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/catalog_exercise.dart';
import '../catalog/exercise_catalog.dart';
import '../catalog/exercise_images.dart';
import '../data/repositories/catalog_link_repository.dart';
import 'providers.dart';

/// El catálogo de ejercicios incluido en la app (ADR-0015).
final exerciseCatalogProvider = Provider<ExerciseCatalog>(
  (ref) => BundledExerciseCatalog(
    () => rootBundle.loadString('assets/catalog/exercises.json'),
  ),
);

/// Las fotos de los ejercicios. Por defecto no hay (las pruebas no usan la
/// red); `main` lo reemplaza por las que se descargan y se guardan.
final exerciseImageStoreProvider = Provider<ExerciseImageStore>(
  (ref) => const NoImageStore(),
);

final catalogLinkRepositoryProvider = Provider(
  (ref) => CatalogLinkRepository(ref.watch(databaseProvider)),
);

/// Alias del usuario: nombre normalizado → id del catálogo.
final exerciseAliasesProvider =
    StreamProvider.family<Map<String, String>, String>(
      (ref, userId) =>
          ref.watch(catalogLinkRepositoryProvider).watchAliases(userId),
    );

/// Un ejercicio del catálogo por su id.
final catalogExerciseProvider = FutureProvider.family<CatalogExercise?, String>(
  (ref, id) => ref.watch(exerciseCatalogProvider).getById(id),
);
