# ADR-0010: Rutina de entrenamiento y sesiones que la siguen

- Estado: Aceptado
- Fecha: 2026-11-16

## Contexto

Hasta ahora la app registraba lo que se hizo, pero no sabía lo que tocaba. El
plan de entrenamiento llega en PDF, con días numerados, ejercicios con series y
rangos de repeticiones, series de aproximación en los ejercicios principales y
biseries. En el alcance original, importar la rutina era parte de la Fase 4 y
dependía de un catálogo de ejercicios; se adelantó porque es lo que más cambia
el uso diario.

## Decisión

```
rutina → día → ejercicio (aproximación, series, repeticiones, biserie, nota)
sesión de fuerza → día de rutina (opcional)
```

- **La rutina es una plantilla, separada del historial.** Borrarla o
  reemplazarla no toca las sesiones ya registradas.
- **Una sesión de fuerza puede seguir un día de la rutina** (`routine_day_id`)
  o ser libre. Si lo sigue, su pantalla muestra cada ejercicio con su objetivo
  y cuántas series efectivas lleva.
- **El ejercicio de la rutina guarda su nombre como texto** y se enlaza con un
  ejercicio real la primera vez que se registra una serie: se reutiliza el del
  mismo nombre o se crea. Así la rutina se puede importar sin catálogo, y el
  historial y las gráficas de 1RM siguen funcionando sobre los mismos
  ejercicios.
- **La biserie es una marca en el segundo ejercicio** ("va con el anterior"),
  no un grupo aparte: se edita con un interruptor y basta para parejas.
- **El día que toca** es el siguiente al de la última sesión que siguió la
  rutina, y vuelve al primero al terminar la vuelta. Es una sugerencia: el
  usuario elige.
- **Al agregar una serie** se propone el peso y la unidad de la última vez que
  se hizo ese ejercicio, y se marca como aproximación mientras falten las que
  pide la rutina.

La lectura del PDF sigue el ADR-0009: PDFKit para el texto y un intérprete
propio (`parseRoutine`) que marca lo que no entiende, con revisión obligatoria.

Es la versión 3 del esquema: crea tres tablas y agrega una columna a
`sessions`. Hay pruebas de migración desde las versiones 1 y 2.

## Alternativas consideradas

**Exigir un catálogo de ejercicios antes de importar.** Daría nombres
normalizados e imágenes. Se descartó por ahora: obligaría a emparejar a mano
cuarenta ejercicios antes de poder usar la rutina. El enlace perezoso deja
abierta la puerta al catálogo de la Fase 4.

**Biseries como grupos con identificador.** Permitiría triseries y circuitos.
Se descartó porque la rutina real solo trae parejas y un grupo complica la
edición.

**Calcular el día por la fecha (lunes = día 1).** Más simple. Se descartó
porque saltarse un día desfasa toda la semana.

**Guardar el objetivo copiado en cada serie.** Conservaría lo que pedía la
rutina aunque luego cambie. Se pospuso: hoy nada compara lo hecho con lo
pedido a lo largo del tiempo.

## Consecuencias

- Iniciar una sesión de fuerza pide un paso más (elegir el día) cuando hay
  rutina.
- Renombrar un ejercicio de la rutina lo desenlaza: se trata como otro
  ejercicio, con su propio historial.
- Si se edita la rutina, las sesiones anteriores muestran los objetivos
  actuales, no los que había cuando se hicieron.
- El intérprete toma solo el primer bloque cuando un ejercicio trae dos
  ("4 series agarre prono + 4 series agarre neutro") y lo marca para revisión.
- La rutina entra en el respaldo; los respaldos anteriores se siguen pudiendo
  restaurar.
