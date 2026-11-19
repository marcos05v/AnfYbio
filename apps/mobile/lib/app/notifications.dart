import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/supplement_notifications.dart';

/// Programa las notificaciones locales del teléfono.
abstract class NotificationScheduler {
  /// Pide permiso para notificar (iOS lo pregunta una sola vez; después
  /// devuelve lo que el usuario ya eligió). `true` si están permitidas.
  Future<bool> requestPermission();

  /// Borra todas las notificaciones pendientes y programa [notifications].
  Future<void> replaceAll(List<PlannedNotification> notifications);
}

/// No programa nada. Es el valor por defecto, para que las pruebas no
/// dependan del sistema; `main` lo reemplaza por [LocalNotificationScheduler].
class NoopNotificationScheduler implements NotificationScheduler {
  const NoopNotificationScheduler();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> replaceAll(List<PlannedNotification> notifications) async {}
}

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => const NoopNotificationScheduler(),
);

/// Notificaciones locales con flutter_local_notifications (ADR-0014). No usa
/// ningún servidor: el teléfono las dispara solo, aunque la app esté cerrada.
class LocalNotificationScheduler implements NotificationScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  /// Inicializa una sola vez, sin pedir permiso todavía: se pide cuando el
  /// usuario hace algo que lo necesita.
  Future<void> _init() => _ready ??= () async {
    tz_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }();

  @override
  Future<bool> requestPermission() async {
    await _init();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> replaceAll(List<PlannedNotification> notifications) async {
    await _init();
    await _plugin.cancelAll();
    for (final notification in notifications) {
      await _plugin.zonedSchedule(
        id: notification.id,
        scheduledDate: tz.TZDateTime.from(notification.at, tz.local),
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(threadIdentifier: 'suplementos'),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
