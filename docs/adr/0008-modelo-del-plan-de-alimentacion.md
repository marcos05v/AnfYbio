# ADR-0008: Modelo del plan de alimentación

- Estado: Aceptado
- Fecha: 2026-11-16

## Contexto

La Fase 2 parte del plan que entrega la nutrióloga, siempre en PDF. Al revisar
un plan real se vio que:

- trae dos menús distintos, uno para días de entrenamiento y otro para días de
  descanso, con comidas y nombres diferentes en cada uno;
- expresa las cantidades en gramos, piezas, scoops o "libre", y a veces sin
  unidad;
- indica si se pesa en crudo, cocido o seco solo en algunos alimentos, más una
  regla general en texto al inicio;
- ofrece alternativas en el mismo renglón ("pollo o res magra");
- **no usa el Sistema Mexicano de Alimentos Equivalentes**, que el alcance
  original daba por supuesto;
- incluye una guía de suplementos con dosis, momento de toma y beneficio.

## Decisión

El plan se guarda con la misma forma que tiene en papel:

```
plan → menú (entrenamiento | descanso) → comida → alimento
plan → suplemento de la guía
```

- **El alimento conserva el nombre tal como viene**, alternativas incluidas.
  Las opciones se obtienen partiendo ese texto (`foodOptions`), sin tabla
  propia y sin catálogo de alimentos.
- **El estado de pesaje puede quedar "sin especificar".** La app no aplica la
  regla general por su cuenta: decidir si "atún" es proteína cruda es justo
  donde una regla automática falla. Lo indica el usuario.
- **Cantidad y unidad son opcionales**, y "libre" es una marca aparte.
- **Un solo plan activo por usuario.** Guardar un plan nuevo desactiva el
  anterior, que se conserva.
- **El menú del día** es el de entrenamiento si hoy hay una sesión registrada y
  el de descanso si no; el usuario puede cambiarlo a mano, y esa elección vale
  solo para ese día.
- **La guía de suplementos es texto de consulta.** El inventario y los
  recordatorios son de la Fase 3.

Todas las tablas siguen las reglas del ADR-0002. Es la primera ampliación del
esquema (versión 2): la migración solo crea tablas, y una prueba comprueba con
una copia del esquema anterior que los datos existentes se conservan.

## Alternativas consideradas

**Catálogo de alimentos con equivalentes.** Permitiría sustituciones
calculadas. Se descartó porque el plan real no trae equivalentes: habría que
inventar datos que la nutrióloga no dio. Las sustituciones serán las
alternativas que ella escribe.

**Una tabla de opciones por alimento.** Modela las alternativas de forma
explícita. Se pospuso: mientras nadie registre cuál opción comió, partir el
texto basta, y agregar la tabla después no obliga a migrar datos.

**Un solo menú con variaciones por tipo de día.** Menos filas. Se descartó
porque los dos menús del plan real no comparten estructura.

**Aplicar automáticamente la regla general de pesaje.** Menos captura. Se
descartó por el riesgo de mostrar un gramaje en el estado equivocado, que es un
error con consecuencias reales en la porción servida.

## Consecuencias

- La captura manual y la futura lectura del PDF producen el mismo borrador
  (`NutritionPlanDraft`) y se guardan por el mismo camino.
- Sin catálogo, la app no calcula calorías ni macronutrientes.
- El plan entra en el respaldo; los respaldos anteriores a esta versión se
  siguen pudiendo restaurar.
