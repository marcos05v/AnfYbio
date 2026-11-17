# ADR-0005: Respaldo de datos en un archivo JSON versionado

- Estado: Aceptado
- Fecha: 2026-11-16

## Contexto

En la Fase 1 no hay servidor: los datos viven solo en el teléfono. La app se
instala con una cuenta gratuita de Apple, así que borrarla por error, cambiar
de teléfono o un fallo en la reinstalación semanal significan perderlo todo. El
alcance pide exportar todos los datos del usuario a un archivo.

## Decisión

El respaldo es **un solo archivo JSON** con todas las filas del usuario, que se
entrega mediante la hoja de compartir de iOS (Archivos, iCloud Drive, AirDrop).

- Lleva `format`, `formatVersion`, `schemaVersion` y `exportedAt`, para que una
  futura importación sepa qué está leyendo.
- Una lista por tabla, con las mismas columnas que la base de datos.
- Fechas en texto ISO 8601 en UTC; enumerados y unidades como texto.
- Incluye las filas con borrado lógico (`deletedAt`): es una copia fiel, no un
  informe.
- Las tablas se leen dentro de una transacción para que el archivo sea
  coherente.

## Alternativas consideradas

**Copiar el archivo SQLite.** Es lo más simple y lo más fiel. Se descartó
porque el archivo es opaco (no se puede abrir ni revisar sin herramientas),
queda atado a la versión exacta del esquema y contendría a todos los usuarios
de la base, no solo al que exporta.

**Un CSV por tabla.** Se abre en una hoja de cálculo. Se descartó porque son
ocho archivos que habría que empaquetar, y CSV no distingue bien entre vacío y
nulo ni conserva los tipos.

**Guardar el archivo en la carpeta de la app y mostrarlo en Archivos.** No
necesita la hoja de compartir. Se descartó porque el respaldo quedaría dentro
de la propia app y se borraría junto con ella, que es justo el caso que debe
cubrir.

## Consecuencias

- El usuario decide dónde guardar la copia; para que sirva debe quedar fuera
  del teléfono o en iCloud Drive.
- El archivo se puede leer y revisar con cualquier editor de texto.
- El formato coincide casi por completo con lo que enviará la sincronización,
  así que este código se reutilizará en la etapa 2.
- **Todavía no existe la importación.** El respaldo protege los datos, pero
  restaurarlos en la app requiere una función que está pendiente. El formato
  versionado está pensado para hacerla posible.
- El respaldo es manual: no hay copias automáticas ni recordatorios.
