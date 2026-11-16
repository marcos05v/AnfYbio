# ADR-0001: Un solo repositorio para app, API e infraestructura

- Estado: Aceptado
- Fecha: 2026-11-16

## Contexto

El proyecto tiene tres partes: la app móvil (Flutter), una API de sincronización
(NestJS) que llegará en una etapa posterior, e infraestructura. Lo desarrolla
una sola persona. Varias decisiones pendientes (sincronización, conflictos,
autenticación) afectan a la app y a la API al mismo tiempo.

## Decisión

Un solo repositorio de git con cada parte en su carpeta: `apps/mobile`,
`apps/api`, `infra` y `docs`. Cada app conserva sus propias dependencias y
comandos; lo único compartido es el historial de git.

## Alternativas consideradas

**Dos repositorios (app y API) clonados lado a lado.** Da un historial limpio
por proyecto y un CI más simple en cada uno. Se descartó porque:

- Un cambio en el contrato de sincronización tocaría ambos repos con commits
  coordinados a mano, y nada avisaría si quedan en versiones incompatibles.
- Los ADR, el README general y la infraestructura no tendrían un lugar natural.
- Su ventaja real (equipos, permisos y ritmos de despliegue distintos) no aplica
  a un proyecto de una persona.

## Consecuencias

- Un cambio que cruza app y API cabe en un solo commit y un solo PR.
- El CI necesitará filtros por ruta para no ejecutar las pruebas de la API
  cuando solo cambia la app, y viceversa.
- El historial mezcla ambos proyectos; se filtra por carpeta cuando haga falta.
- No se usa ninguna herramienta de monorepo (Melos, Nx, Turborepo): con dos apps
  en lenguajes distintos no hay código compartido que la justifique.
