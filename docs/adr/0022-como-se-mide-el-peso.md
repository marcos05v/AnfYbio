# ADR-0022: Cómo se mide el peso de cada ejercicio

- Estado: Aceptado
- Fecha: 2026-11-19

## Contexto

El mismo número significa cosas distintas según el ejercicio:

- En press militar en Smith, "40 kg" es todo lo que se levanta.
- En press Arnold, "20 kg" es cada mancuerna, es decir, 40 en total.
- En la prensa se suelen contar los discos de un lado.
- En dominadas se anota el lastre, no el peso corporal.

Hasta ahora la app guardaba solo el número y la unidad. El 1RM y su gráfica
se calculan por ejercicio, así que la tendencia era correcta mientras el
usuario anotara siempre igual. Pero nada se lo recordaba, y un cálculo futuro
de volumen total o la comparación entre ejercicios saldrían mal.

## Decisión

- Cada ejercicio guarda **cómo se mide** (`loadMode`): total, por mancuerna,
  por lado o peso corporal más lastre. Es una columna nueva y opcional en
  `exercises` (versión 8 del esquema).
- **El peso de cada serie se guarda tal como se anotó**, sin convertirlo
  (ADR-0002: hechos, no derivados). El total se calcula cuando hace falta
  (`totalLoadKg`): por mancuerna y por lado valen el doble, y el peso
  corporal necesita conocer cuánto pesa la persona.
- **Mientras el usuario no elija**, se deduce del equipo que indica el
  catálogo (ADR-0015): mancuernas o pesa rusa → por mancuerna; peso corporal
  → lastre; lo demás → total. Al guardar la primera serie, la forma de medir
  queda registrada como dato del usuario y deja de depender del catálogo.
- **La forma de medir siempre se ve**:
  - en la serie: "20 kg c/u × 10";
  - en el 1RM: "1RM ≈ 26 kg c/u";
  - en el formulario: "Peso c/u", "Lastre";
  - y en la explicación de la gráfica de progreso.

## Alternativas consideradas

- **Convertir y guardar siempre el total.** Se perdería lo que el usuario
  realmente anotó, el número no coincidiría con lo que ve en el gimnasio, y
  un error al elegir la forma de medir alteraría los datos guardados.
- **Decidirlo solo por el catálogo, sin guardar.** Cambiar el enlace del
  catálogo cambiaría el significado del historial.
- **Columna obligatoria con valor por defecto.** Los respaldos y las filas
  sincronizadas de versiones anteriores no traen el campo; una columna
  opcional los lee sin cambios.

## Consecuencias

- El progreso de cada ejercicio no cambia: compara siempre el mismo tipo de
  número.
- Cambiar la forma de medir de un ejercicio cambia cómo se lee todo su
  historial. Es lo correcto si se eligió mal; si de verdad se cambió la forma
  de registrar, conviene crear otro ejercicio.
- En máquinas por lado, el total no incluye el peso del carro.
