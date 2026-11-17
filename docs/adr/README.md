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

## Decisiones abiertas

- Estrategia de sincronización y resolución de conflictos.
- Autenticación.
- Almacenamiento de imágenes del catálogo.
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
