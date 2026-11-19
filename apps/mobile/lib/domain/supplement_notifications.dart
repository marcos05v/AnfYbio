import 'supplement_inventory.dart';

/// Hora del aviso de reabastecimiento.
const int restockAlertHour = 9;

/// Días hacia adelante que se programan los recordatorios de toma.
const int reminderHorizonDays = 7;

/// iOS solo guarda 64 notificaciones pendientes por app; se deja margen.
const int maxPendingNotifications = 60;

/// Lo que hace falta de un suplemento para planear sus notificaciones.
class SupplementForNotifications {
  const SupplementForNotifications({
    required this.id,
    required this.name,
    required this.doseLabel,
    required this.status,
    this.timing,
    this.reminderMinute,
  });

  final String id;

  /// Nombre corto, para el título.
  final String name;

  /// Dosis ya escrita: "5 g", "1 pastillas".
  final String doseLabel;
  final String? timing;

  /// Minutos desde la medianoche; nulo si no hay recordatorio.
  final int? reminderMinute;
  final InventoryStatus status;
}

enum NotificationKind { reminder, restock }

/// Una notificación local que hay que programar.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.supplementId,
    required this.at,
    required this.title,
    required this.body,
    required this.kind,
  });

  final int id;

  /// El suplemento al que se refiere: el botón "Ya lo tomé" registra la toma
  /// de este suplemento.
  final String supplementId;

  /// Momento en hora local.
  final DateTime at;
  final String title;
  final String body;
  final NotificationKind kind;

  @override
  String toString() => '$kind ${at.toIso8601String()} "$title"';
}

/// Todas las notificaciones que deben quedar programadas a partir de [now]
/// (hora local). La app borra las pendientes y programa esta lista cada vez
/// que cambia el inventario o se abre, así que basta con mirar unos días
/// adelante (ADR-0014).
///
/// - **Recordatorio de toma**: uno por día a la hora elegida, durante los
///   próximos días; hoy no, si ya se tomó o la hora ya pasó. Sin existencias
///   no se recuerda tomar.
/// - **Reabastecimiento**: a las 9:00 del día en que quedan los días de aviso
///   configurados. Si ya se está dentro de ese plazo, a las 9:00 siguientes:
///   como se reprograma al abrir la app, avisa cada mañana hasta reabastecer.
List<PlannedNotification> planSupplementNotifications({
  required List<SupplementForNotifications> supplements,
  required DateTime now,
  required int Function(SupplementForNotifications) restockLeadDays,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final withReminder = supplements.where((s) => s.reminderMinute != null);

  // Con muchos suplementos se acortan los días para no pasar del límite.
  final reminderDays = withReminder.isEmpty
      ? 0
      : ((maxPendingNotifications - supplements.length) ~/ withReminder.length)
            .clamp(1, reminderHorizonDays);

  final planned =
      <
        ({
          String supplementId,
          DateTime at,
          String title,
          String body,
          NotificationKind kind,
        })
      >[];

  for (final supplement in supplements) {
    final status = supplement.status;

    if (supplement.reminderMinute case final minute? when status.stock > 0) {
      for (var day = 0; day < reminderDays; day++) {
        final at = today.add(Duration(days: day, minutes: minute));
        if (!at.isAfter(now)) continue;
        if (day == 0 && status.takenToday) continue;
        planned.add((
          supplementId: supplement.id,
          at: at,
          title: 'Toma tu ${supplement.name}',
          body: [supplement.doseLabel, ?supplement.timing].join(' · '),
          kind: NotificationKind.reminder,
        ));
      }
    }

    final runOut = status.runOutDate;
    final alertDay = status.needsRestock || runOut == null
        ? null
        : runOut.subtract(Duration(days: restockLeadDays(supplement)));
    DateTime nextMorning() {
      final todayAt = today.add(const Duration(hours: restockAlertHour));
      return todayAt.isAfter(now)
          ? todayAt
          : todayAt.add(const Duration(days: 1));
    }

    final alertAt = alertDay == null
        ? nextMorning()
        : DateTime(
            alertDay.year,
            alertDay.month,
            alertDay.day,
            restockAlertHour,
          );
    // Lo que quedará el día del aviso: los días de anticipación si es a
    // futuro, o lo que queda hoy si ya se está dentro del plazo.
    final daysThen = alertDay == null
        ? status.daysLeft
        : restockLeadDays(supplement);
    planned.add((
      supplementId: supplement.id,
      at: alertAt.isAfter(now) ? alertAt : nextMorning(),
      title: 'Reabastece tu ${supplement.name}',
      body: status.stock <= 0
          ? 'Ya no te queda.'
          : daysThen == 0
          ? 'Se acaba hoy.'
          : daysThen == 1
          ? 'Te alcanza para 1 día más.'
          : 'Te alcanza para $daysThen días más.',
      kind: NotificationKind.restock,
    ));
  }

  planned.sort((a, b) => a.at.compareTo(b.at));
  return [
    for (final (index, p) in planned.take(maxPendingNotifications).indexed)
      PlannedNotification(
        id: index,
        supplementId: p.supplementId,
        at: p.at,
        title: p.title,
        body: p.body,
        kind: p.kind,
      ),
  ];
}
