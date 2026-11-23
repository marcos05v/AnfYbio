# Instalar AnfYbio en un teléfono Android

En Android la app se instala con un archivo **APK**, sin tienda y sin
cuenta de desarrollador. **No caduca**: queda instalada hasta que se
desinstale (ADR-0024).

## 1. Crear la llave de firma (una sola vez)

Todas las versiones deben firmarse con la misma llave; si no, Android no
deja actualizar y habría que desinstalar, perdiendo los datos del teléfono.

```sh
mkdir -p ~/.anfybio
keytool -genkey -v -keystore ~/.anfybio/anfybio-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias anfybio
```

Te pide una contraseña y algunos datos (nombre, ciudad); pueden ser los que
quieras. Luego crea `apps/mobile/android/key.properties` con:

```properties
storeFile=/Users/TU_USUARIO/.anfybio/anfybio-release.jks
storePassword=la-contraseña-que-elegiste
keyAlias=anfybio
keyPassword=la-contraseña-que-elegiste
```

Ese archivo y la llave **no se suben a git** (están en `.gitignore`).
**Respalda la carpeta `~/.anfybio`** (por ejemplo, en una USB): sin ella no
se puede actualizar la app.

## 2. Generar el APK

```sh
cd apps/mobile
flutter build apk --release --split-per-abi
```

Para casi cualquier teléfono de los últimos años, el archivo es:

```
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 3. Instalarlo en el teléfono

1. Manda el APK al teléfono (WhatsApp como documento, Google Drive o cable).
2. Ábrelo. Android pedirá permitir **"Instalar apps desconocidas"** para la
   app con la que lo abriste (WhatsApp, Archivos…): actívalo.
3. Toca **Instalar**. Si aparece Play Protect advirtiendo que es una app
   desconocida, elige **Instalar de todas formas**.
4. Al abrir AnfYbio por primera vez, acepta el permiso de **notificaciones**
   para los recordatorios de suplementos.

## Actualizar

Genera un APK nuevo (paso 2) y ábrelo en el teléfono: se instala encima y
conserva los datos, siempre que esté firmado con la misma llave.

## Conectarlo al servidor de la casa

En Android escribe la **IP de la Mac** (por ejemplo `192.168.1.77`) en
Ajustes → Servidor; el nombre `.local` no siempre funciona. La IP se ve en la
Mac en Ajustes del Sistema → Wi-Fi → Detalles.
