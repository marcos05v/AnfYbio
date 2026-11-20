import type { NestExpressApplication } from '@nestjs/platform-express';
import request from 'supertest';
import { createTestApp, resetDatabase, signUp, uuid } from './helpers';

describe('Sincronización (e2e)', () => {
  let app: NestExpressApplication;
  let userId: string;
  let token: string;
  const http = () => request(app.getHttpServer());

  /// Una serie de fuerza como la manda el teléfono.
  const set = (
    id: string,
    updatedAt: string,
    extra: Record<string, unknown> = {},
  ) => ({
    table: 'strengthSets',
    data: {
      id,
      userId,
      updatedAt,
      deletedAt: null,
      reps: 8,
      weight: 60,
      ...extra,
    },
  });

  const push = (rows: unknown[], as = token) =>
    http()
      .post('/sync/push')
      .set('Authorization', `Bearer ${as}`)
      .send({ rows });
  const pull = (since = 0, limit?: number, as = token) =>
    http()
      .get('/sync/pull')
      .query(limit ? { since, limit } : { since })
      .set('Authorization', `Bearer ${as}`)
      .expect(200);

  beforeAll(async () => {
    app = await createTestApp();
  });
  beforeEach(async () => {
    await resetDatabase(app);
    ({ userId, token } = await signUp(app, 'marcos'));
  });
  afterAll(() => app.close());

  it('lo que se sube se puede bajar', async () => {
    const id = uuid();
    const user = {
      table: 'users',
      data: {
        id: userId,
        displayName: 'Marcos',
        updatedAt: '2026-11-19T10:00:00Z',
      },
    };
    const sent = set(id, '2026-11-19T10:00:00.123456Z');

    await push([user, sent]).expect(200, {
      applied: 2,
      skipped: 0,
      rejected: [],
    });

    const { body } = await pull();
    expect(body.rows).toEqual([user, sent]);
    expect(body.hasMore).toBe(false);
    expect(body.next).toBeGreaterThan(0);
  });

  it('gana el cambio más reciente, aunque llegue después', async () => {
    const id = uuid();
    await push([set(id, '2026-11-19T10:00:00Z', { reps: 8 })]).expect(200);

    // Una versión más vieja que llega tarde se ignora.
    await push([set(id, '2026-11-19T09:00:00Z', { reps: 5 })]).expect(200, {
      applied: 0,
      skipped: 1,
      rejected: [],
    });
    expect((await pull()).body.rows[0].data.reps).toBe(8);

    // Una más nueva la reemplaza.
    await push([set(id, '2026-11-19T11:00:00Z', { reps: 10 })]).expect(200, {
      applied: 1,
      skipped: 0,
      rejected: [],
    });
    const { body } = await pull();
    expect(body.rows).toHaveLength(1);
    expect(body.rows[0].data.reps).toBe(10);
  });

  it('distingue cambios separados por un microsegundo', async () => {
    const id = uuid();
    await push([set(id, '2026-11-19T10:00:00.000001Z', { reps: 1 })]);
    await push([set(id, '2026-11-19T10:00:00.000002Z', { reps: 2 })]).expect(
      200,
      { applied: 1, skipped: 0, rejected: [] },
    );
    // La misma fecha otra vez no cuenta como cambio.
    await push([set(id, '2026-11-19T10:00:00.000002Z', { reps: 3 })]).expect(
      200,
      { applied: 0, skipped: 1, rejected: [] },
    );
    expect((await pull()).body.rows[0].data.reps).toBe(2);
  });

  it('un borrado viaja como cualquier cambio', async () => {
    const id = uuid();
    await push([set(id, '2026-11-19T10:00:00Z')]);
    await push([
      set(id, '2026-11-19T10:05:00Z', { deletedAt: '2026-11-19T10:05:00Z' }),
    ]).expect(200);

    const { body } = await pull();
    expect(body.rows[0].data.deletedAt).toBe('2026-11-19T10:05:00Z');
  });

  it('bajar desde un número trae solo lo posterior', async () => {
    await push([set(uuid(), '2026-11-19T10:00:00Z')]);
    const first = (await pull()).body;

    const later = set(uuid(), '2026-11-19T10:01:00Z');
    await push([later]);
    const second = (await pull(first.next)).body;

    expect(second.rows).toEqual([later]);
    expect(second.next).toBeGreaterThan(first.next);
    // Sin cambios nuevos, vuelve vacío y con el mismo número.
    expect((await pull(second.next)).body).toEqual({
      rows: [],
      next: second.next,
      hasMore: false,
    });
  });

  it('una fila actualizada vuelve a bajar con un número nuevo', async () => {
    const id = uuid();
    await push([set(id, '2026-11-19T10:00:00Z')]);
    const { next } = (await pull()).body;

    await push([set(id, '2026-11-19T10:10:00Z', { reps: 12 })]);

    const { body } = await pull(next);
    expect(
      body.rows.map((r: { data: { reps: number } }) => r.data.reps),
    ).toEqual([12]);
  });

  it('baja por páginas', async () => {
    await push(
      Array.from({ length: 5 }, (_, i) =>
        set(uuid(), `2026-11-19T10:00:0${i}Z`),
      ),
    );

    const page1 = (await pull(0, 2)).body;
    const page2 = (await pull(page1.next, 2)).body;
    const page3 = (await pull(page2.next, 2)).body;

    expect([page1, page2, page3].map((p) => p.rows.length)).toEqual([2, 2, 1]);
    expect([page1, page2, page3].map((p) => p.hasMore)).toEqual([
      true,
      true,
      false,
    ]);
  });

  it('nadie sube filas a nombre de otra cuenta', async () => {
    const sister = await signUp(app, 'hermana');
    const foreign = { ...set(uuid(), '2026-11-19T10:00:00Z') };
    foreign.data.userId = sister.userId;

    const { body } = await push([foreign]).expect(200);

    expect(body.rejected).toEqual([
      {
        table: 'strengthSets',
        id: foreign.data.id,
        reason: 'La fila pertenece a otra cuenta',
      },
    ]);
    expect((await pull(0, undefined, sister.token)).body.rows).toEqual([]);
  });

  it('nadie sobrescribe una fila ajena aunque use su id', async () => {
    const sister = await signUp(app, 'hermana');
    const id = uuid();
    const hers = {
      table: 'strengthSets',
      data: {
        id,
        userId: sister.userId,
        updatedAt: '2026-11-19T10:00:00Z',
        reps: 5,
      },
    };
    await push([hers], sister.token).expect(200);

    // Mismo id, más reciente, pero de otra cuenta: no cambia nada.
    await push([set(id, '2026-11-19T12:00:00Z', { reps: 99 })]).expect(200, {
      applied: 0,
      skipped: 1,
      rejected: [],
    });

    expect((await pull(0, undefined, sister.token)).body.rows).toEqual([hers]);
    expect((await pull()).body.rows).toEqual([]);
  });

  it('rechaza fechas en el futuro', async () => {
    const future = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    const { body } = await push([set(uuid(), future)]).expect(200);
    expect(body.rejected[0].reason).toMatch(/futuro/);
  });

  it('rechaza tablas desconocidas, filas mal formadas y subidas enormes', async () => {
    await push([{ table: 'accounts', data: {} }]).expect(400);
    await push([{ table: 'sessions', data: 'texto' }]).expect(400);
    await http()
      .post('/sync/push')
      .set('Authorization', `Bearer ${token}`)
      .send({})
      .expect(400);
    await push(
      Array.from({ length: 501 }, () => set(uuid(), '2026-11-19T10:00:00Z')),
    ).expect(400);
    await http()
      .get('/sync/pull')
      .query({ since: -1 })
      .set('Authorization', `Bearer ${token}`)
      .expect(400);
  });
});
