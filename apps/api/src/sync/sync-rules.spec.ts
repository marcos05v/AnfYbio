import { checkRow, maxClockSkewMs } from './sync-rules';

describe('checkRow', () => {
  const userId = '0193a1b2-0000-7000-8000-000000000001';
  const now = new Date('2026-11-19T12:00:00.000Z');
  const row = (data: Record<string, unknown>) => ({
    id: '0193a1b2-0000-7000-8000-0000000000aa',
    userId,
    updatedAt: '2026-11-19T11:59:59.123456Z',
    deletedAt: null,
    ...data,
  });

  it('acepta una fila propia y toma sus columnas de sincronización', () => {
    expect(checkRow('exercises', row({}), userId, now)).toEqual({
      table: 'exercises',
      id: '0193a1b2-0000-7000-8000-0000000000aa',
      updatedAt: '2026-11-19T11:59:59.123456Z',
      deletedAt: null,
      data: row({}),
    });
  });

  it('en users, la fila es la cuenta misma', () => {
    const user = { id: userId, updatedAt: '2026-11-19T11:00:00Z' };
    expect(checkRow('users', user, userId, now)).not.toHaveProperty('reason');
    expect(
      checkRow('users', { ...user, id: 'otra' }, userId, now),
    ).toHaveProperty('reason', 'La fila pertenece a otra cuenta');
  });

  it('rechaza filas de otra cuenta', () => {
    expect(checkRow('sessions', row({ userId: 'otro' }), userId, now)).toEqual({
      reason: 'La fila pertenece a otra cuenta',
    });
  });

  it.each([
    ['sin id', { id: undefined }],
    ['id vacío', { id: '' }],
    ['id demasiado largo', { id: 'x'.repeat(65) }],
  ])('rechaza una fila %s', (_, data) => {
    expect(checkRow('sessions', row(data), userId, now)).toEqual({
      reason: 'La fila no tiene un id válido',
    });
  });

  it.each(['ayer', '2026-11-19', '2026-11-19 10:00:00', 1700000000])(
    'rechaza updatedAt %p',
    (updatedAt) => {
      expect(checkRow('sessions', row({ updatedAt }), userId, now)).toEqual({
        reason: 'updatedAt no es una fecha ISO 8601',
      });
    },
  );

  it('acepta deletedAt nulo, ausente o con fecha, y rechaza otra cosa', () => {
    const deleted = row({ deletedAt: '2026-11-19T11:00:00.5+00:00' });
    expect(checkRow('sessions', deleted, userId, now)).toMatchObject({
      deletedAt: '2026-11-19T11:00:00.5+00:00',
    });
    const { deletedAt: _, ...withoutDeleted } = row({});
    expect(checkRow('sessions', withoutDeleted, userId, now)).toMatchObject({
      deletedAt: null,
    });
    expect(checkRow('sessions', row({ deletedAt: 'sí' }), userId, now)).toEqual(
      { reason: 'deletedAt no es una fecha ISO 8601' },
    );
  });

  it('tolera un reloj adelantado hasta 5 minutos', () => {
    const at = (ms: number) => new Date(now.getTime() + ms).toISOString();
    expect(
      checkRow('sessions', row({ updatedAt: at(maxClockSkewMs) }), userId, now),
    ).not.toHaveProperty('reason');
    expect(
      checkRow(
        'sessions',
        row({ updatedAt: at(maxClockSkewMs + 1000) }),
        userId,
        now,
      ),
    ).toEqual({
      reason: 'updatedAt está en el futuro; revisa la hora del teléfono',
    });
  });
});
