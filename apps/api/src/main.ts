import { createApp } from './app';

async function bootstrap(): Promise<void> {
  try {
    // Lee .env si existe (Node 22+, sin paquetes extra).
    process.loadEnvFile();
  } catch {
    // Sin .env: se usan las variables del sistema.
  }
  const app = await createApp();
  const port = Number(process.env.PORT ?? 4310);
  // 0.0.0.0: escucha en toda la red de la casa, no solo en la Mac
  // (ADR-0019).
  await app.listen(port, '0.0.0.0');
  console.log(`AnfYbio API escuchando en el puerto ${port}`);
}

void bootstrap();
