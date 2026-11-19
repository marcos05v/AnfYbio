import 'package:anfybio/app/appearance.dart';
import 'package:anfybio/app/notifications.dart';
import 'package:anfybio/app/providers.dart';
import 'package:anfybio/data/database.dart';
import 'package:anfybio/data/repositories/nutrition_repository.dart';
import 'package:anfybio/data/repositories/supplement_repository.dart';
import 'package:anfybio/domain/nutrition.dart';
import 'package:anfybio/domain/supplement_notifications.dart';
import 'package:anfybio/ui/app.dart';
import 'package:anfybio/ui/supplement_forms.dart';
import 'package:anfybio/ui/widgets.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registra lo que la app pediría programar, en lugar de usar el sistema.
class FakeScheduler implements NotificationScheduler {
  FakeScheduler({this.allowed = true});

  final bool allowed;
  int permissionRequests = 0;
  List<PlannedNotification> scheduled = const [];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }

  @override
  Future<void> replaceAll(List<PlannedNotification> notifications) async =>
      scheduled = notifications;
}

void main() {
  late AppDatabase db;
  late SharedPreferences preferences;
  late String userId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    final user = await db
        .into(db.users)
        .insertReturning(UsersCompanion.insert(displayName: 'Ana'));
    userId = user.id;
  });

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(Key(key)), text);
    await tester.pumpAndSettle();
  }

  Future<void> openSupplements(
    WidgetTester tester, {
    NotificationScheduler scheduler = const NoopNotificationScheduler(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(preferences),
          notificationSchedulerProvider.overrideWithValue(scheduler),
        ],
        child: const AnfybioApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Suplementos'));
  }

  Future<void> shutDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  /// Creatina: 5 g al día, con las existencias indicadas.
  Future<Supplement> creatine({double stock = 300, int lead = 7}) =>
      SupplementRepository(db).addSupplement(
        userId: userId,
        name: 'Creatina',
        unitLabel: 'g',
        dailyDose: 5,
        restockLeadDays: lead,
        initialQuantity: stock,
      );

  /// Un plan cuya guía trae dos suplementos.
  Future<void> planWithGuide() => NutritionRepository(db).savePlan(
    userId,
    const NutritionPlanDraft(
      name: 'Plan',
      supplements: [
        SupplementDraft(
          name: 'Creatina Monohidratada',
          dose: '5 g al día',
          timing: 'Con el post-entreno',
        ),
        SupplementDraft(name: 'Vitamina D3', dose: '2,000 Ul'),
      ],
    ),
  );

  testWidgets('sin suplementos ni plan, ofrece agregar uno', (tester) async {
    await openSupplements(tester);

    expect(find.text('Sin suplementos todavía'), findsOneWidget);
    expect(find.text('Agregar suplemento'), findsOneWidget);
    expect(find.text('Agregar desde mi plan'), findsNothing);
    await shutDown(tester);
  });

  testWidgets(
    'da de alta un suplemento con lo que tiene y calcula su duración',
    (tester) async {
      await openSupplements(tester);

      await tap(tester, find.text('Agregar suplemento'));
      await type(tester, 'supName', 'Creatina');
      await tap(tester, find.text('Polvo'));
      await type(tester, 'supDose', '5');
      await type(tester, 'supContent', '300');
      expect(
        tester.widget<Text>(find.byKey(const Key('supEstimate'))).data,
        'Empiezas con 300 g: alcanza 60 días.',
      );
      await tap(tester, find.text('Guardar suplemento'));

      expect(find.text('Creatina'), findsOneWidget);
      expect(find.text('Quedan 300 g · alcanza 60 días'), findsOneWidget);
      expect(find.textContaining('Se acaba el'), findsOneWidget);
      expect(find.text('Hay que reabastecer'), findsNothing);
      await shutDown(tester);
    },
  );

  testWidgets('desde la guía del plan propone dosis, unidad y momento', (
    tester,
  ) async {
    await planWithGuide();
    await openSupplements(tester);

    await tap(tester, find.text('Agregar desde mi plan'));
    expect(find.text('De la guía de tu plan'), findsOneWidget);
    await tap(tester, find.text('Vitamina D3'));

    // La guía dice "2,000 Ul": es la concentración de cada pastilla, así
    // que se propone llevarlo en pastillas, una al día.
    final dose = tester.widget<RowTextField>(find.byKey(const Key('supDose')));
    expect(dose.controller.text, '1');
    expect(find.text('Pastillas al día'), findsOneWidget);
    expect(find.byKey(const Key('supUnit')), findsNothing);

    await type(tester, 'supContent', '60');
    await tap(tester, find.text('Guardar suplemento'));
    expect(find.text('Quedan 60 pastillas · alcanza 60 días'), findsOneWidget);
    // El otro suplemento de la guía sigue disponible para agregar.
    expect(find.text('Agregar desde mi plan'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('de la guía, un polvo se propone en gramos con su dosis', (
    tester,
  ) async {
    await planWithGuide();
    await openSupplements(tester);

    await tap(tester, find.text('Agregar desde mi plan'));
    await tap(tester, find.text('Creatina Monohidratada'));

    final dose = tester.widget<RowTextField>(find.byKey(const Key('supDose')));
    expect(dose.controller.text, '5');
    expect(find.text('Gramos al día'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('el contenido de un polvo se puede escribir en kilos', (
    tester,
  ) async {
    await openSupplements(tester);
    await tap(tester, find.text('Agregar suplemento'));
    await type(tester, 'supName', 'Creatina');
    await tap(tester, find.text('Polvo'));
    await type(tester, 'supDose', '5');
    await type(tester, 'supContent', '1');
    await tap(tester, find.text('kg'));
    await tap(tester, find.text('Guardar suplemento'));

    expect(find.text('Quedan 1000 g · alcanza 200 días'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('otra presentación pide en qué se mide', (tester) async {
    await openSupplements(tester);
    await tap(tester, find.text('Agregar suplemento'));
    await type(tester, 'supName', 'Vitamina B12');
    await tap(tester, find.text('Otra'));
    await type(tester, 'supDose', '2');
    await type(tester, 'supContent', '60');
    await tap(tester, find.text('Guardar suplemento'));
    expect(find.textContaining('en qué se mide'), findsOneWidget);

    await type(tester, 'supUnit', 'ml');
    await tap(tester, find.text('Guardar suplemento'));
    expect(find.text('Quedan 60 ml · alcanza 30 días'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('un envase ya empezado estima lo que queda desde la compra', (
    tester,
  ) async {
    SupplementDraftData? saved;
    final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SafeArea(
            child: SingleChildScrollView(
              child: SupplementForm(
                initialPurchaseDate: tenDaysAgo,
                onSave: (data) async => saved = data,
              ),
            ),
          ),
        ),
      ),
    );
    await type(tester, 'supName', 'Zinc');
    await type(tester, 'supDose', '1');
    await type(tester, 'supContent', '60');

    // Sin marcar "ya lo empecé", se parte del envase completo.
    String estimate() =>
        tester.widget<Text>(find.byKey(const Key('supEstimate'))).data!;
    expect(estimate(), 'Empiezas con 60 pastillas: alcanza 60 días.');

    await tap(tester, find.byKey(const Key('supStarted')));
    expect(
      estimate(),
      contains('llevas 10 pastillas y te quedan 50 pastillas'),
    );

    await tap(tester, find.text('Guardar suplemento'));
    expect(saved!.unitLabel, 'pastillas');
    expect((saved!.initialQuantity, saved!.alreadyConsumed), (60, 10));
    expect(saved!.purchasedAt!.day, tenDaysAgo.day);
  });

  testWidgets('sin envase, el suplemento empieza sin existencias', (
    tester,
  ) async {
    await openSupplements(tester);
    await tap(tester, find.text('Agregar suplemento'));
    await type(tester, 'supName', 'Zinc');
    await type(tester, 'supDose', '1');
    await tap(tester, find.text('Guardar suplemento'));

    expect(find.text('Sin existencias'), findsOneWidget);
    expect(await db.select(db.supplementPurchases).get(), isEmpty);
    await shutDown(tester);
  });

  testWidgets('"Tomar" descuenta la dosis y marca el día como tomado', (
    tester,
  ) async {
    await creatine();
    await openSupplements(tester);

    await tap(tester, find.byKey(const Key('take-Creatina')));

    expect(find.text('Tomado'), findsOneWidget);
    expect(find.text('Quedan 295 g · alcanza 59 días'), findsOneWidget);
    expect(find.byKey(const Key('take-Creatina')), findsNothing);
    await shutDown(tester);
  });

  testWidgets('avisa cuando hay que reabastecer', (tester) async {
    await creatine(stock: 30); // 6 días, con aviso a 7
    await openSupplements(tester);

    expect(find.text('Hay que reabastecer'), findsOneWidget);
    expect(find.text('Creatina: alcanza 6 días'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('la anticipación del aviso es configurable', (tester) async {
    await creatine(stock: 30, lead: 3); // 6 días, con aviso a 3
    await openSupplements(tester);

    expect(find.text('Hay que reabastecer'), findsNothing);
    await shutDown(tester);
  });

  testWidgets('sin existencias lo indica en la tarjeta y en el aviso', (
    tester,
  ) async {
    await SupplementRepository(db).addSupplement(
      userId: userId,
      name: 'Zinc',
      unitLabel: 'cápsulas',
      dailyDose: 1,
    );
    await openSupplements(tester);

    expect(find.text('Sin existencias'), findsOneWidget);
    expect(find.text('Zinc: sin existencias'), findsOneWidget);
    await shutDown(tester);
  });

  group('detalle', () {
    testWidgets('muestra existencias, duración y adherencia', (tester) async {
      final supplement = await creatine();
      await SupplementRepository(db).logIntake(supplement.id);
      await openSupplements(tester);

      await tap(tester, find.text('Creatina'));

      expect(find.text('295 g'), findsOneWidget);
      expect(find.text('59 días'), findsOneWidget);
      expect(find.text('100 %'), findsOneWidget); // 1 día, 1 toma
      expect(
        find.textContaining('Predicción con la dosis indicada'),
        findsOneWidget,
      );
      expect(find.text('Toma'), findsOneWidget);
      expect(find.text('Compra'), findsOneWidget);
      expect(find.text('+300 g'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('registrar una compra suma existencias', (tester) async {
      await creatine(stock: 30);
      await openSupplements(tester);
      await tap(tester, find.text('Creatina'));

      await tap(tester, find.text('Registrar compra'));
      await type(tester, 'quantity', '500');
      await type(tester, 'quantityNote', 'Bote grande');
      await tap(tester, find.text('Guardar compra'));

      expect(find.text('530 g'), findsOneWidget);
      expect(find.text('Compra · Bote grande'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('una compra de polvo se puede registrar en kilos', (
      tester,
    ) async {
      await creatine(stock: 30);
      await openSupplements(tester);
      await tap(tester, find.text('Creatina'));

      await tap(tester, find.text('Registrar compra'));
      await type(tester, 'quantity', '0,5');
      await tap(tester, find.text('kg'));
      await tap(tester, find.text('Guardar compra'));

      expect(find.text('530 g'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('corregir existencias deja un ajuste que no cuenta como toma', (
      tester,
    ) async {
      await creatine();
      await openSupplements(tester);
      await tap(tester, find.text('Creatina'));

      await tap(tester, find.text('Corregir existencias'));
      await type(tester, 'quantity', '250');
      await tap(tester, find.text('Guardar'));

      expect(find.text('250 g'), findsOneWidget);
      expect(find.text('Ajuste de existencias'), findsOneWidget);
      expect(
        find.text('Registrar toma de hoy'),
        findsOneWidget,
      ); // sigue sin tomar
      await shutDown(tester);
    });

    testWidgets('registrar la toma de hoy desde el detalle', (tester) async {
      await creatine();
      await openSupplements(tester);
      await tap(tester, find.text('Creatina'));

      await tap(tester, find.text('Registrar toma de hoy'));

      expect(find.text('295 g'), findsOneWidget);
      expect(find.text('Registrar otra toma'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('borrar un movimiento recalcula las existencias', (
      tester,
    ) async {
      final supplement = await creatine();
      await SupplementRepository(db).logIntake(supplement.id);
      await openSupplements(tester);
      await tap(tester, find.text('Creatina'));
      expect(find.text('295 g'), findsOneWidget);

      await tap(tester, find.text('Toma'));
      await tap(tester, find.text('Borrar'));

      expect(find.text('300 g'), findsOneWidget);
      expect(find.text('Toma'), findsNothing);
      await shutDown(tester);
    });

    testWidgets('editar la dosis cambia cuánto dura', (tester) async {
      await creatine();
      await openSupplements(tester);
      await tap(tester, find.text('Creatina'));

      await tap(tester, find.text('Editar'));
      await type(tester, 'supDose', '10');
      await tap(tester, find.text('Guardar cambios'));

      expect(find.text('30 días'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('borrar el suplemento vuelve a la lista vacía', (tester) async {
      await creatine();
      await openSupplements(tester);
      await tap(tester, find.text('Creatina'));

      await tap(tester, find.text('Editar'));
      await tap(tester, find.byIcon(CupertinoIcons.trash));
      await tap(tester, find.text('Borrar'));

      expect(find.text('Sin suplementos todavía'), findsOneWidget);
      await shutDown(tester);
    });
  });

  testWidgets('un suplemento sin dosis no se guarda', (tester) async {
    await openSupplements(tester);
    await tap(tester, find.text('Agregar suplemento'));
    await type(tester, 'supName', 'Zinc');
    await tap(tester, find.text('Guardar suplemento'));

    expect(find.textContaining('cuánto tomas al día'), findsOneWidget);
    expect(await db.select(db.supplements).get(), isEmpty);
    await shutDown(tester);
  });

  group('notificaciones', () {
    testWidgets('cada suplemento con existencias tiene su aviso de reabasto', (
      tester,
    ) async {
      await creatine();
      final scheduler = FakeScheduler();
      await openSupplements(tester, scheduler: scheduler);

      final restock = scheduler.scheduled.single;
      expect(restock.kind, NotificationKind.restock);
      expect(restock.title, 'Reabastece tu Creatina');
      expect(restock.body, 'Te alcanza para 7 días más.');
      await shutDown(tester);
    });

    testWidgets('activar el recordatorio pide permiso y programa la semana', (
      tester,
    ) async {
      await creatine();
      final scheduler = FakeScheduler();
      await openSupplements(tester, scheduler: scheduler);
      await tap(tester, find.text('Creatina'));
      expect(find.text('Sin recordatorio'), findsOneWidget);

      await tap(tester, find.text('Editar'));
      await tap(tester, find.byKey(const Key('supReminder')));
      expect(scheduler.permissionRequests, 1);
      expect(find.text('9:00 a. m.'), findsOneWidget); // hora propuesta
      await tap(tester, find.text('Guardar cambios'));

      // La tarjeta del detalle muestra la hora en grande.
      expect(find.text('RECORDATORIO DIARIO'), findsOneWidget);
      expect(find.text('9:00'), findsOneWidget);
      expect(find.text('a. m.'), findsOneWidget);
      final reminders = scheduler.scheduled.where(
        (n) => n.kind == NotificationKind.reminder,
      );
      expect(reminders.length, inInclusiveRange(6, 7)); // hoy, si aún no pasa
      expect(reminders.first.title, 'Toma tu Creatina');
      expect(reminders.first.body, '5 g');
      expect(reminders.every((n) => n.at.hour == 9), isTrue);
      await shutDown(tester);
    });

    testWidgets('si las notificaciones están desactivadas, lo explica', (
      tester,
    ) async {
      await creatine();
      await openSupplements(tester, scheduler: FakeScheduler(allowed: false));
      await tap(tester, find.text('Creatina'));
      await tap(tester, find.text('Editar'));

      await tap(tester, find.byKey(const Key('supReminder')));

      expect(
        find.textContaining('Las notificaciones están desactivadas'),
        findsOneWidget,
      );
      await shutDown(tester);
    });

    testWidgets('apagar el recordatorio deja de programarlo', (tester) async {
      await SupplementRepository(db).addSupplement(
        userId: userId,
        name: 'Zinc',
        unitLabel: 'pastillas',
        dailyDose: 1,
        reminderMinute: 21 * 60,
        initialQuantity: 60,
      );
      final scheduler = FakeScheduler();
      await openSupplements(tester, scheduler: scheduler);
      expect(
        scheduler.scheduled.where((n) => n.kind == NotificationKind.reminder),
        isNotEmpty,
      );

      await tap(tester, find.text('Zinc'));
      await tap(tester, find.text('Editar'));
      await tap(tester, find.byKey(const Key('supReminder')));
      await tap(tester, find.text('Guardar cambios'));

      expect(
        scheduler.scheduled.where((n) => n.kind == NotificationKind.reminder),
        isEmpty,
      );
      expect(find.text('Sin recordatorio'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('dar de alta el primer suplemento pide permiso', (
      tester,
    ) async {
      final scheduler = FakeScheduler();
      await openSupplements(tester, scheduler: scheduler);
      await tap(tester, find.text('Agregar suplemento'));
      await type(tester, 'supName', 'Zinc');
      await type(tester, 'supDose', '1');
      await tap(tester, find.text('Guardar suplemento'));

      expect(scheduler.permissionRequests, 1);
      await shutDown(tester);
    });

    testWidgets(
      'la campana del detalle pone el recordatorio con confirmación',
      (tester) async {
        await creatine();
        final scheduler = FakeScheduler();
        await openSupplements(tester, scheduler: scheduler);
        await tap(tester, find.text('Creatina'));

        await tap(tester, find.byKey(const Key('reminderBell')));
        expect(find.text('Recordatorio diario'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('reminderClock'))).data,
          '9:00',
        );
        // Sin confirmar no se guarda nada.
        expect(
          (await db.select(db.supplements).getSingle()).reminderMinute,
          isNull,
        );

        await tap(tester, find.text('Poner recordatorio'));

        expect(scheduler.permissionRequests, 1);
        expect(
          (await db.select(db.supplements).getSingle()).reminderMinute,
          540,
        );
        expect(find.text('RECORDATORIO DIARIO'), findsOneWidget);
        expect(
          scheduler.scheduled.where((n) => n.kind == NotificationKind.reminder),
          isNotEmpty,
        );
        await shutDown(tester);
      },
    );

    testWidgets('desde la campana también se quita el recordatorio', (
      tester,
    ) async {
      await SupplementRepository(db).addSupplement(
        userId: userId,
        name: 'Zinc',
        unitLabel: 'pastillas',
        dailyDose: 1,
        reminderMinute: 21 * 60 + 30,
        initialQuantity: 60,
      );
      await openSupplements(tester, scheduler: FakeScheduler());
      // La lista muestra la hora con la campana.
      expect(find.text('9:30 p. m.'), findsOneWidget);
      await tap(tester, find.text('Zinc'));

      await tap(tester, find.byKey(const Key('reminderCard')));
      expect(find.text('Guardar recordatorio'), findsOneWidget);
      await tap(tester, find.byIcon(CupertinoIcons.trash));
      await tap(tester, find.text('Borrar'));

      expect(find.text('Sin recordatorio'), findsOneWidget);
      expect(
        (await db.select(db.supplements).getSingle()).reminderMinute,
        isNull,
      );
      await shutDown(tester);
    });

    testWidgets('sin permiso, la campana explica y no guarda', (tester) async {
      await creatine();
      await openSupplements(tester, scheduler: FakeScheduler(allowed: false));
      await tap(tester, find.text('Creatina'));

      await tap(tester, find.byKey(const Key('reminderBell')));
      await tap(tester, find.text('Poner recordatorio'));

      expect(
        find.textContaining('Las notificaciones están desactivadas'),
        findsOneWidget,
      );
      expect(
        (await db.select(db.supplements).getSingle()).reminderMinute,
        isNull,
      );
      await shutDown(tester);
    });
  });
}
