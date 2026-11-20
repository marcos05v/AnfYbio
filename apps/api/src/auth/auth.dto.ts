import { Transform } from 'class-transformer';
import {
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

const lower = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toLowerCase() : value;

export class LoginDto {
  /// Minúsculas, números, punto, guion y guion bajo; de 3 a 30.
  @Transform(lower)
  @Matches(/^[a-z0-9._-]{3,30}$/, {
    message:
      'El usuario lleva de 3 a 30 letras, números, punto, guion o guion bajo',
  })
  username: string;

  @IsString()
  @MinLength(8, { message: 'La contraseña lleva al menos 8 caracteres' })
  @MaxLength(200)
  password: string;
}

export class RegisterDto extends LoginDto {
  /// El id del usuario local en el teléfono (ADR-0017).
  @IsUUID('all', { message: 'userId debe ser un UUID' })
  userId: string;
}

export interface Session {
  token: string;
  userId: string;
  username: string;
}
