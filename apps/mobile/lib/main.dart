import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/appearance.dart';
import 'app/notifications.dart';
import 'app/providers.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();

  // El programador necesita la base de la app para registrar "Ya lo tomé"
  // con la app abierta, y la base vive en el contenedor de proveedores.
  late final ProviderContainer container;
  final scheduler = LocalNotificationScheduler(
    onTaken: (supplementId) => container
        .read(supplementRepositoryProvider)
        .logIntakeIfNotTakenToday(supplementId, now: DateTime.now()),
  );
  container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      notificationSchedulerProvider.overrideWithValue(scheduler),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const AnfybioApp()),
  );
}
