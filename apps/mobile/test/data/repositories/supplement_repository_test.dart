import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/repositories/supplement_repository.dart';
import 'package:anfybio/data/repositories/training_repository.dart'
    show RecordNotFound;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SupplementRepository repo;
  late String userId;
  var clock = DateTime.utc(2026, 11, 16, 15);
  // "Ahora" en hora local para calcular existencias.
  final today = DateTime(2026, 11, 16, 9);

  setUp(() async {
    clock = DateTime.utc(2026, 11, 16, 15);
    db = AppDatabase(NativeDatabase.memory());
    repo = SupplementRepository(db, now: () => clock);
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Prueba'));
    userId = user.id;
  });
  tearDown(() => db.close());

  Future<Supplement> creatine({double? initialQuantity = 300}) =>
      repo.addSupplement(
        userId: userId,
        name: ' Creatina ',
        unitLabel: 'g',
        dailyDose: 5,
        timing: 'Con el post-entreno',
        initialQuantity: initialQuantity,
      );

  Future<SupplementView> view(String id) async =>
      (await repo.supplementsOf(userId))
          .singleWhere((v) => v.supplement.id == id);

  test(
    'dar de alta con existencias iniciales registra la primera compra',
    () async {
      final supplement = await creatine();

      final loaded = await view(supplement.id);
      expect(loaded.supplement.name, 'Creatina');
      expect(loaded.supplement.restockLeadDays, 7); // valor por defecto
      expect(loaded.purchases.single.quantity, 300);
      expect(loaded.statusAt(today).stock, 300);
      expect(loaded.statusAt(today).daysLeft, 60);
    },
  );

  test('un envase ya empezado descuenta lo estimado como ajuste', () async {
    final supplement = await repo.addSupplement(
      userId: userId,
      name: 'Zinc',
      unitLabel: 'pastillas',
      dailyDose: 1,
      initialQuantity: 60,
      purchasedAt: DateTime.utc(2026, 11, 6, 12),
      alreadyConsumed: 10,
    );

    final loaded = await view(supplement.id);
    expect(loaded.purchases.single.purchasedAt, DateTime.utc(2026, 11, 6, 12));
    expect(loaded.statusAt(today).stock, 50);
    // Es un ajuste: no aparece como toma ni cuenta para la adherencia.
    expect(loaded.intakes.single.isAdjustment, isTrue);
    expect(loaded.statusAt(today).adherence, isNull);
    expect(loaded.statusAt(today).takenToday, isFalse);
  });

  test('sin existencias iniciales empieza en cero', () async {
    final supplement = await creatine(initialQuantity: null);

    final loaded = await view(supplement.id);
    expect(loaded.purchases, isEmpty);
    expect(loaded.statusAt(today).stock, 0);
  });

  test('una toma sin cantidad descuenta la dosis diaria', () async {
    final supplement = await creatine();

    final intake = await repo.logIntake(supplement.id);

    expect((intake.amount, intake.isAdjustment), (5, false));
    expect(intake.takenAt, clock);
    expect((await view(supplement.id)).statusAt(today).stock, 295);
  });

  test('una toma puede llevar otra cantidad', () async {
    final supplement = await creatine();
    await repo.logIntake(supplement.id, amount: 2.5);
    expect((await view(supplement.id)).statusAt(today).stock, 297.5);
  });

  test('una compra nueva suma a las existencias', () async {
    final supplement = await creatine();
    await repo.addPurchase(supplement.id, quantity: 500, note: ' Bote grande ');

    final loaded = await view(supplement.id);
    expect(loaded.statusAt(today).stock, 800);
    expect(loaded.purchases.map((p) => p.note), contains('Bote grande'));
  });

  test('corregir existencias agrega un ajuste por la diferencia', () async {
    final supplement = await creatine();
    await repo.logIntake(supplement.id); // quedan 295 según la app

    await repo.adjustStock(supplement.id, actualStock: 250, now: today);

    final loaded = await view(supplement.id);
    expect(loaded.statusAt(today).stock, 250);
    final adjustment = loaded.intakes.singleWhere((i) => i.isAdjustment);
    expect(adjustment.amount, 45);
    // El ajuste no cuenta como toma: sigue habiendo una sola.
    expect(loaded.intakes.where((i) => !i.isAdjustment), hasLength(1));
  });

  test('corregir hacia arriba deja un ajuste negativo', () async {
    final supplement = await creatine();

    await repo.adjustStock(supplement.id, actualStock: 320, now: today);

    final loaded = await view(supplement.id);
    expect(loaded.statusAt(today).stock, 320);
    expect(loaded.intakes.single.amount, -20);
  });

  test('corregir al mismo valor no registra nada', () async {
    final supplement = await creatine();
    await repo.adjustStock(supplement.id, actualStock: 300, now: today);
    expect((await view(supplement.id)).intakes, isEmpty);
  });

  test('borrar una toma o una compra devuelve las existencias', () async {
    final supplement = await creatine();
    final intake = await repo.logIntake(supplement.id);
    final purchase = await repo.addPurchase(supplement.id, quantity: 100);

    await repo.deleteIntake(intake.id);
    await repo.deletePurchase(purchase.id);

    expect((await view(supplement.id)).statusAt(today).stock, 300);
  });

  test('editar el suplemento cambia dosis y aviso', () async {
    final supplement = await creatine();
    clock = clock.add(const Duration(hours: 1));

    await repo.updateSupplement(
      supplement.id,
      name: 'Creatina monohidratada',
      unitLabel: 'g',
      dailyDose: 3,
      timing: '',
      restockLeadDays: 14,
      reminderMinute: 9 * 60 + 30,
    );

    final edited = (await view(supplement.id)).supplement;
    expect((edited.name, edited.dailyDose), ('Creatina monohidratada', 3));
    expect((edited.timing, edited.restockLeadDays), (null, 14));
    expect(edited.reminderMinute, 570);
    expect(edited.updatedAt, clock);
    expect((await view(supplement.id)).statusAt(today).daysLeft, 100);
  });

  group('"Ya lo tomé" desde la notificación', () {
    final evening = DateTime(2026, 11, 16, 21);

    test('registra la dosis del día', () async {
      final supplement = await creatine();

      final logged = await repo.logIntakeIfNotTakenToday(
        supplement.id,
        now: evening,
      );

      expect(logged, isTrue);
      final intake = (await view(supplement.id)).intakes.single;
      expect((intake.amount, intake.isAdjustment), (5, false));
      expect(intake.takenAt.toLocal(), evening);
    });

    test('no cuenta dos veces si ya se tomó ese día', () async {
      final supplement = await creatine();
      await repo.logIntake(supplement.id, takenAt: DateTime(2026, 11, 16, 8));

      final logged = await repo.logIntakeIfNotTakenToday(
        supplement.id,
        now: evening,
      );

      expect(logged, isFalse);
      expect((await view(supplement.id)).intakes, hasLength(1));
    });

    test('una toma de ayer o un ajuste no cuentan como la de hoy', () async {
      final supplement = await creatine();
      await repo.logIntake(supplement.id, takenAt: DateTime(2026, 11, 15, 22));
      await repo.adjustStock(supplement.id, actualStock: 250, now: evening);

      expect(
        await repo.logIntakeIfNotTakenToday(supplement.id, now: evening),
        isTrue,
      );
    });

    test('si el suplemento se borró, no hace nada', () async {
      final supplement = await creatine();
      await repo.deleteSupplement(supplement.id);

      expect(
        await repo.logIntakeIfNotTakenToday(supplement.id, now: evening),
        isFalse,
      );
      expect(
        await repo.logIntakeIfNotTakenToday('no-existe', now: evening),
        isFalse,
      );
    });
  });

  test('poner, cambiar y quitar el recordatorio', () async {
    final supplement = await creatine();

    await repo.setReminder(supplement.id, 21 * 60);
    expect((await view(supplement.id)).supplement.reminderMinute, 1260);

    await repo.setReminder(supplement.id, null);
    expect((await view(supplement.id)).supplement.reminderMinute, isNull);

    await expectLater(
      repo.setReminder('no-existe', 600),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('borrar el suplemento borra también sus compras y tomas', () async {
    final supplement = await creatine();
    await repo.logIntake(supplement.id);

    await repo.deleteSupplement(supplement.id);

    expect(await repo.supplementsOf(userId), isEmpty);
    expect(
      (await db.select(db.supplementPurchases).get()).every(
        (p) => p.deletedAt != null,
      ),
      isTrue,
    );
    expect(
      (await db.select(db.supplementIntakes).get()).every(
        (i) => i.deletedAt != null,
      ),
      isTrue,
    );
  });

  test('lista en orden alfabético y solo los del usuario', () async {
    final other = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Hermana'));
    await repo.addSupplement(
      userId: userId,
      name: 'zinc',
      unitLabel: 'cápsulas',
      dailyDose: 1,
    );
    await creatine();
    await repo.addSupplement(
      userId: other.id,
      name: 'Hierro',
      unitLabel: 'cápsulas',
      dailyDose: 1,
    );

    final names = (await repo.supplementsOf(userId))
        .map((v) => v.supplement.name);
    expect(names, ['Creatina', 'zinc']);
  });

  test('no se puede registrar sobre un suplemento que no existe', () async {
    await expectLater(
      repo.logIntake('no-existe'),
      throwsA(isA<RecordNotFound>()),
    );
    await expectLater(
      repo.addPurchase('no-existe', quantity: 10),
      throwsA(isA<RecordNotFound>()),
    );
    await expectLater(
      repo.deleteIntake('no-existe'),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('watchSupplementsOf vuelve a emitir al registrar una toma', () async {
    final supplement = await creatine();
    final stocks = <double>[];
    final subscription = repo.watchSupplementsOf(userId).listen((views) {
      stocks.add(views.single.statusAt(today).stock);
    });
    await pumpEventQueue();
    expect(stocks, [300]);

    await repo.logIntake(supplement.id);
    await pumpEventQueue();

    expect(stocks.last, 295);
    await subscription.cancel();
  });

  group('alta desde la guía del plan', () {
    test('agrega los que faltan, sin inventario, con su dosis', () async {
      await repo.addSupplement(
        userId: userId,
        name: 'Creatina',
        unitLabel: 'g',
        dailyDose: 5,
      );

      final result = await repo.addFromGuide(userId, [
        (name: 'creatina', dose: '5 g al día', timing: null),
        (
          name: 'Inositol (Mio-Inositol)',
          dose: '2g por la mañana',
          timing: null,
        ),
        (name: 'Vitamina D3', dose: '2,000 UI', timing: 'Con el desayuno'),
      ]);

      expect(result.added, ['Inositol (Mio-Inositol)', 'Vitamina D3']);
      expect(result.existing, ['creatina']);
      final views = await repo.supplementsOf(userId);
      final inositol = views.singleWhere(
        (v) => v.supplement.name.startsWith('Inositol'),
      );
      expect(
        (inositol.supplement.unitLabel, inositol.supplement.dailyDose),
        ('g', 2.0),
      );
      expect(inositol.hasInventory, isFalse);
      final vitamin = views.singleWhere(
        (v) => v.supplement.name == 'Vitamina D3',
      );
      expect(
        (vitamin.supplement.unitLabel, vitamin.supplement.dailyDose),
        ('pastillas', 1.0),
      );
      expect(vitamin.supplement.timing, 'Con el desayuno');
    });

    test(
      'un plan nuevo que escribe distinto el nombre no lo duplica',
      () async {
        await repo.addFromGuide(userId, [
          (
            name: 'Omega-3 (Ácidos Grasos EPA y DHA)',
            dose: '2 g',
            timing: null,
          ),
          (
            name: 'Magnesio (Glicinato o Citrato)',
            dose: '200 mg',
            timing: null,
          ),
        ]);

        final result = await repo.addFromGuide(userId, [
          (name: 'Omega-3', dose: '1,000–2,000 mg al día', timing: null),
          (name: 'Creatina monohidrato', dose: '5 g por día', timing: null),
          (name: 'Magnesio', dose: '200 mg al día', timing: null),
        ]);

        expect(result.added, ['Creatina monohidrato']);
        expect(result.existing, ['Omega-3', 'Magnesio']);
        expect(await repo.supplementsOf(userId), hasLength(3));
      },
    );

    test('sin guía no agrega nada', () async {
      final result = await repo.addFromGuide(userId, const []);
      expect(result.added, isEmpty);
      expect(result.existing, isEmpty);
      expect(await repo.supplementsOf(userId), isEmpty);
    });
  });
}
