# ADR-0021: Lectura tolerante de planes y revisión con planes reales

- Estado: Aceptado
- Fecha: 2026-11-19

## Contexto

El lector de rutinas (ADR-0010) seguía la plantilla de un solo entrenador:
viñetas "•/◦", "Biserie:" y "N series de A a B repeticiones". La rutina de
otra persona usa otra forma:

- Días en mayúsculas.
- "5 series x 8-10 reps".
- "BISERIE 1 (3 series):" con las series en el encabezado.
- Ejercicios con etiqueta ("A1.", "C2:").
- Numeración rota que deja el PDF ("2. 3. Hip Thrust").
- Renglones sin viñeta.

Con ella, casi todos los ejercicios quedaban marcados para revisión. Otra
persona más va a usar la app y no se sabe cómo escribe su entrenador.

## Decisión

**El lector reconoce cada renglón por lo que dice, no por su viñeta:**

- **Viñetas, números y etiquetas** se quitan y solo se recuerda qué tipo
  traía el renglón (principal, secundario, numerado, con etiqueta).
- **Clasificación:** un renglón es día, biserie, grupo o ejercicio según su
  texto. "Biserie" y "triserie" agrupan dos o tres ejercicios y les prestan
  sus series; un rótulo en mayúsculas es un grupo y presta sus rondas.
- **Series y repeticiones:** se entienden las formas comunes:
  - "4 series de 8 a 12 repeticiones", "4 series x 8-12 reps", "4 x 15";
  - "12 reps", "al fallo", "30 seg";
  - "10,10,8 reps" (drop set, queda en texto);
  - las repeticiones antes de las series.
- **Calentamiento y cardio** guardan su duración y su nota, sin avisos.
- **No adivina:** lo que no entiende se conserva y se marca, igual que antes.
  Para no leer cualquier documento como rutina, el texto suelto antes del
  primer día se ignora.

**Revisión con planes reales sin publicarlos:** `tool/revisar_planes.sh
<carpeta>` extrae el texto de cada PDF con PDFKit (lo mismo que usa la app)
en una carpeta temporal que se borra al terminar. Luego informa:

- qué tipo de documento es;
- cuánto encontró;
- qué porcentaje entendió sin revisión.

Falla si un archivo no se pudo leer. Los PDFs nunca entran al repositorio;
las pruebas usan planes inventados que imitan cada formato.

Resultado con los cuatro planes reales disponibles:

| Documento | Entendido sin revisión |
|---|---|
| Rutina, formato 1 | 98 % |
| Rutina, formato 2 | 96 % |
| Alimentación, formato 1 | 96 % |
| Alimentación, formato 2 | 66 % (renglones con dos cantidades, a propósito) |

## Alternativas consideradas

- **Agregar una plantilla por cada entrenador.** Es lo que se hizo con la
  alimentación (ADR-0009). Cada plan nuevo exige código nuevo y no escala.
- **Un modelo de lenguaje en la nube.** Lo descarta ADR-0009: cuesta y saca
  datos de salud del teléfono.
- **El modelo de Apple en el teléfono (Foundation Models, iOS 26).** Es
  gratuito, privado y sin internet, y devuelve datos con estructura. Solo
  funciona en iPhone con Apple Intelligence (15 Pro o posterior) y exige
  código nativo en Swift. Queda como respaldo posible para cuando el lector
  no entienda un documento, no como lector principal: sus resultados no son
  reproducibles en las pruebas.

## Consecuencias

- Los planes nuevos se pueden probar antes de importarlos en el teléfono.
  Un formato que no se entiende se detecta con la herramienta y se agrega con
  un plan inventado que lo imite.
- Ser tolerante aumenta el riesgo de leer algo que no es una rutina. Las
  pruebas cubren un texto ajeno (una factura), y la revisión previa a guardar
  sigue siendo obligatoria.
