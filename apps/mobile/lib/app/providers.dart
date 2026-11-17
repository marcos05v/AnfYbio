import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repositories/exercise_repository.dart';
import '../data/repositories/training_repository.dart';
import '../data/repositories/user_repository.dart';
import '../domain/one_rep_max_history.dart';

/// La base de datos local. Las pruebas la reemplazan por una en memoria.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final userRepositoryProvider = Provider(
  (ref) => UserRepository(ref.watch(databaseProvider)),
);

final exerciseRepositoryProvider = Provider(
  (ref) => ExerciseRepository(ref.watch(databaseProvider)),
);

final trainingRepositoryProvider = Provider(
  (ref) => TrainingRepository(ref.watch(databaseProvider)),
);

/// El usuario del dispositivo; `null` hasta que se crea en la bienvenida.
final currentUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(userRepositoryProvider).watchCurrentUser(),
);

/// Consultas vivas: la pantalla que las observa se redibuja sola cuando
/// cambian los datos. `family` crea un proveedor por cada id.
final sessionsProvider = StreamProvider.family<List<Session>, String>(
  (ref, userId) =>
      ref.watch(trainingRepositoryProvider).watchSessionsOf(userId),
);

final sessionProvider = StreamProvider.family<Session?, String>(
  (ref, sessionId) =>
      ref.watch(trainingRepositoryProvider).watchSession(sessionId),
);

final strengthSetsProvider = StreamProvider.family<List<StrengthSet>, String>(
  (ref, sessionId) =>
      ref.watch(trainingRepositoryProvider).watchStrengthSetsOf(sessionId),
);

final exercisesProvider = StreamProvider.family<List<Exercise>, String>(
  (ref, userId) =>
      ref.watch(exerciseRepositoryProvider).watchExercisesOf(userId),
);

final swimDetailProvider = StreamProvider.family<SwimDetail?, String>(
  (ref, sessionId) =>
      ref.watch(trainingRepositoryProvider).watchSwimDetail(sessionId),
);

final swimIntervalsProvider = StreamProvider.family<List<SwimInterval>, String>(
  (ref, sessionId) =>
      ref.watch(trainingRepositoryProvider).watchSwimIntervalsOf(sessionId),
);

final swimLapsProvider = StreamProvider.family<List<SwimLap>, String>(
  (ref, sessionId) =>
      ref.watch(trainingRepositoryProvider).watchSwimLapsOf(sessionId),
);

final runDetailProvider = StreamProvider.family<RunDetail?, String>(
  (ref, sessionId) =>
      ref.watch(trainingRepositoryProvider).watchRunDetail(sessionId),
);

final apneaAttemptsProvider = StreamProvider.family<List<ApneaAttempt>, String>(
  (ref, sessionId) =>
      ref.watch(trainingRepositoryProvider).watchApneaAttemptsOf(sessionId),
);

/// Series de un ejercicio a lo largo del tiempo, para su gráfica de progreso.
final setSamplesProvider = StreamProvider.family<List<SetSample>, String>(
  (ref, exerciseId) =>
      ref.watch(trainingRepositoryProvider).watchSetSamplesOf(exerciseId),
);
