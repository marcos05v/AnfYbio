# ADR-0002: Reglas del modelo de datos para soportar sincronización

- Estado: Aceptado
- Fecha: 2026-11-16

## Contexto

La app es local-first: en la Fase 1 no hay servidor y todo vive en la base de
datos del dispositivo. Más adelante se agregará sincronización con un backend
compartido por varios usuarios. Si el modelo se diseña pensando solo en un
dispositivo, agregar la sincronización después obligaría a migrar datos reales
ya capturados (cambiar llaves primarias, reconstruir relaciones).

Este ADR fija las reglas del modelo. No decide el mecanismo de sincronización ni
la resolución de conflictos; eso tendrá su propio ADR.

## Decisión

Todas las tablas con datos del usuario cumplen estas reglas desde el primer
esquema:

1. **Identificadores UUID generados en el cliente.** Dos dispositivos sin
   conexión pueden crear filas sin que sus llaves choquen. Un entero
   autoincremental no lo permite.
2. **Toda fila lleva `user_id`.** En el dispositivo hay un solo usuario, pero en
   el servidor convivirán los datos de varios.
3. **Borrado lógico con `deleted_at`.** Si una fila se borra físicamente, el
   servidor no distingue "se borró" de "todavía no llega" y la fila reaparecería
   al sincronizar.
4. **`created_at` y `updated_at` en UTC.** Son la base de cualquier estrategia
   de conflictos que se elija después.
5. **Se guardan hechos, no valores derivados.** 1RM estimado, ritmo, carga sRPE
   y carga aguda/crónica se calculan al consultarse. Un derivado almacenado
   puede quedar inconsistente con sus datos de origen y genera conflictos que no
   son reales.
6. **Filas pequeñas en lugar de documentos.** Cada serie, intervalo y vuelta es
   una fila. Los conflictos se resuelven por fila, así que dos ediciones a
   series distintas de la misma sesión no chocan.
7. **Unidades canónicas:** distancia en metros, tiempo en milisegundos o
   segundos según la precisión necesaria.
8. **El esquema local usa migraciones versionadas** desde la primera versión.

### Excepción: el peso en fuerza

El peso de una serie se guarda como `weight` + `weight_unit` (`kg` o `lb`), tal
como lo capturó el usuario, y no convertido a una unidad canónica. En el
gimnasio conviven equipos en libras y en kilogramos; convertir al guardar
introduce redondeo (225 lb = 102.058 kg) y pierde el dato de la unidad original.
La conversión a kg se hace al calcular 1RM y gráficas. Es coherente con la
regla 5: la unidad capturada es el hecho; el valor en kg es el derivado.

## Alternativas consideradas

**Diseñar solo para un dispositivo y migrar cuando llegue la sincronización.**
Menos columnas hoy. Se descartó porque el costo se paga después y con datos
reales: cambiar llaves enteras por UUID implica reescribir todas las relaciones.

**Llaves enteras locales más un UUID "de sincronización" aparte.** Mantiene
llaves pequeñas en SQLite. Se descartó por duplicar identidad: cada relación
tendría que traducirse entre los dos identificadores al sincronizar.

**Borrado físico con un registro de borrados aparte.** Mantiene las tablas
limpias. Se descartó por complejidad: es una tabla más que mantener coherente
con todas las demás.

## Consecuencias

- Cada tabla carga cinco columnas comunes: `id`, `user_id`, `created_at`,
  `updated_at` y `deleted_at`.
- Todas las consultas deben filtrar `deleted_at IS NULL`; conviene centralizarlo
  en la capa de acceso a datos para no olvidarlo.
- Los valores derivados se recalculan en cada consulta. Con el volumen de datos
  de dos usuarios no es un problema de rendimiento.
- Las filas borradas se acumulan. Su limpieza se definirá junto con la
  estrategia de sincronización.
- La versión de UUID (v7) se decidió en el ADR-0003.
