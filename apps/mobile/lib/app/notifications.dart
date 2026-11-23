import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/database.dart';
import '../data/repositories/supplement_repository.dart';
import '../domain/supplement_notifications.dart';

/// Categoría de los recordatorios de toma: la que lleva el botón.
const String reminderCategory = 'supplementReminder';

/// Identificador del botón "Ya lo tomé".
const String takenAction = 'taken';

/// Programa las notificaciones locales del teléfono.
abstract class NotificationScheduler {
  /// Pide permiso para notificar (iOS lo pregunta una sola vez; después
  /// devuelve lo que el usuario ya eligió). `true` si están permitidas.
  Future<bool> requestPermission();

  /// Borra todas las notificaciones pendientes y programa [notifications]
  /// con el sonido [soundFile] (nulo: el del sistema).
  Future<void> replaceAll(
    List<PlannedNotification> notifications, {
    String? soundFile,
  });

  /// Muestra al momento una notificación de ejemplo con ese sonido.
  Future<void> showTest({String? soundFile});
}

/// No programa nada. Es el valor por defecto, para que las pruebas no
/// dependan del sistema; `main` lo reemplaza por [LocalNotificationScheduler].
class NoopNotificationScheduler implements NotificationScheduler {
  const NoopNotificationScheduler();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> replaceAll(
    List<PlannedNotification> notifications, {
    String? soundFile,
  }) async {}

  @override
  Future<void> showTest({String? soundFile}) async {}
}

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => const NoopNotificationScheduler(),
);

/// Registra la toma cuando se pulsa "Ya lo tomé" con la app cerrada o en
/// segundo plano. iOS arranca un motor de Flutter aparte solo para esto, así
/// que abre su propia conexión a la base (compartida con la de la app si
/// esta sigue viva).
@pragma('vm:entry-point')
Future<void> handleNotificationActionInBackground(
  NotificationResponse response,
) async {
  if (response.actionId != takenAction || response.payload == null) return;
  DartPluginRegistrant.ensureInitialized();
  final db = AppDatabase();
  try {
    await SupplementRepository(db)
        .logIntakeIfNotTakenToday(response.payload!, now: DateTime.now());
  } finally {
    await db.close();
  }
}

/// Notificaciones locales con flutter_local_notifications (ADR-0014). No usa
/// ningún servidor: el teléfono las dispara solo, aunque la app esté cerrada.
class LocalNotificationScheduler implements NotificationScheduler {
  /// [onTaken] registra la toma cuando se pulsa "Ya lo tomé" con la app
  /// abierta.
  LocalNotificationScheduler({required this.onTaken});

  final Future<void> Function(String supplementId) onTaken;
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  /// Inicializa una sola vez, sin pedir permiso todavía: se pide cuando el
  /// usuario hace algo que lo necesita. Aquí se declara el botón de los
  /// recordatorios, que iOS exige registrar antes de programar.
  Future<void> _init() => _ready ??= () async {
    tz_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              reminderCategory,
              actions: [
                DarwinNotificationAction.plain(takenAction, 'Ya lo tomé'),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == takenAction && response.payload != null) {
          onTaken(response.payload!);
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          handleNotificationActionInBackground,
    );
  }();

  @override
  Future<bool> requestPermission() async {
    await _init();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> replaceAll(
    List<PlannedNotification> notifications, {
    String? soundFile,
  }) async {
    await _init();
    await _installSound(soundFile);
    await _plugin.cancelAll();
    for (final notification in notifications) {
      final isReminder = notification.kind == NotificationKind.reminder;
      await _plugin.zonedSchedule(
        id: notification.id,
        scheduledDate: tz.TZDateTime.from(notification.at, tz.local),
        title: notification.title,
        body: notification.body,
        payload: notification.supplementId,
        notificationDetails: NotificationDetails(
          android: _androidDetails(soundFile, withTakenButton: isReminder),
          iOS: DarwinNotificationDetails(
            threadIdentifier: 'suplementos',
            sound: soundFile,
            categoryIdentifier: isReminder ? reminderCategory : null,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> showTest({String? soundFile}) async {
    await _init();
    await _installSound(soundFile);
    await _plugin.show(
      // Fuera del rango de las programadas, para no reemplazar ninguna.
      id: 9999,
      title: 'Así sonarán tus recordatorios',
      body: 'Desliza hacia abajo para ver el botón "Ya lo tomé".',
      notificationDetails: NotificationDetails(
        android: _androidDetails(soundFile, withTakenButton: true),
        iOS: DarwinNotificationDetails(
          sound: soundFile,
          categoryIdentifier: reminderCategory,
        ),
      ),
    );
  }

  /// En Android el sonido es del canal y no se puede cambiar después de
  /// crearlo: por eso hay un canal por sonido. Los archivos están en
  /// `res/raw` como WAV, con el mismo nombre que los de iOS (ADR-0024).
  static AndroidNotificationDetails _androidDetails(
    String? soundFile, {
    required bool withTakenButton,
  }) {
    final sound = soundFile?.replaceFirst(RegExp(r'\.\w+$'), '');
    return AndroidNotificationDetails(
      'suplementos_${sound ?? 'sistema'}',
      'Suplementos',
      channelDescription: 'Recordatorios de toma y avisos de reabastecer.',
      importance: Importance.high,
      priority: Priority.high,
      sound: sound == null ? null : RawResourceAndroidNotificationSound(sound),
      actions: [
        if (withTakenButton)
          const AndroidNotificationAction(
            takenAction,
            'Ya lo tomé',
            // Registra la toma sin abrir la app y quita el aviso.
            showsUserInterface: false,
            cancelNotification: true,
          ),
      ],
    );
  }

  /// iOS busca los sonidos en la carpeta Library/Sounds de la app. Se copian
  /// ahí desde los recursos la primera vez, en vez de agregarlos al proyecto
  /// de Xcode. Android los toma de `res/raw`.
  Future<void> _installSound(String? soundFile) async {
    if (soundFile == null || !Platform.isIOS) return;
    final library = await getLibraryDirectory();
    final target = File('${library.path}/Sounds/$soundFile');
    if (target.existsSync()) return;
    final data = await rootBundle.load('assets/sounds/$soundFile');
    await target.create(recursive: true);
    await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
  }
}
