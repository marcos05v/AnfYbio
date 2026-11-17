# ADR-0006: fl_chart para las gráficas

- Estado: Aceptado
- Fecha: 2026-11-16

## Contexto

La Fase 1 pide gráficas históricas por ejercicio (1RM estimado a lo largo del
tiempo). La app usa componentes de iOS (Cupertino), tiene modo claro y oscuro,
y no puede depender de nada de pago.

## Decisión

Se usa **fl_chart** (licencia MIT) para las gráficas de línea.

El eje horizontal representa el tiempo real entre sesiones y no su número de
orden: así un descanso de tres semanas se ve como un hueco, no como un paso
más. Cada sesión aporta un punto con su mejor 1RM estimado, calculado solo con
series efectivas de hasta 10 repeticiones (la regla vive en el dominio, en
`one_rep_max_history.dart`, no en la gráfica).

## Alternativas consideradas

**Dibujar las gráficas a mano con `CustomPainter`.** Sin dependencias y con
control total. Se descartó porque ejes, etiquetas e interacción al tocar son
mucho código que mantener para algo que no es el objetivo del proyecto. La
vista de carga semanal sí se dibuja con widgets simples, porque son solo barras.

**Syncfusion Flutter Charts.** Muy completo. Se descartó por su licencia: es
comercial, con una edición comunitaria sujeta a condiciones, lo que choca con
la restricción de costo cero.

**graphic / community_charts.** Gratuitas. Se descartaron por tener menos
mantenimiento y documentación que fl_chart.

## Consecuencias

- La gráfica toma colores y fuente del tema de la app, así que respeta el modo
  oscuro.
- La librería solo dibuja: recibe puntos ya calculados. Cambiarla por otra no
  tocaría el dominio ni sus pruebas.
- Las pruebas de interfaz comprueban los valores mostrados, no el trazo de la
  línea; el aspecto se revisa visualmente.
