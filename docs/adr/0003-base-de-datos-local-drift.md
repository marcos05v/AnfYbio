# ADR-0003: drift como base de datos local

- Estado: Aceptado
- Fecha: 2026-11-16

## Contexto

La app es local-first: toda la funcionalidad depende de una base de datos en el
dispositivo. Los datos son relacionales (sesión → series → ejercicio), la carga
unificada necesita sumas y agrupaciones entre tablas, y el servidor futuro será
PostgreSQL. El proyecto prioriza pruebas automáticas y migraciones versionadas
(ADR-0002, regla 8).

## Decisión

Se usa **drift** sobre SQLite. Las tablas se definen en Dart y un generador de
código (`build_runner`) produce las clases de datos y las consultas tipadas.

Dos decisiones derivadas, pendientes desde el ADR-0002:

- **Los identificadores son UUID versión 7**, generados con el paquete `uuid`.
  A diferencia de la versión 4 (aleatoria), la 7 empieza con la marca de tiempo,
  así que las filas nuevas quedan juntas en el índice y ordenar por `id`
  equivale a ordenar por creación.
- **Los UUID se guardan como texto**, no como 16 bytes binarios. Ocupan más,
  pero se pueden leer al depurar y al exportar; con el volumen de dos usuarios
  el espacio no importa.

## Alternativas consideradas

**sqflite (SQL escrito como texto).** Es más simple y no oculta nada. Se
descartó porque los errores de columnas y tipos aparecen al ejecutar, no al
compilar, y porque migraciones, conversión fila ↔ objeto y pruebas quedan como
trabajo manual sobre nueve tablas.

**Bases no relacionales (Hive, Isar, ObjectBox).** Arrancan más rápido. Se
descartaron porque las agregaciones entre tablas son su punto débil y porque
obligarían a traducir entre dos modelos de datos al sincronizar con PostgreSQL.

**Motores de sincronización (PowerSync, ElectricSQL).** Resuelven la
sincronización completa. Se descartaron por depender de un servicio externo con
planes de pago y porque diseñar la sincronización es parte del objetivo del
proyecto.

## Consecuencias

- Los errores de esquema y de consultas se detectan al compilar.
- Las pruebas de consultas y migraciones corren contra una base en memoria, sin
  dispositivo.
- El esquema local y el de PostgreSQL serán casi iguales, lo que simplifica la
  sincronización.
- Cada cambio al esquema exige ejecutar el generador:
  `dart run build_runner build`.
- Hay una curva de aprendizaje inicial: la sintaxis de drift y el flujo de
  generación de código.
