# AnfYbio

App móvil de entrenamiento y nutrición para atleta híbrido: fuerza
(culturismo/powerbuilding) y resistencia (natación, carrera, apnea).

Proyecto de portafolio y de uso diario. La prioridad es la calidad de ingeniería
(modelado de datos, diseño de API, pruebas y decisiones justificadas) por encima
de la cantidad de funciones.

## Estado

**Fases 1, 2 y 3 completas.**

- Fase 1 — Entrenamiento: registro, edición y borrado de sesiones de fuerza,
  natación, carrera y apnea; 1RM estimado con gráficas por ejercicio; carga
  sRPE con resumen semanal; respaldo y restauración en un archivo JSON; modo
  claro y oscuro.
- Fase 2 — Nutrición: plan de alimentación con menús por tipo de día, captura
  manual o importación desde PDF con revisión, guía de suplementos, y lotes de
  cocción que convierten las porciones del plan de crudo a cocido.
- Fase 3 — Suplementos: inventario por presentación (pastillas, polvo u otra)
  con compras, tomas y ajustes; días restantes y fecha en que se acaba;
  adherencia; recordatorio diario de toma y aviso de reabastecimiento como
  notificaciones locales.
- Adelantado de la Fase 4: rutina de entrenamiento (manual o importada desde
  PDF) y sesiones de fuerza que siguen el día que toca según el día de la
  semana.

Las sustituciones del plan son las alternativas que escribe la nutrióloga en
cada renglón; no hay catálogo de equivalentes (ADR-0008).

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Entrenamiento: fuerza, natación, carrera, apnea, carga sRPE, exportación | Completa |
| 2 | Nutrición: plan alimenticio, lotes de cocción, sustituciones | Completa |
| 3 | Suplementos: inventario, recordatorios, adherencia | Completa |
| 4 | Catálogo de ejercicios e importación desde PDF | Pendiente |

## Principios

- **Local-first.** La app funciona completa con su base de datos local. La
  sincronización con el servidor es opcional y llega después.
- **Costo cero.** Ningún servicio de pago.
- **iOS primero.** El código Flutter queda multiplataforma; Android está fuera
  de alcance por ahora.

## Estructura del repositorio

```
apps/mobile/   App Flutter (iOS)
apps/api/      API NestJS (llega en la etapa 2; hoy solo un README)
infra/         Scripts de infraestructura (Postgres, despliegue)
docs/adr/      Registro de decisiones de arquitectura
```

## Cómo correr la app

Requisitos: Flutter 3.47 o superior, Xcode y un iPhone conectado.

```sh
cd apps/mobile
flutter pub get
flutter run
```

Con una cuenta gratuita de Apple la firma caduca cada 7 días. Para renovarla se
vuelve a ejecutar `flutter run` sobre la app ya instalada, **sin borrarla**: así
se conservan los datos locales.

## Pruebas

```sh
cd apps/mobile
flutter analyze
flutter test
```

## Decisiones

Las decisiones técnicas se registran en [docs/adr](docs/adr/README.md).
