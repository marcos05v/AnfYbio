import { execSync } from 'node:child_process';
import './env';

/// Deja la base de pruebas con el esquema al día antes de correr las
/// pruebas. Se niega a tocar una base que no termine en _test.
export default function globalSetup(): void {
  const url = process.env.DATABASE_URL!;
  if (!new URL(url).pathname.endsWith('_test')) {
    throw new Error(`Las pruebas solo corren contra una base *_test: ${url}`);
  }
  execSync('npx prisma migrate deploy', {
    stdio: 'inherit',
    env: process.env,
  });
}
