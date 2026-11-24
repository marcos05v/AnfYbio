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
- **Bloques para varios días.** "ABDOMEN: TODOS LOS DÍAS DE SUPERIOR"
  se copia al final de cada día cuyo nombre diga "superior", sin importar
  acentos, mayúsculas ni plural. "Todos los días" a secas va en todos. Si
  ningún día coincide, el bloque se queda donde apareció y se avisa.
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
| Rutina, formato 2 | 98 % |
| Alimentación, formato 1 | 96 % |
| Alimentación, formato 2 | 100 % (con platos y alternativas, ADR-0023) |

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

## Actualización (2026-11-23): más formatos, sin plantillas nuevas

Dos planes nuevos y dos viejos que no se habían probado mostraron casos que
cualquier otro plan puede traer. Se resolvieron con reglas generales, no con
una plantilla para esos planes:

- **Rutina:**
  - Lo que va antes del primer día ("Regla general: descansos de 2–3 min…")
    se guarda como **indicaciones generales** de la rutina (columna
    `routines.notes`, esquema 10) y se muestra arriba de los días. Antes se
    leía como un "Día 1".
  - "3–4 series" toma el mínimo y deja el rango en la nota.
  - "Biserie de Core (Plancha 30–60 seg + Elevación de piernas): 3 rondas"
    se separa en dos ejercicios unidos.
- **Alimentación:**
  - Días alto y bajo con otras palabras: "mayor/menor demanda",
    "más/menos carbohidratos", "carga".
  - Una sección de recomendaciones al final ("💡 Claves…",
    "Recomendaciones") se guarda en las indicaciones del plan; sus renglones
    numerados ya no se leen como comidas.
  - Fracciones sin unidad ("1/4 de aguacate", "½ plátano"), "medida" como
    scoop, "al gusto" como libre y la cantidad al final ("Arroz cocido
    180 gr").
  - Alternativas en el renglón siguiente ("… yogur o" / "20 g de nueces") o
    entre paréntesis ("(o 20 g de avena si entrenas)", con la condición como
    nota).
  - Comidas con sus alimentos en el mismo renglón ("• Comida: 150 g de
    pollo + 120 g de arroz"). El "+" siempre separa alimentos.
  - Platos con ingredientes entre paréntesis o con "de" ("Hot cakes (1
    huevo, 4 claras…)", "Omelet de 1 huevo y 4 claras").
  - El estado entre paréntesis manda: "(pesadas en seco) cocidas con agua"
    se pesa en seco.
  - Suplementos con "Cuándo:", numerados, y sin confundir un título de
    sección con un suplemento.

| Plan | Antes | Ahora |
| --- | --- | --- |
| Rutina, formato 3 | 91 % (con un "Día 1" falso) | 97 % |
| Alimentación, formato 3 | 86 % | 100 % |
| Alimentación, formato en línea | 0 % | 100 % |
| Alimentación, formato 1 (otra persona) | 85 % | 96 % |

Lo que queda por revisar son datos que el plan no trae ("40 h", un peso sin
unidad, un ejercicio sin repeticiones) o que tienen dos lecturas posibles.

Después se agregó un formato más ("OPCIÓN A/B", comidas numeradas sin viñeta
con sus alimentos en viñetas "•", y suplementos con la dosis en el mismo
renglón). Ese plan quedó al 100 % sin cambiar los demás. `revisar_planes.sh`
ahora acepta PDFs sueltos además de carpetas.

## Actualización (2026-11-23, días de la rutina y suplementos)

- **Días de la rutina en cada menú.** Si el título del menú dice "día: 2,
  5 y 3" o "(días 1, 4, 6 y 7)", esos números se guardan en el menú
  (`plan_menus.routine_days`, esquema v12) y se quitan del título. En la
  pantalla de alimentación, el menú de hoy sale del día de la rutina que
  toca. Si el plan no dice días, se elige como antes: por sesión registrada
  o a mano. Elegirlo a mano siempre manda.
- **Suplementos repetidos al importar otro plan.** Al pasar la guía al
  inventario, ya no se compara el nombre exacto sino el nombre principal
  (`isSameSupplement`): "Omega-3" y "Omega-3 (Ácidos Grasos EPA y DHA)" son
  el mismo.
