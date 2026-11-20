# ADR-0015: Catálogo de ejercicios, fotos bajo demanda y enlace por alias

- Estado: Aceptado
- Fecha: 2026-11-19

## Contexto

La Fase 4 pide un catálogo de ejercicios detrás de una interfaz con fuentes
intercambiables, con fotos de inicio y fin, y una forma de emparejar los
ejercicios de la rutina (en español) con el catálogo. La fuente inicial es
free-exercise-db (Unlicense): 876 ejercicios, 1 MB de datos y 99 MB de fotos,
con nombres e instrucciones en inglés.

## Decisión

### Datos: dentro de la app, traducidos

- El catálogo se incluye como recurso (`assets/catalog/exercises.json`,
  1.5 MB), armado por `tool/catalog/build_catalog.py` a partir de una versión
  fija del repositorio (`catalogCommit`).
- Nombres e instrucciones se tradujeron al español una sola vez, con un
  glosario común (`tool/catalog/glosario_traduccion.md`). Las traducciones
  viven en el repositorio (`translations_es.json`); el script falla si
  alguna no cuadra con su ejercicio (mismo id y mismo número de pasos).
- Una prueba valida cada ejercicio contra el `schema.json` original del
  proyecto, incluidos los campos opcionales (`force`, `mechanic`,
  `equipment`) que vienen nulos.
- El acceso es por la interfaz `ExerciseCatalog` (`getById`, `search`);
  `BundledExerciseCatalog` es la primera implementación.

### Fotos: descarga al verlas, con copia local (opción C)

- Se descargan de jsDelivr fijando la misma versión del repositorio, así que
  nunca cambian. No se usa raw.githubusercontent.
- Cada foto se guarda en Application Support la primera vez; después se lee
  del teléfono. "Descargar fotos de la rutina" guarda de una vez las de los
  ejercicios enlazados, para entrenar sin señal.
- Detrás de la interfaz `ExerciseImageStore`: el servidor propio de la etapa
  2 podrá reemplazar a jsDelivr sin tocar las pantallas.

### Enlace: sugerencia y confirmación manual

- `rankMatches` compara el nombre de la rutina con el nombre en español del
  catálogo y, traducido con un glosario de gimnasio, con el original en
  inglés. Puntúa por palabras compartidas (pesa más cubrir la búsqueda que el
  parecido total), con singulares en español, sinónimos ("jalón al mentón" =
  "remo al mentón"), el equipo a medio peso y penalizaciones por variantes
  contradictorias (plano frente a declinado, sentado frente a de pie).
- También iguala nombres distintos del mismo ejercicio antes de comparar
  ("pullover en polea" = jalón con brazos rectos, "remo en polea baja" = remo
  sentado en polea, "jalón de tríceps" = extensión de tríceps en polea) y
  toma el equipo del dato del catálogo, no solo del nombre. Barra y barra Z
  cuentan como cercanas, no como contradicción.
- **Nada se enlaza sin confirmación.** La revisión propone el mejor
  candidato con su foto; el usuario lo confirma o busca otro. Si el
  parecido es bajo, la pregunta lo dice ("No encontré uno igual").
- Cada confirmación guarda un **alias**: nombre normalizado → id del
  catálogo (tabla `exercise_aliases`, versión 7 del esquema). Un nombre se
  confirma una sola vez; un ejercicio nuevo con ese nombre hereda el enlace.
- **"No está en el catálogo"**: el alias guarda la marca `_propio` (ningún id
  del catálogo empieza con guion bajo, y no hace falta cambiar el esquema).
  El nombre deja de contarse como pendiente, pero el ejercicio no apunta a
  nada del catálogo. Así quedan, por ejemplo, el press California o la
  sentadilla sumo en máquina, que no están en ninguna base gratuita con
  fotos (se revisó también wger).

Medición con 46 nombres típicos de una rutina (prueba
`bundled_catalog_test.dart`): **100 % aparece entre las 3 primeras
sugerencias y 83 % en primer lugar** (antes de los sinónimos: 87 % y 69 % con
39 nombres). La prueba exige al menos 90 % y 70 %.

## Alternativas consideradas

**Todas las fotos dentro de la app.** Funciona sin internet desde el primer
día, pero suma 99 MB a una app que se reinstala cada semana por Wi-Fi.

**Fotos reducidas dentro de la app** (20–25 MB). Peor calidad y un proceso
para 1,746 fotos.

**Traducir en el teléfono** (framework de traducción de iOS). Gratis, pero
exige descargar modelos de idioma, código nativo y no se puede probar de
forma automática. Una traducción fija es determinista y revisable.

**Instrucciones en inglés.** Sin trabajo de traducción, pero el usuario las
quiere en español.

**Emparejar por distancia de caracteres** (Levenshtein, trigramas). Tolera
faltas de ortografía, pero no entiende que "mancuernas" y "dumbbell" son lo
mismo, ni el orden distinto de las palabras.

**Enlazar automáticamente las coincidencias muy seguras.** Más rápido, pero
un enlace equivocado pasa desapercibido; la confirmación manual cuesta un
toque por nombre y solo la primera vez.

## Consecuencias

- La primera vez que se ve un ejercicio hace falta internet para sus fotos.
- La calidad de la traducción depende de la revisión que se le haga; se
  puede corregir editando `translations_es.json` y volviendo a armar.
- El glosario y los sinónimos se amplían a medida que aparezcan nombres que
  no emparejan bien; la prueba de precisión avisa si un cambio empeora.
- Los alias entran en el respaldo.
- Al guardar una rutina importada desde PDF se abre directamente la revisión
  de enlaces; los nombres ya confirmados antes se enlazan solos.
