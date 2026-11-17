import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/nutrition.dart';

/// Apariencia de la app: seguir al sistema, o forzar claro u oscuro.
enum AppAppearance { system, light, dark }

/// Preferencias del dispositivo. Se inicializa en `main` antes de arrancar.
///
/// La apariencia es una preferencia de este teléfono, no un dato del usuario:
/// por eso vive aquí y no en la base de datos, y no se sincronizará.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Se reemplaza en main() y en las pruebas.'),
);

class AppearanceController extends Notifier<AppAppearance> {
  static const _key = 'appearance';

  @override
  AppAppearance build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_key);
    return AppAppearance.values.firstWhere(
      (a) => a.name == saved,
      orElse: () => AppAppearance.system,
    );
  }

  Future<void> select(AppAppearance appearance) async {
    state = appearance;
    await ref.read(sharedPreferencesProvider).setString(_key, appearance.name);
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceController, AppAppearance>(
      AppearanceController.new,
    );

/// Elección manual del tipo de día (entrenamiento o descanso) para **hoy**.
///
/// Se guarda junto con la fecha: al día siguiente deja de aplicar y la app
/// vuelve a decidirlo sola según haya o no una sesión registrada.
class DayTypeOverrideController extends Notifier<DayType?> {
  static const _key = 'dayTypeOverride';

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  @override
  DayType? build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_key);
    if (saved == null) return null;
    final [date, name] = saved.split(':');
    if (date != _today()) return null;
    return DayType.values.where((t) => t.name == name).firstOrNull;
  }

  /// Con `null` se vuelve a la detección automática.
  Future<void> select(DayType? dayType) async {
    state = dayType;
    final preferences = ref.read(sharedPreferencesProvider);
    if (dayType == null) {
      await preferences.remove(_key);
    } else {
      await preferences.setString(_key, '${_today()}:${dayType.name}');
    }
  }
}

final dayTypeOverrideProvider =
    NotifierProvider<DayTypeOverrideController, DayType?>(
      DayTypeOverrideController.new,
    );
