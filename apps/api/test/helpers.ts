import type { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { configureApp } from '../src/app';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

export async function createTestApp(): Promise<NestExpressApplication> {
  const moduleRef = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();
  const app = moduleRef.createNestApplication<NestExpressApplication>({
    logger: false,
  });
  configureApp(app);
  await app.init();
  return app;
}

/// Borra todo entre pruebas.
export async function resetDatabase(
  app: NestExpressApplication,
): Promise<void> {
  await app
    .get(PrismaService)
    .$executeRawUnsafe('TRUNCATE accounts, sync_rows RESTART IDENTITY CASCADE');
}

let counter = 0;

/// Un UUID v7 de prueba distinto cada vez.
export function uuid(): string {
  counter++;
  return `0193a1b2-0000-7000-8000-${counter.toString(16).padStart(12, '0')}`;
}

/// Registra una cuenta y devuelve su id y su token.
export async function signUp(
  app: NestExpressApplication,
  username = `persona${counter + 1}`,
): Promise<{ userId: string; token: string }> {
  const userId = uuid();
  const response = await request(app.getHttpServer())
    .post('/auth/register')
    .send({ userId, username, password: 'contraseña-segura' })
    .expect(201);
  return { userId, token: response.body.token };
}
