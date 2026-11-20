import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { syncTables, type SyncTable } from './sync-rules';

export class PushRowDto {
  @IsIn(syncTables, { message: 'Tabla desconocida' })
  table: SyncTable;

  /// La fila completa, como la guarda el teléfono.
  @IsObject()
  data: Record<string, unknown>;
}

/// Máximo de filas por subida; el teléfono manda el resto en otras.
export const maxPushRows = 500;

export class PushDto {
  @IsArray()
  @ArrayMaxSize(maxPushRows)
  @ValidateNested({ each: true })
  @Type(() => PushRowDto)
  rows: PushRowDto[];
}

export class PullQueryDto {
  /// El último número de secuencia que el teléfono ya tiene.
  @Type(() => Number)
  @IsInt()
  @Min(0)
  since = 0;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1000)
  limit = 500;
}

export interface PushResult {
  /// Filas guardadas (eran nuevas o más recientes que las del servidor).
  applied: number;
  /// Filas ignoradas: el servidor ya tenía una versión igual o más nueva.
  skipped: number;
  rejected: { table: string; id: unknown; reason: string }[];
}

export interface PullResult {
  rows: { table: SyncTable; data: Record<string, unknown> }[];
  /// Número a mandar como `since` en la siguiente petición.
  next: number;
  hasMore: boolean;
}
