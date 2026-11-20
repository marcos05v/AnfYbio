import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';

/// Crea la aplicación con la misma configuración que usan las pruebas.
export async function createApp(): Promise<NestExpressApplication> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  configureApp(app);
  return app;
}

export function configureApp(app: NestExpressApplication): void {
  // Una subida trae hasta 500 filas; el límite por defecto (100 KB) no
  // alcanza.
  app.useBodyParser('json', { limit: '5mb' });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
}
