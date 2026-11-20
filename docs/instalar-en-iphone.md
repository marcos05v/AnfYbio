# Instalar AnfYbio en un iPhone sin pagar

Con una cuenta gratuita de Apple, la app firmada **caduca a los 7 días**:
después ya no abre hasta que se vuelve a firmar. Los datos **no se pierden**
mientras la app no se borre: renovar la firma es una actualización.

Límites de la cuenta gratuita:

- La firma dura 7 días.
- Hasta 3 apps instaladas así por iPhone.
- Hasta 10 identificadores de app nuevos por semana.

## Regla de oro: instalar en modo release

`flutter run` a secas instala la versión de **depuración**. Desde iOS 14, una
app de Flutter en depuración **no abre desde la pantalla de inicio** si no
está conectada a la Mac. Para usarla en el día a día:

```sh
cd apps/mobile
flutter run --release
```

Es más rápida, abre sola desde el ícono y sigue funcionando sin la Mac hasta
que pasan los 7 días.

## Opción A: renovar a mano cada semana (lo más simple)

1. Conecta el iPhone por cable, o por Wi-Fi si ya lo emparejaste en Xcode
   (Window → Devices and Simulators → "Connect via network").
2. Ejecuta `flutter run --release`.
3. Listo por otros 7 días.

### En otro iPhone (por ejemplo, el de un familiar)

La primera vez:

1. Conéctalo por cable a la Mac y toca **"Confiar"** en el iPhone.
2. En el iPhone: **Ajustes → Privacidad y seguridad → Modo de desarrollador**
   → activarlo y reiniciar.
3. En la Mac: `flutter devices` muestra su nombre; instala con
   `flutter run --release -d "<nombre del iPhone>"`.
4. En el iPhone: **Ajustes → General → VPN y gestión de dispositivos** →
   tu cuenta de desarrollador → **Confiar**.
5. Opcional: en Xcode (Window → Devices and Simulators) marca "Connect via
   network" para las siguientes renovaciones sin cable.

Cada 7 días hay que repetir el paso 3 con ese iPhone cerca de la Mac.

## Opción B: AltStore, renovación automática en el Wi-Fi de casa

[AltStore](https://altstore.io) es gratuito: un programa en la Mac
(AltServer) renueva la firma por Wi-Fi en segundo plano, siempre que el iPhone
y la Mac estén en la misma red con AltServer abierto. Sigue usando la cuenta
gratuita, así que aplican los mismos límites, pero ya no hay que acordarse.

1. Instala AltServer en la Mac desde altstore.io y, desde su menú, instala
   AltStore en cada iPhone (por cable la primera vez).
2. Arma el archivo de la app:

   ```sh
   cd apps/mobile
   flutter build ios --release
   rm -rf build/ipa-alt && mkdir -p build/ipa-alt/Payload
   cp -R build/ios/iphoneos/Runner.app build/ipa-alt/Payload/
   (cd build/ipa-alt && zip -qr AnfYbio.ipa Payload)
   ```

3. Pasa `build/ipa-alt/AnfYbio.ipa` al iPhone (AirDrop) y ábrelo con
   AltStore → "Mis apps" → "+".
4. AltStore la renueva solo cuando el iPhone está en casa.

Cuidados:

- **AltStore instala una copia con otro identificador**, así que es otra app
  para iOS: no hereda los datos de la versión instalada con `flutter run`.
  Antes de cambiar, sincroniza con el servidor (Ajustes → Servidor) o exporta
  un respaldo; en la nueva, inicia sesión o restaura.
- Pide tu Apple ID para firmar. Muchos usan un Apple ID secundario solo para
  esto.

## Lo que sí cuesta (solo como referencia)

El Apple Developer Program (99 USD al año) da firmas de un año y TestFlight
para invitar a otras personas. El proyecto no lo usa: su restricción es costo
cero.
