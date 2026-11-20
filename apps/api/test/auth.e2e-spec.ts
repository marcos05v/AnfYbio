import type { NestExpressApplication } from '@nestjs/platform-express';
import request from 'supertest';
import { PrismaService } from '../src/prisma/prisma.service';
import { createTestApp, resetDatabase, signUp, uuid } from './helpers';

describe('Cuentas (e2e)', () => {
  let app: NestExpressApplication;
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    app = await createTestApp();
  });
  beforeEach(() => resetDatabase(app));
  afterAll(() => app.close());

  it('GET /health identifica al servidor', async () => {
    await http()
      .get('/health')
      .expect(200, { status: 'ok', service: 'anfybio' });
  });

  it('registrarse usa el id del teléfono y entrega un token', async () => {
    const userId = uuid();
    const response = await http()
      .post('/auth/register')
      .send({ userId, username: ' Marcos ', password: 'contraseña-segura' })
      .expect(201);

    expect(response.body).toMatchObject({ userId, username: 'marcos' });
    await http()
      .get('/auth/me')
      .set('Authorization', `Bearer ${response.body.token}`)
      .expect(200, { userId, username: 'marcos' });
  });

  it('la contraseña se guarda con argon2id, nunca en claro', async () => {
    await signUp(app, 'ana');
    const account = await app
      .get(PrismaService)
      .account.findUniqueOrThrow({ where: { username: 'ana' } });
    expect(account.passwordHash).toMatch(/^\$argon2id\$/);
    expect(account.passwordHash).not.toContain('contraseña-segura');
  });

  it('no permite repetir usuario ni id', async () => {
    const { userId } = await signUp(app, 'ana');
    await http()
      .post('/auth/register')
      .send({ userId: uuid(), username: 'ANA', password: 'otra-contraseña' })
      .expect(409);
    await http()
      .post('/auth/register')
      .send({ userId, username: 'otra', password: 'otra-contraseña' })
      .expect(409);
  });

  it.each([
    ['usuario corto', { username: 'ab' }],
    ['usuario con espacios', { username: 'ana maria' }],
    ['contraseña corta', { password: '1234567' }],
    ['id que no es UUID', { userId: '123' }],
    ['campos de más', { admin: true }],
  ])('rechaza el registro con %s', async (_, change) => {
    await http()
      .post('/auth/register')
      .send({
        userId: uuid(),
        username: 'ana',
        password: 'contraseña-segura',
        ...change,
      })
      .expect(400);
  });

  it('inicia sesión con la contraseña correcta', async () => {
    const { userId } = await signUp(app, 'ana');
    const response = await http()
      .post('/auth/login')
      .send({ username: 'Ana', password: 'contraseña-segura' })
      .expect(200);
    expect(response.body).toMatchObject({ userId, username: 'ana' });
    expect(typeof response.body.token).toBe('string');
  });

  it('contraseña incorrecta y usuario inexistente responden igual', async () => {
    await signUp(app, 'ana');
    const wrong = await http()
      .post('/auth/login')
      .send({ username: 'ana', password: 'no-es-esta' })
      .expect(401);
    const missing = await http()
      .post('/auth/login')
      .send({ username: 'nadie', password: 'no-es-esta' })
      .expect(401);
    expect(wrong.body.message).toBe('Usuario o contraseña incorrectos');
    expect(missing.body.message).toBe(wrong.body.message);
  });

  it('sin token o con uno alterado no deja pasar', async () => {
    const { token } = await signUp(app);
    await http().get('/auth/me').expect(401);
    await http().get('/sync/pull').expect(401);
    await http()
      .get('/auth/me')
      .set('Authorization', `Bearer ${token.slice(0, -2)}xx`)
      .expect(401);
    await http().get('/auth/me').set('Authorization', token).expect(401);
  });
});
