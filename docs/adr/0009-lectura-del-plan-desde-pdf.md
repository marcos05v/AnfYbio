# ADR-0009: Lectura del plan desde PDF con PDFKit y un intérprete propio

- Estado: Aceptado
- Fecha: 2026-11-16

## Contexto

El plan de alimentación llega siempre como PDF, escrito por la misma
nutrióloga y con una estructura estable (viñetas por comida y por alimento).
Capturarlo a mano son unos cincuenta renglones cada vez que cambia. Las
restricciones: costo cero, y es información de salud.

## Decisión

La lectura ocurre por completo en el teléfono, en dos pasos:

1. **Extraer el texto** con PDFKit, el lector de PDF que trae iOS, a través de
   un canal de plataforma (`anfybio/pdf_text`) de unas veinte líneas de Swift.
2. **Interpretarlo** con un intérprete propio en Dart puro
   (`parseNutritionPlan`), que convierte el texto en el mismo borrador que
   usa la captura manual.

El intérprete no adivina. Lo que no reconoce (una unidad mal escrita, un
número sin unidad, dos alternativas que se pesan distinto) lo conserva y lo
marca. Nada se guarda sin pasar por una pantalla de revisión, donde cada
renglón se puede corregir o quitar.

## Alternativas consideradas

**Un modelo de lenguaje por internet.** Entiende casi cualquier formato. Se
descartó por tres razones: la API de calidad es de pago y los niveles gratuitos
suelen reservarse el derecho de usar los datos; el plan saldría del teléfono; y
la clave tendría que vivir dentro de una app cuyo repositorio es público.

**Una librería de PDF multiplataforma (pdfrx, Syncfusion).** Funcionaría igual
en Android. Syncfusion se descartó por su licencia; pdfrx, porque añade un
binario de varios megabytes para hacer lo que el sistema ya hace. Android está
fuera de alcance, y el canal queda detrás de una interfaz (`PdfTextPicker`)
que permite cambiar la implementación después.

**Reconocimiento de texto (OCR) para PDF escaneados.** Se dejó fuera: los
planes reales traen texto. Si el PDF no lo tiene, la app lo explica y ofrece la
captura manual.

## Consecuencias

- Funciona sin conexión y sin costo, y el plan no sale del dispositivo.
- El intérprete está atado al formato de esta nutrióloga. Si lo cambia, habrá
  que ajustarlo; mientras tanto la revisión y la captura manual siguen
  funcionando.
- El intérprete es Dart puro: sus pruebas corren sin teléfono, sobre un plan
  de ejemplo con datos inventados que reproduce los renglones partidos y los
  errores de captura de un plan real. Los PDF reales no están en el repositorio.
- El código Swift no tiene pruebas automáticas; se compila en cada build y se
  comprobó a mano que PDFKit entrega el texto en el orden esperado.
- Leer la rutina de entrenamiento desde PDF necesitará su propio intérprete,
  que reutiliza la extracción de texto.

## Actualización (2026-11-19): un segundo formato

El lector reconoce también la forma en que escribe otra nutrióloga:

- **Menús:** "🟩 DÍAS ALTOS: …" (con emoji).
- **Comidas:** numeradas sin viñeta.
- **Alimentos:** la cantidad antes del nombre ("130 g de pechuga (en crudo)").
- **Piezas:** un número sin unidad ("2 tostadas").
- **Etiquetas:** "Opcional:" o "Más proteína:", que quedan como nota.
- **Suplementos:** separados por una viñeta sola, con "Objetivo" en lugar de
  "Beneficio".

Se mantiene la regla de no adivinar. Un renglón que trae dos cantidades
("1 manzana ó 1 taza de fresas") o una unidad que la app no maneja (ml) se
importa marcado para revisión. Las pruebas usan un plan inventado con este
formato (`test/fixtures/plan_dias_altos_bajos_ejemplo.txt`).
