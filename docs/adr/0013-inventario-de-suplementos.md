# ADR-0013: Inventario de suplementos

- Estado: Aceptado
- Fecha: 2026-11-16

## Contexto

La Fase 3 pide llevar el inventario de suplementos: qué se compró, cuánto se
toma, cuándo se acaba cada uno, avisar para reabastecer y registrar las tomas
para medir la adherencia y afinar la predicción.

## Decisión

Tres tablas: el **suplemento** (nombre, unidad, dosis diaria, días de aviso),
sus **compras** (lo que entra) y sus **tomas** (lo que sale).

- **Las existencias no se guardan**: son compras menos tomas (ADR-0002,
  regla 5). No hay un contador que pueda quedar desfasado.
- **Una sola unidad por suplemento**, elegida por el usuario, para compras,
  dosis y tomas: gramos para un polvo, cápsulas para un frasco. Así no hay
  conversiones entre miligramos y cápsulas.
- **Corregir existencias agrega un ajuste**, no modifica el historial: es una
  salida (o entrada, si es negativa) que no cuenta como toma.
- **La adherencia** es la fracción de días con al menos una toma, desde la
  primera toma y como máximo en los últimos 30 días.
- **La fecha en que se acaba** se predice con la dosis indicada; tras una
  semana de registros, con el consumo real de ese periodo. Quien toma el
  suplemento la mitad de los días verá que le dura el doble.
- **El aviso de reabastecimiento** aparece dentro de la app cuando quedan
  tantos días o menos como los configurados en cada suplemento.
- La guía del plan sirve de punto de partida: la app propone nombre, dosis,
  unidad y momento de toma leyendo el texto de la guía.

- **La presentación** (pastillas, polvo u otra) se pregunta al dar de alta y
  fija la unidad: "pastillas", gramos (el contenido de un polvo se puede
  escribir en kilos) o la que escriba el usuario. No se guarda aparte: se
  deduce de la unidad.
- **Un envase ya empezado** se da de alta con su fecha de compra: la app
  estima lo consumido (dosis diaria × días desde la compra) y lo anota como
  ajuste, para no arrancar en blanco ni inventar tomas que no cuentan en la
  adherencia. Se corrige después con "Corregir existencias".
- Desde la guía del plan, una dosis en gramos se propone como polvo; una en
  mg o UI se toma como la concentración de cada pastilla y se propone una
  pastilla al día.

Es la versión 5 del esquema, con su prueba de migración.

## Alternativas consideradas

**Cantidad del envase, tamaño de porción y porciones al día** (como en el
alcance original). Modela el envase tal como viene. Se descartó por pedir tres
datos donde bastan dos: con la unidad libre, "60 cápsulas, 1 al día" y
"300 g, 5 al día" se expresan igual.

**Guardar las existencias como un número editable.** Es lo más simple. Se
descartó porque se pierde el porqué de cada cambio y no permite calcular
adherencia ni consumo real.

**Descontar la dosis automáticamente cada día.** No exige registrar nada. Se
descartó porque el inventario dejaría de reflejar lo que realmente se toma,
que es justo lo que se quiere medir.

## Consecuencias

- La predicción es tan buena como el registro: si se toma sin registrar, la
  app cree que queda más. Para eso existe "Corregir existencias".
- Los recordatorios y el aviso como notificaciones se resolvieron en el
  ADR-0014.
- El inventario entra en el respaldo.
