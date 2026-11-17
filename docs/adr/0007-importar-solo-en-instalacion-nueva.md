# ADR-0007: Un respaldo solo se restaura en una instalación sin datos

- Estado: Aceptado
- Fecha: 2026-11-16

## Contexto

El ADR-0005 dejó pendiente la importación del respaldo. Importar es la
operación más arriesgada de la app: puede sobrescribir o duplicar datos reales.
Los casos que hay que cubrir son cambiar de teléfono y reinstalar la app tras
borrarla; en ambos la app está vacía.

## Decisión

El respaldo solo se puede restaurar cuando la base no tiene ningún usuario. La
opción aparece únicamente en la pantalla de bienvenida.

- Se importa todo o nada: una sola transacción, y cualquier fila inválida
  deshace lo ya insertado.
- Se rechazan los archivos de otro formato y los de una versión más nueva que
  la app.
- Las filas conservan sus identificadores y fechas originales, también las
  borradas lógicamente.

## Alternativas consideradas

**Reemplazar los datos existentes.** Permite restaurar en cualquier momento. Se
descartó porque un toque equivocado borraría todo lo registrado desde el último
respaldo, y no hay forma de deshacerlo.

**Combinar el archivo con los datos existentes.** Es lo que haría un usuario
con dos teléfonos. Se descartó porque combinar exige resolver conflictos (la
misma fila editada en los dos lados), que es exactamente el problema de la
sincronización: tendrá su propio ADR y no conviene adelantar una versión a
medias.

## Consecuencias

- Restaurar nunca destruye datos, porque no hay datos que destruir.
- Para volver a un respaldo anterior en un teléfono con datos hay que borrar la
  app y reinstalarla.
- La prueba principal exporta, importa en una base vacía y vuelve a exportar:
  los dos archivos deben ser idénticos.
- El importador depende de que el esquema del archivo sea igual o anterior al
  de la app. Cuando haya una segunda versión del esquema, hará falta migrar los
  respaldos antiguos al leerlos.
