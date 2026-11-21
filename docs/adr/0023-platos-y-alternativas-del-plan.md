# ADR-0023: Platos con ingredientes y alternativas con su propia cantidad

- Estado: Aceptado
- Fecha: 2026-11-20

## Contexto

Cada renglón del plan se guardaba como un solo alimento con una cantidad.
Eso no alcanza para cómo escriben algunas nutriólogas:

- **Platos:** "Sándwich en pan integral (2 rebanadas) con 90 g de pechuga
  de pavo u 80 g de queso panela": un plato con ingredientes, y uno de ellos
  con alternativa.
- **Sumas:** "3 claras de huevo + 1 huevo entero": dos alimentos.
- **Alternativas con otra cantidad:** "1 manzana ó 1 taza de fresas". Las
  que comparten cantidad ("pollo o res magra, 130 g") ya funcionaban dentro
  del nombre.

Esos renglones se importaban como un texto marcado para revisión: 11 de 32
en un plan real.

## Decisión

- **Dos columnas nuevas en `plan_items`** (versión 9 del esquema), las dos
  opcionales:
  - `parentItemId`: el plato al que pertenece un ingrediente;
  - `alternativeOfId`: el alimento del que es alternativa.

  Un renglón suelto deja las dos vacías, como siempre.
- **El borrador refleja la misma estructura:** `ItemDraft` tiene
  `ingredients` y `alternatives`. Al guardar se insertan en orden y quedan
  enlazados. Borrar un plato borra lo que lleva dentro.
- **El lector descompone el renglón:**
  - "X con *cantidad* …" es un plato. Lo que va en "X en *base*
    (*n* rebanadas)" es un ingrediente más.
  - "+" seguido de una cantidad separa alimentos.
  - "ó", "o" y "u" seguidos de una cantidad separan alternativas.
  - Solo se corta donde viene una cantidad. "Proteína mezclada con agua" o
    "pepino o jícama" siguen siendo un solo alimento.
  - El formato "Nombre: cantidad" sigue siendo siempre un solo alimento.
- **Unidades nuevas:** mililitros, tazas, cucharadas y cucharaditas. Se
  guardan por nombre, sin migración. Un rango ("30-40 g") toma el mínimo y
  guarda el rango en la nota.
- **Pantallas:** el plato se ve en negritas con sus ingredientes debajo, con
  sangría. Las alternativas se ven como "o 80 g de queso panela". En la
  revisión de la importación, cada uno se puede corregir o quitar por
  separado.

## Alternativas consideradas

- **Una tabla aparte para platos.** Es más formal, pero duplica lo que ya es
  un alimento (nombre, cantidad, estado) y complica la sincronización.
- **Guardar el renglón completo como texto y descomponerlo al mostrarlo.**
  Se pierde la posibilidad de corregir un ingrediente y de que los lotes de
  cocción encuentren "pechuga" dentro del sándwich.
- **Columnas obligatorias.** Los respaldos y las filas sincronizadas de
  versiones anteriores no las traen; opcionales, se leen sin cambios.

## Consecuencias

- Los lotes de cocción calculan cuánto servir también para los ingredientes
  de un plato y para las alternativas, porque siguen siendo alimentos.
- Con los planes reales disponibles, la alimentación del segundo formato
  pasó de 66 % a 100 % entendido sin revisión, y la del primero no cambió.
- Agregar un ingrediente a un plato a mano todavía no se puede desde la
  pantalla del plan; se corrige al importar o se agrega como alimento suelto.
