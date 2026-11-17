# ADR-0012: El día de rutina que toca se decide por el día de la semana

- Estado: Aceptado
- Fecha: 2026-11-16
- Reemplaza la regla del "día que toca" del ADR-0010.

## Contexto

El ADR-0010 sugería como día de rutina el siguiente al de la última sesión
registrada. Con el uso real resultó poco natural: la rutina se piensa por
semana ("el lunes toca pecho"), y esa regla se desfasaba si un día no se
registraba la sesión.

## Decisión

El día que toca sale del día de la semana: **lunes = Día 1, martes = Día 2**,
y así sucesivamente. Los días de la semana que sobran son de descanso (con una
rutina de seis días, el domingo).

El usuario puede corregirlo: al elegir a mano qué día toca hoy, la app guarda
en qué día de la semana cae el Día 1 y recorre los demás. Es una preferencia
del dispositivo (como la apariencia), no un dato de la base.

Sigue siendo una sugerencia: al iniciar una sesión se puede elegir cualquier
día, o una sesión libre.

## Alternativas consideradas

**Seguir con "el siguiente al último hecho".** No se desfasa si se entrena en
días irregulares. Se descartó porque no coincide con la forma en que el
usuario organiza su semana, y era la queja concreta.

**Asignar cada día de la rutina a un día de la semana, uno por uno.** Permite
descansos intercalados (lunes, martes, jueves…). Se pospuso: exige una
pantalla de configuración que hoy no hace falta, y el modelo actual se puede
ampliar a eso sin migrar datos.

## Consecuencias

- La tarjeta del inicio no depende de lo que ya se registró: muestra lo mismo
  todo el día.
- Si se salta un día, la app no lo "arrastra" al siguiente; el usuario elige
  qué hacer.
- Los descansos quedan siempre al final de la semana de la rutina.
- Una rutina de más de siete días no cabe en este esquema: solo se sugerirían
  los siete primeros.
