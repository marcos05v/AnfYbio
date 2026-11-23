# ADR-0024: Android dentro del alcance

- Estado: Aceptado
- Fecha: 2026-11-21
- Modifica: el alcance del proyecto ("iOS primero; Android fuera de
  alcance").

## Contexto

Una persona más va a usar la app y su teléfono es Android. El código de
Flutter es casi todo multiplataforma, pero algunas piezas eran solo de iOS:

- la lectura de PDF con PDFKit;
- los sonidos de notificación en `Library/Sounds`;
- los permisos de red local de iOS;
- la firma con la cuenta gratuita de Apple.

## Decisión

- **Android pasa a estar dentro del alcance**, como segunda plataforma. La
  interfaz sigue siendo de estilo iOS (Cupertino) en los dos sistemas: una
  sola interfaz que mantener.
- **Lectura de PDF:** el mismo canal `anfybio/pdf_text` que en iOS,
  implementado en Kotlin con **PdfBox-Android** (Apache 2.0, gratis, sin
  servicios externos). El código Dart y los lectores de planes no cambian.
- **Notificaciones:**
  - Un canal por sonido, porque en Android el sonido pertenece al canal y
    no se puede cambiar después.
  - Los sonidos se copian a `res/raw` como WAV, con los mismos nombres que
    los de iOS.
  - El botón "Ya lo tomé" registra la toma sin abrir la app.
  - Avisos inexactos (`inexactAllowWhileIdle`), que no necesitan el permiso
    de alarmas exactas.
- **Red:** HTTP sin cifrar permitido (`usesCleartextTraffic`) para el
  servidor de la casa (ADR-0019). Android no siempre resuelve los nombres
  `.local`, así que en Android la app pide la IP de la Mac.
- **Distribución:** un APK instalado a mano ("orígenes desconocidos"). Es
  gratis, sin cuenta de desarrollador, y **no caduca** como la firma gratuita
  de iOS. Se firma con una llave propia que vive fuera del repositorio
  (`android/key.properties`, ignorado por git). Todas las versiones deben ir
  con la misma llave para actualizarse sin perder datos.
- **Compilación:** compileSdk 37, que piden flutter_local_notifications y
  androidx.core. "Core library desugaring" activo. Reglas de R8 para
  PdfBox. Los sonidos y el ícono de notificación se protegen de la
  reducción de recursos con `res/raw/keep.xml`.
- **CI:** un trabajo nuevo compila el APK de release en cada cambio de la
  app.

## Alternativas consideradas

- **Google Play.** La cuenta de desarrollador cuesta 25 USD; va contra el
  costo cero. Un APK alcanza para una persona.
- **Interfaz Material en Android.** Se vería más nativa, pero duplicaría las
  pantallas y sus pruebas.
- **Un paquete de Flutter para leer PDF.** Los que hay usan PdfBox por
  debajo en Android, o son de pago para uso comercial. El canal propio deja
  el mismo código en los dos sistemas.
- **Emulador de Android para probar.** En una Mac de 8 GB pesa demasiado.
  Se prueba en un teléfono real.

## Consecuencias

- Hay que verificar en un teléfono real lo que las pruebas automáticas no
  cubren:
  - que PdfBox extraiga el texto igual que PDFKit (viñetas y saltos de
    línea);
  - las notificaciones con su botón;
  - la conexión por IP.
- Si se pierde la llave de firma, la app no se puede actualizar: hay que
  desinstalarla y reinstalarla. Con el servidor, los datos se recuperan.
- El APK completo pesa unos 73 MB porque incluye tres tipos de procesador;
  separado por tipo (`--split-per-abi`), el de teléfonos modernos pesa unos
  30 MB.
