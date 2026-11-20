# ADR-0020: Sincronización en la app

- Estado: Aceptado
- Fecha: 2026-11-19

## Contexto

La API de la etapa 2 ya existe (ADR-0016 a ADR-0019). Falta que la app sepa
qué subir, cómo guardar lo que baja y cuándo sincronizar, sin dejar de
funcionar cuando no hay servidor.

## Decisión

- **Qué subir: una marca de tiempo.** La app guarda cuándo empezó la última
  subida y sube las filas con `updatedAt` posterior a esa marca. La marca se
  guarda 5 segundos antes del inicio real, para no perder una fila que se
  estaba guardando justo en ese momento. Una fila que se sube dos veces no
  hace daño: el servidor ignora lo que ya tiene.
- **Qué bajar: el número de secuencia** que devuelve el servidor, guardado en
  las preferencias.
- **Cómo guardar lo que baja:**
  - Todo en una sola transacción, en orden de dependencias (usuario,
    ejercicios, rutina, sesiones, series…).
  - Con las llaves foráneas revisadas al final (`PRAGMA defer_foreign_keys`):
    una serie puede llegar antes que su sesión si la sesión cambió después.
  - Cada fila se guarda solo si es nueva o más reciente que la local, la
    misma regla del servidor.
- **Un registro genérico de tablas** (`syncTablesOf`): nombre, tabla y
  `fromJson` de cada una, en lugar de código por tabla. Una prueba verifica que
  cubre todas las tablas de la base.
- **El token va en el Llavero de iOS** (`flutter_secure_storage`), no en las
  preferencias, que quedan en texto plano dentro de los respaldos del
  teléfono.
- **Cuándo sincronizar:**
  - Al abrir la app y al volver a ella, en silencio: sin Wi-Fi de la casa o
    con la Mac apagada no pasa nada.
  - Con el botón "Sincronizar ahora" en Ajustes → Servidor, que sí muestra el
    resultado o el error.
- **Cuentas en la app:**
  - "Crear cuenta" usa el id del usuario local y sube todo.
  - "Iniciar sesión" en una instalación nueva (desde la bienvenida) baja todo.
  - Iniciar sesión con una cuenta distinta a la del usuario local se rechaza:
    mezclar los datos de dos personas no tiene arreglo (misma idea que
    ADR-0007).

## Alternativas consideradas

- **Bandeja de salida con disparadores de SQLite.** Cada cambio quedaría
  anotado en una tabla de pendientes. Es más exacto que la marca de tiempo,
  pero agrega un disparador por tabla y una migración, para evitar un caso (una
  fila guardada en el mismo instante en que empieza la subida) que el margen
  de 5 segundos ya cubre.
- **Sincronizar en segundo plano (Background Fetch).** iOS decide cuándo
  correrla y con una cuenta gratuita es poco confiable. Al abrir la app es
  suficiente.
- **Token en las preferencias.** Es más simple, pero cualquiera con un
  respaldo sin cifrar del teléfono podría leerlo.

## Consecuencias

- Si el reloj del teléfono retrocede (por ejemplo, al cambiarlo a mano), una
  edición podría quedar con una fecha anterior a la marca y no subirse hasta
  que se vuelva a editar. Se acepta: iOS mantiene la hora sincronizada.
- Una fila que llega de una versión más nueva de la app y que esta no sabe
  leer se cuenta como "no sincronizada" en el resultado, en lugar de detener
  todo.
