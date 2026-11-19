# ADR-0014: Notificaciones locales para tomas y reabastecimiento

- Estado: Aceptado
- Fecha: 2026-11-18

## Contexto

La Fase 3 pide recordatorios de toma y un aviso de reabastecimiento con
anticipación configurable. Hasta ahora el aviso solo se veía al abrir la app.
Restricciones: costo cero, sin servidor (la app es local-first) e iOS como
plataforma.

## Decisión

Se usan **notificaciones locales** con `flutter_local_notifications`: el
propio iPhone las dispara a la hora programada, aunque la app esté cerrada.

- **Qué programar lo decide una función pura**
  (`planSupplementNotifications`), probada sin dispositivo. La app borra
  todas las pendientes y vuelve a programar la lista completa cada vez que
  cambia el inventario y cada vez que vuelve a primer plano.
- **Recordatorio de toma**: opcional por suplemento, a la hora elegida. Se
  programan los próximos 7 días como avisos sueltos, no uno repetitivo: así
  se puede omitir el de hoy si ya se tomó, y no se recuerda tomar algo que se
  acabó.
- **Aviso de reabastecimiento**: a las 9:00 del día en que quedan los días de
  anticipación configurados. Si ya se está dentro del plazo, a la mañana
  siguiente; como se reprograma al abrir la app, avisa cada mañana hasta
  reabastecer.
- iOS guarda como máximo 64 notificaciones pendientes por app: si hay muchos
  suplementos se acortan los días de recordatorio para no pasar de 60.
- **El permiso se pide al usarlo**: al dar de alta un suplemento o al activar
  un recordatorio, no al abrir la app. Si está denegado, el formulario
  explica cómo activarlo.
- La hora del recordatorio se guarda en la base (columna `reminder_minute`,
  versión 6 del esquema) para que entre en el respaldo.
- La zona horaria se toma del teléfono (`flutter_timezone`) para que la hora
  programada sea la hora local.

### Ampliación: botón "Ya lo tomé" y sonido propio

- Los recordatorios llevan el botón **"Ya lo tomé"**, que registra la toma
  sin abrir la app. Con la app cerrada, iOS arranca un motor de Flutter
  aparte que ejecuta `handleNotificationActionInBackground`; por eso la base
  se abre con `shareAcrossIsolates`, para que ese motor y la app usen la
  misma conexión. Si ese día ya había una toma, no registra otra.
- **Sonido propio**: tres sonidos sintetizados para el proyecto
  (`tool/make_sounds.py`), sin licencias de terceros, más el del sistema. Es
  una preferencia del teléfono. iOS solo reproduce sonidos que vienen en la
  app; en lugar de agregarlos al proyecto de Xcode, se copian de los recursos
  a `Library/Sounds` la primera vez.

## Alternativas consideradas

**Notificaciones push desde un servidor.** Permitirían avisos aunque la app
no se abra en semanas. Se descartaron: requieren servidor y una cuenta de
desarrollador de pago de Apple, y no aportan nada que las locales no cubran.

**Un recordatorio diario repetitivo** (`matchDateTimeComponents`). Es una sola
notificación por suplemento. Se descartó porque sonaría también los días en
que ya se tomó.

**Guardar la hora en las preferencias del dispositivo.** Evita migrar el
esquema. Se descartó porque se perdería al restaurar un respaldo.

**Usar un tono del iPhone o una canción.** iOS no da acceso a sus tonos ni
a la música del usuario para notificaciones de otras apps.

**Sonido continuo tipo alarma, aunque el teléfono esté en silencio.** Solo
lo permiten las alertas críticas, que Apple reserva para apps médicas o de
seguridad con un permiso especial.

## Consecuencias

- Si la app no se abre en más de una semana, los recordatorios se agotan
  hasta la siguiente apertura. El aviso de reabastecimiento futuro sí queda
  programado.
- La programación real (`LocalNotificationScheduler`) y el botón en segundo
  plano no tienen pruebas automáticas: dependen del sistema. Las pruebas usan un programador falso que
  registra lo que se programaría; el comportamiento en el iPhone se comprueba
  a mano.
- Al escribir la prueba de migración apareció un error de orden: una tabla
  creada en un paso con la definición actual ya trae las columnas de pasos
  posteriores. Agregar una columna a una tabla existente debe hacerse solo si
  la tabla venía de antes.
