# API de AnfYbio

Servidor de sincronización para la red de la casa (etapa 2): cada teléfono
sube sus cambios y baja los de sus otros dispositivos. La app sigue
funcionando sin él.

NestJS + TypeScript, Prisma y PostgreSQL, sin Docker
([ADR-0018](../../docs/adr/0018-servidor-nestjs-prisma-postgres.md)).

## Endpoints

| Método | Ruta | Para qué |
|---|---|---|
| `GET` | `/health` | Comprueba que la dirección es este servidor |
| `POST` | `/auth/register` | Crea la cuenta con el id del usuario del teléfono |
| `POST` | `/auth/login` | Inicia sesión; devuelve un token JWT de 30 días |
| `GET` | `/auth/me` | La cuenta del token |
| `POST` | `/sync/push` | Sube hasta 500 filas; gana el cambio más reciente |
| `GET` | `/sync/pull?since=N&limit=500` | Baja lo que cambió después de `N` |

Las reglas están en los ADRs:
[sincronización](../../docs/adr/0016-sincronizacion-ultimo-cambio-gana.md),
[cuentas](../../docs/adr/0017-cuentas-con-usuario-y-contrasena.md) y
[conexión en la red local](../../docs/adr/0019-conexion-en-la-red-local.md).

## Ponerlo a andar en la Mac

Requisitos: Node 22 o superior y PostgreSQL 17 de Homebrew.

```sh
brew install postgresql@17
brew services run postgresql@17      # lo enciende solo hasta reiniciar
createdb anfybio_dev
createdb anfybio_test

cd apps/api
npm install
cp .env.example .env                 # cambia TU_USUARIO y JWT_SECRET
npm run db:deploy                    # crea las tablas
npm run build && npm start           # escucha en el puerto 4310
```

Para comprobarlo desde otro equipo de la casa:

```sh
curl http://$(scutil --get LocalHostName).local:4310/health
```

Para apagar PostgreSQL: `brew services stop postgresql@17`.

## Pruebas

```sh
npm test            # unitarias (reglas de sincronización)
npm run test:e2e    # integración contra la base anfybio_test
```

Las de integración corren contra un PostgreSQL real; se niegan a usar una base
cuyo nombre no termine en `_test`. En GitHub Actions usan un contenedor de
servicio.

## Seguridad en esta etapa

- Contraseñas con argon2id; el inicio de sesión responde igual si el usuario
  no existe o si la contraseña es incorrecta.
- HTTP sin cifrar, pensado solo para la red de la casa. HTTPS llega con la
  etapa 3 (ADR-0019).
- Sin límite de intentos de inicio de sesión: aceptable en una red privada,
  obligatorio antes de exponer el servidor a internet.
