import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { checkRow, type CheckedRow, type SyncTable } from './sync-rules';
import type { PullResult, PushResult, PushRowDto } from './sync.dto';

@Injectable()
export class SyncService {
  constructor(private readonly prisma: PrismaService) {}

  /// Guarda las filas que llegan; en un conflicto gana el `updatedAt` más
  /// reciente (ADR-0016).
  async push(
    userId: string,
    rows: PushRowDto[],
    now = new Date(),
  ): Promise<PushResult> {
    const result: PushResult = { applied: 0, skipped: 0, rejected: [] };
    const accepted: CheckedRow[] = [];
    for (const row of rows) {
      const checked = checkRow(row.table, row.data, userId, now);
      if ('reason' in checked) {
        result.rejected.push({
          table: row.table,
          id: row.data.id,
          reason: checked.reason,
        });
      } else {
        accepted.push(checked);
      }
    }
    if (accepted.length === 0) return result;

    await this.prisma.$transaction(async (tx) => {
      // Una subida a la vez por cuenta: así los números de secuencia de una
      // cuenta se confirman en orden y una bajada nunca se salta uno.
      await tx.$queryRaw`SELECT 1 FROM pg_advisory_xact_lock(hashtext(${userId}))`;
      for (const row of accepted) {
        // Inserta o, si ya existe, reemplaza solo si es de la misma cuenta y
        // más reciente. Las fechas se pasan como texto para conservar los
        // microsegundos.
        const saved = await tx.$queryRaw<{ seq: bigint }[]>`
          INSERT INTO sync_rows (table_name, id, user_id, updated_at, deleted_at, data)
          VALUES (${row.table}, ${row.id}, ${userId}::uuid,
                  ${row.updatedAt}::timestamptz, ${row.deletedAt}::timestamptz,
                  ${JSON.stringify(row.data)}::jsonb)
          ON CONFLICT (table_name, id) DO UPDATE
          SET updated_at = EXCLUDED.updated_at,
              deleted_at = EXCLUDED.deleted_at,
              data = EXCLUDED.data,
              seq = nextval(pg_get_serial_sequence('sync_rows', 'seq'))
          WHERE sync_rows.user_id = EXCLUDED.user_id
            AND sync_rows.updated_at < EXCLUDED.updated_at
          RETURNING seq`;
        if (saved.length > 0) {
          result.applied++;
        } else {
          result.skipped++;
        }
      }
    });
    return result;
  }

  /// Las filas de la cuenta que cambiaron después de [since], en el orden en
  /// que el servidor las aceptó.
  async pull(
    userId: string,
    since: number,
    limit: number,
  ): Promise<PullResult> {
    const found = await this.prisma.$queryRaw<
      { table_name: SyncTable; data: Record<string, unknown>; seq: bigint }[]
    >`
      SELECT table_name, data, seq FROM sync_rows
      WHERE user_id = ${userId}::uuid AND seq > ${since}
      ORDER BY seq
      LIMIT ${limit + 1}`;
    const hasMore = found.length > limit;
    const page = found.slice(0, limit);
    return {
      rows: page.map((row) => ({ table: row.table_name, data: row.data })),
      next: page.length > 0 ? Number(page[page.length - 1]!.seq) : since,
      hasMore,
    };
  }
}
