import 'package:drift/drift.dart';

import '../../domain/training_load.dart';
import '../../domain/weight.dart';
import '../database.dart';
import '../tables/apnea_attempts.dart';
import '../tables/sessions.dart';
import '../tables/swim.dart';

/// La sesión no existe o fue borrada.
class SessionNotFound implements Exception {
  const SessionNotFound(this.sessionId);
  final String sessionId;

  @override
  String toString() => 'SessionNotFound: $sessionId';
}

/// Se intentó guardar un dato de un tipo en una sesión de otro tipo.
class WrongSessionType implements Exception {
  const WrongSessionType({required this.expected, required this.actual});
  final SessionType expected;
  final SessionType actual;

  @override
  String toString() =>
      'WrongSessionType: se esperaba ${expected.name}, es ${actual.name}';
}

/// El ejercicio no existe, fue borrado o pertenece a otro usuario.
class ExerciseNotFound implements Exception {
  const ExerciseNotFound(this.exerciseId);
  final String exerciseId;

  @override
  String toString() => 'ExerciseNotFound: $exerciseId';
}

/// Única puerta de entrada para leer y escribir entrenamientos.
///
/// Aquí viven las reglas que la base de datos no puede garantizar sola:
/// - coherencia de tipo: una serie de fuerza solo entra en una sesión de fuerza;
/// - borrado lógico en cascada: borrar una sesión marca también sus hijos;
/// - las lecturas nunca devuelven filas borradas;
/// - toda modificación actualiza `updatedAt`.
class TrainingRepository {
  TrainingRepository(
    this._db, {
    DateTime Function()? now,
    DateTime Function(DateTime utc)? toLocal,
  }) : _now = now ?? (() => DateTime.now().toUtc()),
       _toLocal = toLocal ?? ((utc) => utc.toLocal());

  final AppDatabase _db;

  /// Reloj y zona horaria inyectables para que las pruebas sean deterministas.
  final DateTime Function() _now;
  final DateTime Function(DateTime utc) _toLocal;

  // ---------------------------------------------------------------- sesiones

  /// Inicia una sesión de fuerza, carrera o apnea.
  Future<Session> startSession({
    required String userId,
    required SessionType type,
    DateTime? startedAt,
  }) {
    if (type == SessionType.swim) {
      throw ArgumentError('La natación se inicia con startSwimSession.');
    }
    return _insertSession(userId, type, startedAt);
  }

  /// Inicia una sesión de natación junto con su tamaño de alberca.
  ///
  /// Ambas filas se guardan en una transacción: o existen las dos o ninguna.
  Future<Session> startSwimSession({
    required String userId,
    required int poolLengthM,
    DateTime? startedAt,
  }) {
    return _db.transaction(() async {
      final session = await _insertSession(userId, SessionType.swim, startedAt);
      await _db
          .into(_db.swimDetails)
          .insert(
            SwimDetailsCompanion.insert(
              userId: userId,
              sessionId: session.id,
              poolLengthM: poolLengthM,
            ),
          );
      return session;
    });
  }

  /// Cierra la sesión con su duración y esfuerzo percibido (1–10).
  Future<void> finishSession(
    String sessionId, {
    required int durationS,
    required int sessionRpe,
  }) async {
    await _requireSession(sessionId);
    await (_db.update(
      _db.sessions,
    )..where((s) => s.id.equals(sessionId))).write(
      SessionsCompanion(
        durationS: Value(durationS),
        sessionRpe: Value(sessionRpe),
        updatedAt: Value(_now()),
      ),
    );
  }

  /// Borra la sesión y todo lo que cuelga de ella (borrado lógico).
  Future<void> deleteSession(String sessionId) async {
    await _requireSession(sessionId);
    final now = Value(_now());

    await _db.transaction(() async {
      final intervalIds = _db.selectOnly(_db.swimIntervals)
        ..addColumns([_db.swimIntervals.id])
        ..where(_db.swimIntervals.sessionId.equals(sessionId));
      await (_db.update(_db.swimLaps)
            ..where((l) => l.intervalId.isInQuery(intervalIds))
            ..where((l) => l.deletedAt.isNull()))
          .write(SwimLapsCompanion(deletedAt: now, updatedAt: now));

      await (_db.update(_db.swimIntervals)
            ..where((i) => i.sessionId.equals(sessionId))
            ..where((i) => i.deletedAt.isNull()))
          .write(SwimIntervalsCompanion(deletedAt: now, updatedAt: now));
      await (_db.update(_db.swimDetails)
            ..where((d) => d.sessionId.equals(sessionId))
            ..where((d) => d.deletedAt.isNull()))
          .write(SwimDetailsCompanion(deletedAt: now, updatedAt: now));
      await (_db.update(_db.runDetails)
            ..where((d) => d.sessionId.equals(sessionId))
            ..where((d) => d.deletedAt.isNull()))
          .write(RunDetailsCompanion(deletedAt: now, updatedAt: now));
      await (_db.update(_db.apneaAttempts)
            ..where((a) => a.sessionId.equals(sessionId))
            ..where((a) => a.deletedAt.isNull()))
          .write(ApneaAttemptsCompanion(deletedAt: now, updatedAt: now));
      await (_db.update(_db.strengthSets)
            ..where((s) => s.sessionId.equals(sessionId))
            ..where((s) => s.deletedAt.isNull()))
          .write(StrengthSetsCompanion(deletedAt: now, updatedAt: now));
      await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
          .write(SessionsCompanion(deletedAt: now, updatedAt: now));
    });
  }

  /// Sesiones del usuario, de la más reciente a la más antigua.
  Future<List<Session>> sessionsOf(String userId) => _sessionsOf(userId).get();

  /// Igual que [sessionsOf], pero vuelve a emitir cada vez que cambian.
  Stream<List<Session>> watchSessionsOf(String userId) =>
      _sessionsOf(userId).watch();

  /// Una sesión concreta; emite `null` si no existe o fue borrada.
  Stream<Session?> watchSession(String sessionId) {
    return (_db.select(_db.sessions)
          ..where((s) => s.id.equals(sessionId) & s.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  SimpleSelectStatement<$SessionsTable, Session> _sessionsOf(String userId) {
    return _db.select(_db.sessions)
      ..where((s) => s.userId.equals(userId) & s.deletedAt.isNull())
      ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]);
  }

  // ------------------------------------------------------------------ fuerza

  /// Agrega una serie al final de una sesión de fuerza.
  Future<StrengthSet> addStrengthSet({
    required String sessionId,
    required String exerciseId,
    required double weight,
    required WeightUnit weightUnit,
    required int reps,
    double? rpe,
    bool isWarmup = false,
  }) {
    return _db.transaction(() async {
      final session = await _requireSession(sessionId, SessionType.strength);
      await _requireExercise(exerciseId, session.userId);

      return _db
          .into(_db.strengthSets)
          .insertReturning(
            StrengthSetsCompanion.insert(
              userId: session.userId,
              sessionId: sessionId,
              exerciseId: exerciseId,
              position: await _nextPosition(
                _db.strengthSets,
                _db.strengthSets.position,
                _db.strengthSets.sessionId,
                sessionId,
              ),
              weight: weight,
              weightUnit: weightUnit,
              reps: reps,
              rpe: Value(rpe),
              isWarmup: Value(isWarmup),
            ),
          );
    });
  }

  /// Series de una sesión en el orden en que se hicieron.
  Future<List<StrengthSet>> strengthSetsOf(String sessionId) =>
      _strengthSetsOf(sessionId).get();

  /// Igual que [strengthSetsOf], pero vuelve a emitir cada vez que cambian.
  Stream<List<StrengthSet>> watchStrengthSetsOf(String sessionId) =>
      _strengthSetsOf(sessionId).watch();

  SimpleSelectStatement<$StrengthSetsTable, StrengthSet> _strengthSetsOf(
    String sessionId,
  ) {
    return _db.select(_db.strengthSets)
      ..where((s) => s.sessionId.equals(sessionId) & s.deletedAt.isNull())
      ..orderBy([(s) => OrderingTerm.asc(s.position)]);
  }

  // ---------------------------------------------------------------- natación

  /// Agrega un bloque a una sesión de natación, con sus parciales por vuelta
  /// si se registraron.
  Future<SwimInterval> addSwimInterval({
    required String sessionId,
    required SwimStroke stroke,
    required int distanceM,
    required int durationMs,
    List<int> lapSplitsMs = const [],
  }) {
    return _db.transaction(() async {
      final session = await _requireSession(sessionId, SessionType.swim);

      final interval = await _db
          .into(_db.swimIntervals)
          .insertReturning(
            SwimIntervalsCompanion.insert(
              userId: session.userId,
              sessionId: sessionId,
              position: await _nextPosition(
                _db.swimIntervals,
                _db.swimIntervals.position,
                _db.swimIntervals.sessionId,
                sessionId,
              ),
              stroke: stroke,
              distanceM: distanceM,
              durationMs: durationMs,
            ),
          );

      for (final (index, splitMs) in lapSplitsMs.indexed) {
        await _db
            .into(_db.swimLaps)
            .insert(
              SwimLapsCompanion.insert(
                userId: session.userId,
                intervalId: interval.id,
                lapNumber: index + 1,
                splitMs: splitMs,
              ),
            );
      }
      return interval;
    });
  }

  // ----------------------------------------------------------------- carrera

  /// Guarda la distancia de una sesión de carrera.
  Future<void> setRunDistance(String sessionId, {required int distanceM}) {
    return _db.transaction(() async {
      final session = await _requireSession(sessionId, SessionType.run);

      final updated =
          await (_db.update(_db.runDetails)..where(
                (d) => d.sessionId.equals(sessionId) & d.deletedAt.isNull(),
              ))
              .write(
                RunDetailsCompanion(
                  distanceM: Value(distanceM),
                  updatedAt: Value(_now()),
                ),
              );
      if (updated == 0) {
        await _db
            .into(_db.runDetails)
            .insert(
              RunDetailsCompanion.insert(
                userId: session.userId,
                sessionId: sessionId,
                distanceM: distanceM,
              ),
            );
      }
    });
  }

  // ------------------------------------------------------------------- apnea

  /// Agrega un intento a una sesión de apnea.
  ///
  /// La estática exige [durationMs] y la dinámica [distanceM]; lo valida la
  /// base de datos.
  Future<ApneaAttempt> addApneaAttempt({
    required String sessionId,
    required ApneaKind kind,
    int? durationMs,
    int? distanceM,
  }) {
    return _db.transaction(() async {
      final session = await _requireSession(sessionId, SessionType.apnea);

      return _db
          .into(_db.apneaAttempts)
          .insertReturning(
            ApneaAttemptsCompanion.insert(
              userId: session.userId,
              sessionId: sessionId,
              position: await _nextPosition(
                _db.apneaAttempts,
                _db.apneaAttempts.position,
                _db.apneaAttempts.sessionId,
                sessionId,
              ),
              kind: kind,
              durationMs: Value(durationMs),
              distanceM: Value(distanceM),
            ),
          );
    });
  }

  // ------------------------------------------------------------------- carga

  /// Carga sRPE de cada sesión terminada, ubicada en su día **local**.
  ///
  /// `startedAt` se guarda en UTC; una sesión a las 8 p. m. en México ya es
  /// "mañana" en UTC, así que se convierte antes de asignarle día.
  Future<List<LoadEntry>> loadEntriesOf(String userId) async {
    final sessions = await sessionsOf(userId);
    return [
      for (final session in sessions)
        if (sessionLoad(
              durationS: session.durationS,
              sessionRpe: session.sessionRpe,
            )
            case final load?)
          LoadEntry(day: _toLocal(session.startedAt), load: load),
    ];
  }

  // ---------------------------------------------------------------- internos

  Future<Session> _insertSession(
    String userId,
    SessionType type,
    DateTime? startedAt,
  ) {
    return _db
        .into(_db.sessions)
        .insertReturning(
          SessionsCompanion.insert(
            userId: userId,
            type: type,
            startedAt: (startedAt ?? _now()).toUtc(),
          ),
        );
  }

  /// Devuelve la sesión si existe, no está borrada y es del tipo esperado.
  Future<Session> _requireSession(String sessionId, [SessionType? type]) async {
    final session =
        await (_db.select(_db.sessions)
              ..where((s) => s.id.equals(sessionId) & s.deletedAt.isNull()))
            .getSingleOrNull();
    if (session == null) throw SessionNotFound(sessionId);
    if (type != null && session.type != type) {
      throw WrongSessionType(expected: type, actual: session.type);
    }
    return session;
  }

  Future<void> _requireExercise(String exerciseId, String userId) async {
    final exercise =
        await (_db.select(_db.exercises)..where(
              (e) =>
                  e.id.equals(exerciseId) &
                  e.userId.equals(userId) &
                  e.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (exercise == null) throw ExerciseNotFound(exerciseId);
  }

  /// Siguiente posición libre dentro de la sesión (1 si está vacía).
  ///
  /// Cuenta también las filas borradas para no reutilizar una posición.
  Future<int> _nextPosition(
    TableInfo table,
    GeneratedColumn<int> position,
    GeneratedColumn<String> sessionIdColumn,
    String sessionId,
  ) async {
    final maxPosition = position.max();
    final query = _db.selectOnly(table)
      ..addColumns([maxPosition])
      ..where(sessionIdColumn.equals(sessionId));
    final current = await query.map((row) => row.read(maxPosition)).getSingle();
    return (current ?? 0) + 1;
  }
}
