/**
 * Общая настройка приложения — один вызов для `main.ts`, эмиттера контракта и тестов
 * (`helpers/app.ts`): что проверено в тестах, то и работает у проверяющего.
 */
import { type INestApplication, ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, type OpenAPIObject, SwaggerModule } from '@nestjs/swagger';
import { json, type NextFunction, type Request, type Response } from 'express';
import { ErrorBody, ErrorFilter } from './common/errors';
import { requestContext } from './common/logger';
import { requestLog } from './common/request-log';

/** Предел тела `POST /client-logs` (таблица эндпоинтов): сверх — 413. */
const CLIENT_LOG_BODY_LIMIT = '4kb';

export function buildOpenApiDocument(app: INestApplication): OpenAPIObject {
  const config = new DocumentBuilder()
    .setTitle('The Way API')
    .setDescription('Контракт порождается из кода (`npm run openapi:emit`).')
    .setVersion('1.0.0')
    // Токен сессии непрозрачен: формат по умолчанию `JWT` соврал бы генератору.
    .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'opaque' })
    .build();
  return SwaggerModule.createDocument(app, config, {
    extraModels: [ErrorBody],
    // Имя операции = имя метода контроллера (уникальны по всему API) — его берёт Dart-клиент.
    operationIdFactory: (_controllerKey: string, methodKey: string) => methodKey,
  });
}

/** Проверка тел и запросов — одна на приложение и на seed (`seed/services.ts`): seed проходит те же правила, что клиент. */
export function validationPipe(): ValidationPipe {
  return new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true });
}

export function configureApp(app: INestApplication): void {
  app.use(requestContext());
  app.use(requestLog());
  // Свой парсер раньше общего: общий видит уже разобранное тело и пропускает его. Обёртка
  // обязательна: Nest не ставит общий парсер, если в стеке уже есть функция с именем
  // `jsonParser`, и тогда тела всех остальных путей остаются неразобранными.
  const clientLogsJson = json({ limit: CLIENT_LOG_BODY_LIMIT });
  app.use('/client-logs', (req: Request, res: Response, next: NextFunction) => clientLogsJson(req, res, next));
  app.useGlobalPipes(validationPipe());
  app.useGlobalFilters(new ErrorFilter());
  SwaggerModule.setup('docs', app, buildOpenApiDocument(app));
}
