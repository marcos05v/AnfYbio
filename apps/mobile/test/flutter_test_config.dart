import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Configuración común a todas las pruebas.
///
/// Las pruebas de interfaz corren en una pantalla más alta que la ventana de
/// 800×600 que usa Flutter por defecto, para que las listas largas queden a
/// la vista sin tener que desplazarlas.
///
/// El ancho se deja en 800 a propósito: la fuente de las pruebas dibuja cada
/// letra como un cuadrado, mucho más ancha que la real, y con el ancho de un
/// teléfono daría desbordes que en el dispositivo no existen. El aspecto real
/// se revisa con capturas hechas con la fuente de la app.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .implicitView!;
    view.physicalSize = const Size(800, 1800);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!.reset();
  });
  await testMain();
}
