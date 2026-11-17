import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
