import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Prisma } from '@prisma/client';
import * as argon2 from 'argon2';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto, RegisterDto, Session } from './auth.dto';

/// Contenido del token: el id de la cuenta y su usuario.
export interface TokenPayload {
  sub: string;
  username: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  /// Hash con el que se compara cuando el usuario no existe, para que
  /// responder "no existe" tarde lo mismo que "contraseña incorrecta".
  private readonly dummyHash = argon2.hash('contraseña-que-nadie-usa', {
    type: argon2.argon2id,
  });

  async register(dto: RegisterDto): Promise<Session> {
    const passwordHash = await argon2.hash(dto.password, {
      type: argon2.argon2id,
    });
    try {
      const account = await this.prisma.account.create({
        data: { id: dto.userId, username: dto.username, passwordHash },
      });
      return this.session(account.id, account.username);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('Ese usuario o esa cuenta ya existe');
      }
      throw error;
    }
  }

  async login(dto: LoginDto): Promise<Session> {
    const account = await this.prisma.account.findUnique({
      where: { username: dto.username },
    });
    const valid = await argon2.verify(
      account?.passwordHash ?? (await this.dummyHash),
      dto.password,
    );
    if (!account || !valid) {
      // El mismo mensaje en los dos casos: no revela qué usuarios existen.
      throw new UnauthorizedException('Usuario o contraseña incorrectos');
    }
    return this.session(account.id, account.username);
  }

  private async session(userId: string, username: string): Promise<Session> {
    const payload: TokenPayload = { sub: userId, username };
    return { token: await this.jwt.signAsync(payload), userId, username };
  }
}
