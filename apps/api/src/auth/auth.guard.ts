import {
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import type { TokenPayload } from './auth.service';

type AuthedRequest = Request & { account?: TokenPayload };

/// Exige un token válido en `Authorization: Bearer …` (ADR-0017).
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthedRequest>();
    const [scheme, token] = request.headers.authorization?.split(' ') ?? [];
    if (scheme !== 'Bearer' || !token) {
      throw new UnauthorizedException('Falta iniciar sesión');
    }
    try {
      request.account = await this.jwt.verifyAsync<TokenPayload>(token);
    } catch {
      throw new UnauthorizedException('La sesión no es válida o ya venció');
    }
    return true;
  }
}

/// La cuenta del token, en un controlador protegido por [AuthGuard].
export const CurrentAccount = createParamDecorator(
  (_: unknown, context: ExecutionContext): TokenPayload => {
    const request = context.switchToHttp().getRequest<AuthedRequest>();
    return request.account!;
  },
);
