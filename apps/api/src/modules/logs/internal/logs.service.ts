import { Injectable } from '@nestjs/common';
import { logEvent } from '../../../common/logger';
import type { ClientLogBody } from './logs.dto';

/**
 * Ошибки клиента — строкой лога `client_log` с полями тела. `trace_id` строки —
 * из `traceparent` запроса (клиент ставит его на каждый запрос); `user_id` — если вошёл.
 * Размер тела (≤ 4 КБ) ограничивает парсер в `configure-app.ts`.
 */
@Injectable()
export class LogsService {
  async write(_viewerId: string | undefined, body: ClientLogBody): Promise<void> {
    logEvent(
      'client_log',
      {
        client_level: body.level,
        message: body.message,
        screen: body.screen ?? undefined,
        client_trace_id: body.traceId ?? undefined,
        app_version: body.appVersion,
        device: body.device,
      },
      body.level === 'info' ? 'info' : body.level,
    );
  }
}
