# ADR-0016: Sincronización por filas, gana el último cambio

- Estado: Aceptado
- Fecha: 2026-11-19

## Contexto

La etapa 2 agrega un servidor en la Mac para que cada teléfono respalde y
sincronice sus datos en la red de la casa. La app sigue siendo local-first: el
teléfono es la fuente principal y debe funcionar igual sin servidor.

El modelo ya está listo para esto (ADR-0002): ids UUID creados en el cliente,
`user_id` en cada fila, borrado lógico con `deleted_at` y `updated_at` en UTC.
Falta decidir cómo viajan los cambios y qué pasa si una misma fila cambió en dos
lugares.

## Decisión

**Empujar y jalar filas completas; en un conflicto gana el `updated_at` más
reciente.**

- **Subir (`POST /sync/push`).** El cliente manda las filas que cambiaron desde
  su última subida: tabla, id, `updatedAt`, `deletedAt` y la fila completa. El
  servidor guarda cada una solo si su `updatedAt` es más nuevo que el que ya
  tiene. Si es igual o más viejo, la ignora y responde cuál quedó.
- **Bajar (`GET /sync/pull?since=N`).** Cada fila aceptada recibe un número de
  secuencia del servidor que siempre crece. El cliente guarda el último número
  que vio y pide solo lo posterior, por páginas. No se usa el reloj del cliente
  para saber qué es nuevo: dos relojes desfasados no pueden hacer que se salte
  un cambio.
- **Borrar es actualizar.** Un borrado es una fila con `deletedAt`; viaja igual
  que cualquier cambio y gana o pierde con la misma regla.
- **Cada quien solo toca lo suyo.** El servidor rechaza filas cuyo `userId` no
  sea el de la cuenta que sincroniza.

## Alternativas consideradas

- **Por campo.** Se conservaría el peso editado en un lado y las reps en otro.
  Exige guardar la fecha de cada campo y complica las pruebas, para un caso que
  casi no ocurre: cada persona usa su propio teléfono y las filas son pequeñas
  (ADR-0002, regla 6), así que dos ediciones rara vez tocan la misma fila.
- **Preguntar al usuario.** Es lo más seguro, pero agrega pantallas que casi
  nunca se verían.
- **CRDT o bitácora de operaciones.** Resuelven la edición simultánea en
  tiempo real, que esta app no necesita, y su costo de diseño es mucho mayor.

## Consecuencias

- Si la misma fila se edita en dos dispositivos sin sincronizar, se pierde la
  edición más vieja. Se acepta: con un teléfono por persona casi no pasa.
- Un reloj del teléfono muy adelantado haría ganar sus cambios. El servidor
  rechaza fechas más de 5 minutos en el futuro.
- El número de secuencia permite reanudar una sincronización cortada sin
  repetir ni perder filas.
