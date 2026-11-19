import 'package:anfybio/domain/supplement_inventory.dart';
import 'package:anfybio/domain/supplement_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Lunes 16 de noviembre de 2026, 8:00.
  final now = DateTime(2026, 11, 16, 8);

  InventoryStatus status({
    double stock = 300,
    int daysLeft = 60,
    bool needsRestock = false,
    bool takenToday = false,
  }) => InventoryStatus(
    stock: stock,
    dailyRate: 5,
    usesActualRate: false,
    daysLeft: daysLeft,
    runOutDate: stock <= 0
        ? null
        : DateTime(now.year, now.month, now.day + daysLeft),
    needsRestock: needsRestock,
    adherence: null,
    takenToday: takenToday,
  );

  SupplementForNotifications supplement({
    String name = 'Creatina',
    int? reminderMinute,
    InventoryStatus? inventory,
    String? timing,
  }) => SupplementForNotifications(
    id: 'id-$name',
    name: name,
    doseLabel: '5 g',
    timing: timing,
    reminderMinute: reminderMinute,
    status: inventory ?? status(),
  );

  List<PlannedNotification> plan(
    List<SupplementForNotifications> supplements, {
    int leadDays = 7,
    DateTime? at,
  }) => planSupplementNotifications(
    supplements: supplements,
    now: at ?? now,
    restockLeadDays: (_) => leadDays,
  );

  List<PlannedNotification> reminders(List<PlannedNotification> all) =>
      all.where((n) => n.kind == NotificationKind.reminder).toList();
  List<PlannedNotification> restocks(List<PlannedNotification> all) =>
      all.where((n) => n.kind == NotificationKind.restock).toList();

  group('recordatorio de toma', () {
    test('uno al día a la hora elegida, durante la próxima semana', () {
      final result = reminders(plan([supplement(reminderMinute: 9 * 60 + 30)]));

      expect(result, hasLength(7));
      expect(result.first.at, DateTime(2026, 11, 16, 9, 30));
      expect(result.last.at, DateTime(2026, 11, 22, 9, 30));
      expect(result.first.title, 'Toma tu Creatina');
    });

    test('cada notificación sabe de qué suplemento es', () {
      final result = plan([
        supplement(name: 'Zinc', reminderMinute: 600),
        supplement(name: 'Creatina'),
      ]);
      expect(
        result.where((n) => n.supplementId == 'id-Zinc').map((n) => n.kind),
        containsAll([NotificationKind.reminder, NotificationKind.restock]),
      );
      expect(
        result.where((n) => n.supplementId == 'id-Creatina').single.kind,
        NotificationKind.restock,
      );
    });

    test('el cuerpo lleva la dosis y cuándo tomarlo', () {
      final result = reminders(
        plan([supplement(reminderMinute: 600, timing: 'Con el post-entreno')]),
      );
      expect(result.first.body, '5 g · Con el post-entreno');
    });

    test('si la hora de hoy ya pasó, empieza mañana', () {
      final result = reminders(plan([supplement(reminderMinute: 7 * 60)]));
      expect(result.first.at, DateTime(2026, 11, 17, 7));
      expect(result, hasLength(6));
    });

    test('si ya se tomó hoy, no recuerda hoy', () {
      final result = reminders(
        plan([
          supplement(
            reminderMinute: 20 * 60,
            inventory: status(takenToday: true),
          ),
        ]),
      );
      expect(result.first.at, DateTime(2026, 11, 17, 20));
    });

    test('sin hora elegida no hay recordatorios', () {
      expect(reminders(plan([supplement()])), isEmpty);
    });

    test('sin existencias no recuerda tomarlo', () {
      final result = reminders(
        plan([
          supplement(
            reminderMinute: 600,
            inventory: status(stock: 0, daysLeft: 0, needsRestock: true),
          ),
        ]),
      );
      expect(result, isEmpty);
    });
  });

  group('aviso de reabastecimiento', () {
    test('a las 9:00 del día en que quedan los días de aviso', () {
      // Alcanza 60 días; con aviso a 7 → dentro de 53 días.
      final result = restocks(plan([supplement()]));

      expect(result.single.at, DateTime(2027, 1, 8, 9));
      expect(result.single.title, 'Reabastece tu Creatina');
      expect(result.single.body, 'Te alcanza para 7 días más.');
    });

    test('la anticipación es la de cada suplemento', () {
      final result = restocks(plan([supplement()], leadDays: 14));
      expect(result.single.at, DateTime(2027, 1, 1, 9));
    });

    test('si ya hay que reabastecer, avisa la mañana siguiente', () {
      final inventory = status(stock: 20, daysLeft: 4, needsRestock: true);

      // Antes de las 9: hoy a las 9.
      expect(
        restocks(plan([supplement(inventory: inventory)])).single.at,
        DateTime(2026, 11, 16, 9),
      );
      // Después de las 9: mañana a las 9.
      expect(
        restocks(
          plan([
            supplement(inventory: inventory),
          ], at: DateTime(2026, 11, 16, 15)),
        ).single.at,
        DateTime(2026, 11, 17, 9),
      );
    });

    test('sin existencias dice que ya no queda', () {
      final result = restocks(
        plan([
          supplement(
            inventory: status(stock: 0, daysLeft: 0, needsRestock: true),
          ),
        ]),
      );
      expect(result.single.body, 'Ya no te queda.');
    });
  });

  group('en conjunto', () {
    test('ordenadas por hora y con identificadores consecutivos', () {
      final result = plan([
        supplement(name: 'Zinc', reminderMinute: 21 * 60),
        supplement(name: 'Creatina', reminderMinute: 10 * 60),
      ]);

      expect(result.map((n) => n.id), List.generate(result.length, (i) => i));
      for (var i = 1; i < result.length; i++) {
        expect(result[i].at.isBefore(result[i - 1].at), isFalse);
      }
      expect(result.first.title, 'Toma tu Creatina');
    });

    test('con muchos suplementos nunca pasa del límite de iOS', () {
      final many = [
        for (var i = 0; i < 12; i++)
          supplement(name: 'S$i', reminderMinute: 600 + i),
      ];

      final result = plan(many);

      expect(result.length, lessThanOrEqualTo(maxPendingNotifications));
      // Cada suplemento conserva su aviso de reabastecimiento.
      expect(restocks(result), hasLength(12));
      // Se acortan los días de recordatorio: (60 − 12) ÷ 12 = 4.
      expect(reminders(result), hasLength(48));
    });

    test('sin suplementos no hay nada que programar', () {
      expect(plan([]), isEmpty);
    });
  });
}
