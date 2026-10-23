import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { currentContext, logEvent, runWithContext } from './logger';

/**
 * Строка лога `request` на каждый запрос:
 * метод, путь (без строки запроса), код, мс; `trace_id` и `user_id` — из контекста запроса.
 * Пишется и в production: на стенде телеметрии нет, лог — единственный след.
 *
 * `res.on('finish')`, а не перехватчик Nest: перехватчик не видит запросов, отклонённых до
 * контроллера (guard, pipe, 404). Контекст захватывается при входе: событие `finish` приходит
 * из сокета, вне асинхронной цепочки запроса; `user_id` guard дописывает в тот же объект.
 */
export function requestLog(): RequestHandler {
  return (req: Request, res: Response, next: NextFunction): void => {
    const startedAt = process.hrtime.bigint();
    const ctx = currentContext();
    res.on('finish', () => {
      const ms = Math.round(Number(process.hrtime.bigint() - startedAt) / 1e6);
      const fields = { method: req.method, path: req.originalUrl.split('?')[0], code: res.statusCode, ms };
      if (ctx) runWithContext(ctx, () => logEvent('request', fields));
      else logEvent('request', fields);
    });
    next();
  };
}
