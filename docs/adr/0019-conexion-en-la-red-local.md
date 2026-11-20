# ADR-0019: Conexión en la red de la casa por nombre `.local`

- Estado: Aceptado
- Fecha: 2026-11-19

## Contexto

El teléfono tiene que encontrar a la Mac en el Wi-Fi de la casa. El router
asigna las IP y puede cambiarlas.

## Decisión

- **La app se conecta al nombre Bonjour de la Mac** (por ejemplo,
  `MacBook-Air-de-Marcos.local:4310`). macOS lo anuncia solo, sin instalar
  nada, y sigue funcionando aunque cambie la IP. Si falla, en Ajustes se puede
  escribir la IP.
- **HTTP sin cifrar, solo dentro de la red local.** iOS bloquea HTTP por
  defecto; se habilita únicamente para direcciones locales con
  `NSAllowsLocalNetworking`, no para internet.
- **El servidor escucha en el puerto 4310**, poco usado: el 3000 lo ocupan
  muchos servidores de desarrollo (Next.js, por ejemplo) que pueden estar
  corriendo en la misma Mac. Para no confundirse con otro servidor, la app
  verifica que `GET /health` responda `service: anfybio`.
- La app pide el permiso de "Red local" que iOS exige para hablar con otros
  equipos de la casa.

## Alternativas consideradas

- **Escribir la IP a mano.** Es lo más simple, pero se rompe cuando el router
  cambia la IP.
- **Descubrimiento automático con mDNS desde la app.** Encontraría el servidor
  sin escribir nada, pero agrega un paquete nativo y permisos de Bonjour; el
  nombre `.local` resuelve casi lo mismo sin código extra.
- **HTTPS con certificado propio.** Cifraría el tráfico, pero iOS exige
  instalar y confiar el certificado a mano en cada teléfono. Se hará en la
  etapa 3, si el servidor sale a internet, donde sí es obligatorio.

## Consecuencias

- En una red ajena (un café, por ejemplo) alguien podría ver el tráfico. La
  app solo sincroniza con la dirección que el usuario configuró.
- La contraseña viaja sin cifrar dentro de la casa al iniciar sesión. Se
  acepta en esta etapa y se resuelve con HTTPS en la etapa 3.
