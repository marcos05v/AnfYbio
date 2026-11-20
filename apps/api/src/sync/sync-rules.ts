/// Tablas de la app que se sincronizan, con los mismos nombres del respaldo
/// JSON (ADR-0005). Cualquier otra se rechaza.
export const syncTables = [
  'users',
  'exercises',
  'sessions',
  'strengthSets',
  'swimDetails',
  'swimIntervals',
  'swimLaps',
  'runDetails',
  'apneaAttempts',
  'nutritionPlans',
  'planMenus',
  'planMeals',
  'planItems',
  'supplementGuidelines',
  'routines',
  'routineDays',
  'routineExercises',
  'cookingBatches',
  'supplements',
  'supplementPurchases',
  'supplementIntakes',
  'exerciseAliases',
] as const;

export type SyncTable = (typeof syncTables)[number];

/// Fecha ISO 8601 con zona, con hasta microsegundos (así las escribe Dart).
const isoDate =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$/;

/// Cuánto se tolera que el reloj del teléfono vaya adelantado (ADR-0016).
export const maxClockSkewMs = 5 * 60 * 1000;

/// Una fila lista para guardarse: sus columnas de sincronización, sacadas de
/// la fila misma.
export interface CheckedRow {
  table: SyncTable;
  id: string;
  updatedAt: string;
  deletedAt: string | null;
  data: Record<string, unknown>;
}

/// Revisa una fila que llega del teléfono. Devuelve la fila lista para
/// guardarse o el motivo por el que se rechaza.
export function checkRow(
  table: SyncTable,
  data: Record<string, unknown>,
  userId: string,
  now: Date,
): CheckedRow | { reason: string } {
  const { id, updatedAt, deletedAt } = data;
  if (typeof id !== 'string' || id.length === 0 || id.length > 64) {
    return { reason: 'La fila no tiene un id válido' };
  }
  if (typeof updatedAt !== 'string' || !isoDate.test(updatedAt)) {
    return { reason: 'updatedAt no es una fecha ISO 8601' };
  }
  if (
    deletedAt !== undefined &&
    deletedAt !== null &&
    (typeof deletedAt !== 'string' || !isoDate.test(deletedAt))
  ) {
    return { reason: 'deletedAt no es una fecha ISO 8601' };
  }
  // Cada quien solo sube lo suyo. En `users`, la fila es la cuenta misma.
  const owner = table === 'users' ? id : data.userId;
  if (owner !== userId) {
    return { reason: 'La fila pertenece a otra cuenta' };
  }
  if (Date.parse(updatedAt) > now.getTime() + maxClockSkewMs) {
    return {
      reason: 'updatedAt está en el futuro; revisa la hora del teléfono',
    };
  }
  return {
    table,
    id,
    updatedAt,
    deletedAt: (deletedAt as string | null | undefined) ?? null,
    data,
  };
}
