# Registro de decisiones de arquitectura (ADR)

Cada decisión técnica relevante se documenta en un archivo breve: qué se
decidió, qué alternativas había y por qué se eligió esa.

Un ADR aceptado no se reescribe. Si la decisión cambia, se crea un ADR nuevo que
lo reemplaza y el anterior se marca como "Reemplazado por ADR-XXXX".

## Índice

| ADR | Decisión | Estado |
|---|---|---|
| [0001](0001-monorepo.md) | Un solo repositorio para app, API e infraestructura | Aceptado |
| [0002](0002-modelo-de-datos-listo-para-sincronizar.md) | Reglas del modelo de datos para soportar sincronización | Aceptado |
| [0003](0003-base-de-datos-local-drift.md) | drift como base de datos local; UUID v7 guardados como texto | Aceptado |
| [0004](0004-riverpod-para-el-manejo-de-estado.md) | Riverpod para el manejo de estado | Aceptado |
| [0005](0005-respaldo-en-json.md) | Respaldo de datos en un archivo JSON versionado | Aceptado |
| [0006](0006-fl-chart-para-las-graficas.md) | fl_chart para las gráficas | Aceptado |
| [0007](0007-importar-solo-en-instalacion-nueva.md) | Un respaldo solo se restaura en una instalación sin datos | Aceptado |
| [0008](0008-modelo-del-plan-de-alimentacion.md) | Modelo del plan de alimentación | Aceptado |
| [0009](0009-lectura-del-plan-desde-pdf.md) | Lectura del plan desde PDF con PDFKit y un intérprete propio | Aceptado |
| [0010](0010-rutina-de-entrenamiento.md) | Rutina de entrenamiento y sesiones que la siguen | Aceptado; el "día que toca" lo reemplaza el ADR-0012 |
| [0011](0011-lotes-de-coccion.md) | Lotes de cocción y conversión de crudo a cocido | Aceptado |
| [0012](0012-dia-de-rutina-por-dia-de-la-semana.md) | El día de rutina que toca se decide por el día de la semana | Aceptado |
| [0013](0013-inventario-de-suplementos.md) | Inventario de suplementos | Aceptado |
| [0014](0014-notificaciones-locales.md) | Notificaciones locales para tomas y reabastecimiento | Aceptado |
| [0015](0015-catalogo-de-ejercicios.md) | Catálogo de ejercicios, fotos bajo demanda y enlace por alias | Aceptado |
| [0016](0016-sincronizacion-ultimo-cambio-gana.md) | Sincronización por filas, gana el último cambio | Aceptado |
| [0017](0017-cuentas-con-usuario-y-contrasena.md) | Cuentas con usuario y contraseña, y token JWT | Aceptado |
| [0018](0018-servidor-nestjs-prisma-postgres.md) | Servidor con NestJS, Prisma y PostgreSQL, sin Docker | Aceptado |
| [0019](0019-conexion-en-la-red-local.md) | Conexión en la red de la casa por nombre `.local` | Aceptado |
| [0020](0020-sincronizacion-en-la-app.md) | Sincronización en la app | Aceptado |
| [0021](0021-lectura-tolerante-de-planes.md) | Lectura tolerante de planes y revisión con planes reales | Aceptado |
| [0022](0022-como-se-mide-el-peso.md) | Cómo se mide el peso de cada ejercicio | Aceptado |
| [0023](0023-platos-y-alternativas-del-plan.md) | Platos con ingredientes y alternativas con su propia cantidad | Aceptado |

## Decisiones abiertas

- Estrategia de sincronización y resolución de conflictos.
- Autenticación.
- Hosting gratuito en la nube.

## Plantilla

```markdown
# ADR-NNNN: Título

- Estado: Propuesto | Aceptado | Reemplazado por ADR-XXXX
- Fecha: AAAA-MM-DD

## Contexto
Qué problema hay y qué restricciones aplican.

## Decisión
Qué se decidió, en una o dos frases.

## Alternativas consideradas
Cada alternativa y por qué se descartó.

## Consecuencias
Qué se gana, qué se pierde y qué queda pendiente.
```
