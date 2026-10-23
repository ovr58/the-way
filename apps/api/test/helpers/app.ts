/**
 * Приложение проверок — тот же `configureApp`, что у `main.ts`: что проверено здесь, то и работает
 * у проверяющего. HTTP (supertest) — только для действия под проверкой.
 */
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/configure-app';
import { migrate } from './db';

export async function createTestApp(): Promise<INestApplication> {
  await migrate();
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  const app = moduleRef.createNestApplication({ logger: false });
  configureApp(app);
  await app.init();
  return app;
}

type Method = 'get' | 'post' | 'patch' | 'delete';

/** Запрос от имени пользователя: `call(app, user.token).post('/trips').send(body)`. */
export function call(app: INestApplication, token?: string): Record<Method, (path: string) => request.Test> {
  const server = app.getHttpServer();
  const wrap =
    (method: Method) =>
    (path: string): request.Test => {
      const req = request(server)[method](path);
      return token ? req.set('authorization', `Bearer ${token}`) : req;
    };
  return { get: wrap('get'), post: wrap('post'), patch: wrap('patch'), delete: wrap('delete') };
}
