# ADR-0017: Cuentas con usuario y contraseña, y token JWT

- Estado: Aceptado
- Fecha: 2026-11-19

## Contexto

El servidor guarda los datos de varias personas (el usuario y su hermana, cada
una con su teléfono). Necesita saber quién sincroniza para que nadie lea ni
sobrescriba datos ajenos.

## Decisión

- **Registro e inicio de sesión con usuario y contraseña** desde la app.
- **La contraseña se guarda con argon2id**, el algoritmo recomendado hoy por
  OWASP. Nunca se guarda ni se registra en claro.
- **El servidor entrega un token JWT** firmado con una clave que solo vive en
  la Mac (`.env`, fuera del repositorio). El teléfono lo manda en cada
  sincronización. Dura 30 días; al vencer, se vuelve a iniciar sesión.
- **La cuenta usa el mismo id que el usuario local.** Al registrarse, el
  teléfono envía su id (UUID, ADR-0002) y la cuenta lo adopta, así las filas
  que ya existen no cambian de dueño. En una instalación nueva, iniciar sesión
  devuelve ese id y la app baja todo.

## Alternativas consideradas

- **Emparejar con un código de 6 dígitos.** Es más cómodo, pero es un esquema
  propio, menos común y más difícil de defender en una revisión de código.
- **Token de actualización (refresh token) además del de acceso.** Es lo
  correcto en un servicio público. En una red de casa con dos usuarios, un
  token de 30 días es suficiente y mucho más simple. Se agrega si el servidor
  sale a internet (etapa 3).
- **bcrypt.** Sigue siendo aceptable, pero argon2id resiste mejor ataques con
  GPU y es el recomendado para proyectos nuevos.

## Consecuencias

- Si roban el teléfono con la sesión abierta, el token sirve hasta que venza.
  Se mitiga porque el servidor solo existe en la red de la casa.
- Cambiar la clave de firma cierra todas las sesiones.
