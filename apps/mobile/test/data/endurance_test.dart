import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/tables/apnea_attempts.dart';
import 'package:anfybio/data/tables/sessions.dart';
import 'package:anfybio/data/tables/swim.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late String userId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Prueba'));
    userId = user.id;
  });
  tearDown(() => db.close());

  Future<String> createSession(SessionType type) async {
    final session = await db
        .into(db.sessions)
        .insertReturning(
          SessionsCompanion.insert(
            userId: userId,
            type: type,
            startedAt: DateTime.utc(2026, 11, 16, 7),
          ),
        );
    return session.id;
  }

  Matcher rejected = throwsA(isA<SqliteException>());

  group('natación', () {
    late String sessionId;
    setUp(() async => sessionId = await createSession(SessionType.swim));

    SwimIntervalsCompanion interval(int position, SwimStroke stroke) =>
        SwimIntervalsCompanion.insert(
          userId: userId,
          sessionId: sessionId,
          position: position,
          stroke: stroke,
          distanceM: 100,
          durationMs: 95000,
        );

    test(
      'una sesión admite varios estilos, cada uno con sus vueltas',
      () async {
        await db
            .into(db.swimDetails)
            .insert(
              SwimDetailsCompanion.insert(
                userId: userId,
                sessionId: sessionId,
                poolLengthM: 25,
              ),
            );
        final free = await db
            .into(db.swimIntervals)
            .insertReturning(interval(1, SwimStroke.freestyle));
        await db
            .into(db.swimIntervals)
            .insert(interval(2, SwimStroke.backstroke));
        for (var lap = 1; lap <= 4; lap++) {
          await db
              .into(db.swimLaps)
              .insert(
                SwimLapsCompanion.insert(
                  userId: userId,
                  intervalId: free.id,
                  lapNumber: lap,
                  splitMs: 23750,
                ),
              );
        }

        final intervals = await (db.select(
          db.swimIntervals,
        )..orderBy([(i) => OrderingTerm.asc(i.position)])).get();
        expect(intervals.map((i) => i.stroke), [
          SwimStroke.freestyle,
          SwimStroke.backstroke,
        ]);
        final laps = await (db.select(
          db.swimLaps,
        )..where((l) => l.intervalId.equals(free.id))).get();
        expect(laps, hasLength(4));
      },
    );

    test('una sesión solo puede tener un detalle de natación', () async {
      final detail = SwimDetailsCompanion.insert(
        userId: userId,
        sessionId: sessionId,
        poolLengthM: 25,
      );
      await db.into(db.swimDetails).insert(detail);
      await expectLater(db.into(db.swimDetails).insert(detail), rejected);
    });

    test('rechaza distancias y tiempos que no sean positivos', () async {
      final base = interval(1, SwimStroke.freestyle);
      await expectLater(
        db
            .into(db.swimIntervals)
            .insert(base.copyWith(distanceM: const Value(0))),
        rejected,
      );
      await expectLater(
        db
            .into(db.swimIntervals)
            .insert(base.copyWith(durationMs: const Value(-1))),
        rejected,
      );
    });
  });

  group('carrera', () {
    test('guarda la distancia; duración y RPE van en la sesión', () async {
      final sessionId = await createSession(SessionType.run);
      await db
          .into(db.runDetails)
          .insert(
            RunDetailsCompanion.insert(
              userId: userId,
              sessionId: sessionId,
              distanceM: 5000,
            ),
          );
      await (db.update(
        db.sessions,
      )..where((s) => s.id.equals(sessionId))).write(
        const SessionsCompanion(durationS: Value(1500), sessionRpe: Value(6)),
      );

      final run = await db.select(db.runDetails).getSingle();
      final session = await db.select(db.sessions).getSingle();
      expect(run.distanceM, 5000);
      expect(session.durationS, 1500);
      expect(session.sessionRpe, 6);
    });
  });

  group('apnea', () {
    late String sessionId;
    setUp(() async => sessionId = await createSession(SessionType.apnea));

    ApneaAttemptsCompanion attempt(
      ApneaKind kind, {
      int? durationMs,
      int? distanceM,
    }) => ApneaAttemptsCompanion.insert(
      userId: userId,
      sessionId: sessionId,
      position: 1,
      kind: kind,
      durationMs: Value(durationMs),
      distanceM: Value(distanceM),
    );

    test('la estática guarda tiempo y la dinámica distancia', () async {
      await db
          .into(db.apneaAttempts)
          .insert(attempt(ApneaKind.static, durationMs: 150000));
      await db
          .into(db.apneaAttempts)
          .insert(attempt(ApneaKind.dynamic, distanceM: 50));
      expect(await db.select(db.apneaAttempts).get(), hasLength(2));
    });

    test('la dinámica puede llevar además el tiempo', () async {
      await db
          .into(db.apneaAttempts)
          .insert(attempt(ApneaKind.dynamic, distanceM: 50, durationMs: 60000));
      final saved = await db.select(db.apneaAttempts).getSingle();
      expect(saved.durationMs, 60000);
    });

    test('rechaza una estática sin tiempo', () async {
      await expectLater(
        db
            .into(db.apneaAttempts)
            .insert(attempt(ApneaKind.static, distanceM: 50)),
        rejected,
      );
    });

    test('rechaza una dinámica sin distancia', () async {
      await expectLater(
        db
            .into(db.apneaAttempts)
            .insert(attempt(ApneaKind.dynamic, durationMs: 60000)),
        rejected,
      );
    });
  });
}
