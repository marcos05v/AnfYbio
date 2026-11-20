import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { AuthGuard } from './auth.guard';
import { AuthService } from './auth.service';

/// La clave para firmar tokens; sin ella (o si es corta) el servidor no
/// arranca, en lugar de firmar con algo adivinable.
export function jwtSecret(): string {
  const secret = process.env.JWT_SECRET ?? '';
  if (secret.length < 32) {
    throw new Error(
      'JWT_SECRET falta o es muy corta (mínimo 32 caracteres). ' +
        'Genera una con: openssl rand -base64 48',
    );
  }
  return secret;
}

@Module({
  imports: [
    JwtModule.registerAsync({
      global: true,
      useFactory: () => ({
        secret: jwtSecret(),
        signOptions: { expiresIn: '30d' },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, AuthGuard],
  exports: [AuthGuard],
})
export class AuthModule {}
