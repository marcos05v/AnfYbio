# AnfYbio

App móvil de entrenamiento y nutrición para atleta híbrido: fuerza
(culturismo/powerbuilding) y resistencia (natación, carrera, apnea).

Proyecto de portafolio y de uso diario. La prioridad es la calidad de ingeniería
(modelado de datos, diseño de API, pruebas y decisiones justificadas) por encima
de la cantidad de funciones.

## Estado

**Las cuatro fases del alcance están completas**, y también la etapa 2 del
servidor: la app sincroniza con una API en la Mac a través del Wi-Fi de la
casa (Ajustes → Servidor).

- Fase 1 — Entrenamiento: registro, edición y borrado de sesiones de fuerza,
  natación, carrera y apnea; 1RM estimado con gráficas por ejercicio; carga
  sRPE con resumen semanal; respaldo y restauración en un archivo JSON; modo
  claro y oscuro.
- Fase 2 — Nutrición: plan de alimentación con menús por tipo de día, captura
  manual o importación desde PDF con revisión, guía de suplementos, y lotes de
  cocción que convierten las porciones del plan de crudo a cocido.
- Fase 3 — Suplementos: inventario por presentación (pastillas, polvo u otra)
  con compras, tomas y ajustes; días restantes y fecha en que se acaba;
  adherencia; recordatorio diario de toma (con botón "Ya lo tomé" y sonido
  propio) y aviso de reabastecimiento como notificaciones locales.
- Fase 4 — Catálogo e importación: rutina de entrenamiento (manual o
  importada desde PDF) con sesiones que siguen el día que toca; catálogo de
  876 ejercicios (free-exercise-db) traducido al español, con fotos animadas
  que se descargan al verlas; enlace de la rutina con el catálogo por
  sugerencia y confirmación manual, que se recuerda con alias. El plan de
  alimentación se importa con un lector propio en lugar de un modelo de IA
  (ADR-0009).

Las sustituciones del plan son las alternativas que escribe la nutrióloga en
cada renglón; no hay catálogo de equivalentes (ADR-0008).

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Entrenamiento: fuerza, natación, carrera, apnea, carga sRPE, exportación | Completa |
| 2 | Nutrición: plan alimenticio, lotes de cocción, sustituciones | Completa |
| 3 | Suplementos: inventario, recordatorios, adherencia | Completa |
| 4 | Catálogo de ejercicios e importación desde PDF | Completa |

| Etapa del servidor | Contenido | Estado |
|---|---|---|
| 1 | Sin servidor: todo en el teléfono | Completa |
| 2 | API en la Mac (NestJS + PostgreSQL), sincronización en la red local | Completa |
| 3 | Nube con plan gratuito, solo si hace falta | Pendiente de ADR |

## Principios

- **Local-first.** La app funciona completa con su base de datos local. La
  sincronización con el servidor es opcional y llega después.
- **Costo cero.** Ningún servicio de pago.
- **iOS primero.** El código Flutter queda multiplataforma; Android está fuera
  de alcance por ahora.

## Estructura del repositorio

```
apps/mobile/   App Flutter (iOS)
apps/api/      API de sincronización: NestJS + Prisma + PostgreSQL
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
vuelve a ejecutar `flutter run --release` sobre la app ya instalada, **sin
borrarla**: así se conservan los datos locales. Cómo instalarla en otro iPhone
y cómo renovarla sola: [docs/instalar-en-iphone.md](docs/instalar-en-iphone.md).

## Cómo correr la API

Ver [apps/api/README.md](apps/api/README.md).

## Pruebas

```sh
cd apps/mobile
flutter analyze
flutter test

cd ../api
npm test           # unitarias
npm run test:e2e   # integración, contra PostgreSQL real
```

## Decisiones

Las decisiones técnicas se registran en [docs/adr](docs/adr/README.md).
