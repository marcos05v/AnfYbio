# ADR-0004: Riverpod para el manejo de estado

- Estado: Aceptado
- Fecha: 2026-11-16

## Contexto

Las pantallas necesitan dos cosas: acceder a los repositorios y redibujarse
cuando cambian los datos. La app es local-first, así que casi todo el estado ya
vive en la base de datos; drift puede emitir consultas "vivas" que vuelven a
entregar su resultado cada vez que cambia una tabla. El proyecto prioriza que
todo se pueda probar sin dispositivo.

## Decisión

Se usa **Riverpod** (`flutter_riverpod`), sin generación de código, y solo con
dos tipos de proveedor por ahora:

- `Provider` para la base de datos y los repositorios.
- `StreamProvider` para las consultas vivas de drift.

El estado de los formularios (lo que el usuario está escribiendo) se queda
dentro de cada pantalla con `setState`: es estado efímero que nadie más
necesita. `Notifier` se usará cuando aparezca estado compartido entre pantallas
que no viva en la base de datos.

Las pantallas nunca usan la base de datos directamente; siempre pasan por un
repositorio.

## Alternativas consideradas

**Solo `setState`.** Sin dependencias. Se descartó porque obligaría a pasar la
base de datos por los constructores de todas las pantallas y a recargar cada
lista a mano después de guardar.

**Provider.** Más simple y muy difundido. Se descartó porque sus errores de
configuración aparecen al ejecutar y porque Riverpod, del mismo autor, existe
para corregir esas limitaciones.

**Bloc.** Muy estructurado y frecuente en empresas grandes. Se descartó porque
exige mucho código por función (evento, estado y bloc) y aquí casi todo el
estado es una consulta a la base de datos, donde esa ceremonia no aporta.

**Riverpod con generación de código.** Menos código repetido. Se pospuso para no
sumar una segunda capa de código generado a la de drift.

## Consecuencias

- Guardar un dato actualiza todas las pantallas que lo muestran, sin código
  adicional.
- Las pruebas de interfaz reemplazan `databaseProvider` por una base en memoria
  y recorren la app completa sin dispositivo.
- Los proveedores son variables globales: hay que cuidar que la lógica siga en
  los repositorios y en el dominio, y no se mude a ellos.
