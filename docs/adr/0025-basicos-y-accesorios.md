# ADR-0025: Ejercicios básicos y accesorios, con su descanso

- Estado: Aceptado
- Fecha: 2026-11-23

## Contexto

Las rutinas piden descansos distintos según el tipo de ejercicio ("2–3 min
en básicos/compuestos pesados y 60–90 seg en accesorios"), pero no marcan
qué ejercicio es de qué tipo. El usuario tenía que deducirlo cada vez.

## Decisión

- Cada ejercicio de la rutina es **básico** (compuesto, varias
  articulaciones) o **accesorio** (aislamiento, una articulación).
- **Se deduce del nombre** con listas de palabras (`exerciseRoleFor`).
  Primero se buscan las de accesorio, porque son más específicas ("press
  francés", "curl femoral"). Calentamiento, cardio y activación no tienen
  tipo. Si el nombre no lo deja claro, no se adivina.
- **El usuario puede corregirlo** en el formulario del ejercicio. Se guarda
  en `routine_exercises.role` (esquema v11). Nulo significa que se deduce
  al mostrarse, así que si mejora la deducción, mejora también en las
  rutinas ya guardadas.
- **El descanso sale de las indicaciones generales del plan** si las trae
  ("X–Y min en básicos", "Z seg en accesorios"). Si no, se usan 2–3 min
  para básicos y 60–90 s para accesorios.
- En una biserie, el descanso se muestra solo en el último ejercicio,
  porque se descansa al terminar la vuelta.

## Consecuencias

- La deducción es por palabras y en español e inglés. Un nombre que no
  reconoce se queda sin etiqueta, y el usuario puede asignarla.
- No hay temporizador de descanso. Si se agrega uno, puede usar
  `restFor` tal cual.
