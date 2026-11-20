# ADR-0018: Servidor con NestJS, Prisma y PostgreSQL, sin Docker

- Estado: Aceptado
- Fecha: 2026-11-19

## Contexto

El servidor corre en una MacBook Air con 8 GB de RAM y debe costar cero. El
documento del proyecto fija NestJS + TypeScript y PostgreSQL. Falta decidir
cómo hablar con la base de datos, cómo instalarla y cómo guardar las filas que
llegan del teléfono.

## Decisión

- **Prisma** para el acceso a datos y las migraciones: el esquema vive en un
  archivo legible (`prisma/schema.prisma`), genera tipos de TypeScript y
  migraciones en SQL versionadas en el repositorio.
- **PostgreSQL instalado con Homebrew**, sin Docker. Se enciende solo cuando se
  usa (`brew services start postgresql@17`) y consume unos 30 MB en reposo.
- **Las filas se guardan como documentos JSONB con sus columnas de
  sincronización aparte.** Una sola tabla `sync_rows` con: tabla de origen,
  id, `user_id`, `updated_at`, `deleted_at`, número de secuencia y la fila
  completa en `data`. Solo se aceptan nombres de tabla de una lista conocida.

### Por qué una tabla genérica y no una por cada tabla de la app

El servidor es un **relevo y respaldo**: no consulta ni calcula sobre los
entrenamientos, solo guarda y devuelve filas. La app tiene 22 tablas y su
esquema ya va en la versión 7. Copiarlas en el servidor obligaría a escribir
una migración del servidor por cada cambio de la app, y un teléfono con una
versión vieja rompería la sincronización. Con JSONB, el servidor no depende de
la forma de cada fila, y PostgreSQL puede consultarla con índices si algún día
hace falta.

## Alternativas consideradas

- **Una tabla de Postgres por cada tabla de la app.** Daría consultas
  relacionales en el servidor, pero el doble de esquemas que mantener al día.
  Conviene en la etapa 3 si el servidor llega a calcular estadísticas.
- **TypeORM.** Es el clásico de NestJS, pero sus tipos y migraciones son menos
  confiables.
- **Drizzle.** Es ligero y cercano a SQL, pero menos conocido.
- **Docker.** Es lo usual para Postgres, pero en 8 GB de RAM la máquina virtual
  de Docker Desktop consume de 2 a 4 GB por sí sola.

## Consecuencias

- Las pruebas de integración necesitan un PostgreSQL real: en la Mac es la
  base `anfybio_test`, y en GitHub Actions un contenedor de servicio, que
  corre en los servidores de GitHub y es gratis en repositorios públicos.
- El servidor no valida el contenido de cada fila, solo sus columnas de
  sincronización y su dueño. La validación de dominio sigue en la app.
- Se usa Prisma 6. `npm audit` marca dependencias de su herramienta de línea
  de comandos (`deepmerge-ts` y `effect`, dentro de `@prisma/config`), que
  solo leen la configuración local y no reciben datos de la red. Corregirlas
  exige Prisma 7, con otra forma de configurarse; queda como mejora.
