import {
  type ArgumentsHost,
  Catch,
  type ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import type { Request, Response } from 'express';
import { logEvent } from './logger';

/**
 * Коды ошибок контракта. `internal` — любой 5xx, в том числе 501 у сервисов-заглушек
 * шага 1.1 (`NotImplementedException`).
 */
export const ERROR_CODES = [
  'validation',
  'invalid_code',
  'unauthorized',
  'forbidden',
  'not_found',
  'limit_reached',
  'too_far_ahead',
  'invalid_time_step',
  'edit_locked',
  'seats_below_taken',
  'no_seats',
  'trip_unavailable',
  'booking_exists',
  'car_invalid',
  'file_too_large',
  'file_type',
  'blocked',
  'account_blocked',
  'invalid_transition',
  'order_unavailable',
  'order_mismatch',
  'car_plate_taken',
  'car_seats_out_of_range',
  'internal',
] as const;
export type ErrorCode = (typeof ERROR_CODES)[number];

/** Тело любого ответа с ошибкой: `{code, message}` (+ `blockedUntil` у `blocked`). */
export class ErrorBody {
  @ApiProperty({ enum: ERROR_CODES, enumName: 'ErrorCode' })
  code!: ErrorCode;

  @ApiProperty()
  message!: string;

  @ApiPropertyOptional({ type: String, format: 'date-time', nullable: true })
  blockedUntil?: string | null;
}

const DEFAULT_STATUS: Record<ErrorCode, number> = {
  validation: HttpStatus.BAD_REQUEST,
  invalid_code: HttpStatus.BAD_REQUEST,
  unauthorized: HttpStatus.UNAUTHORIZED,
  forbidden: HttpStatus.FORBIDDEN,
  not_found: HttpStatus.NOT_FOUND,
  limit_reached: HttpStatus.CONFLICT,
  too_far_ahead: HttpStatus.BAD_REQUEST,
  invalid_time_step: HttpStatus.BAD_REQUEST,
  edit_locked: HttpStatus.CONFLICT,
  seats_below_taken: HttpStatus.CONFLICT,
  no_seats: HttpStatus.CONFLICT,
  trip_unavailable: HttpStatus.CONFLICT,
  booking_exists: HttpStatus.CONFLICT,
  car_invalid: HttpStatus.BAD_REQUEST,
  file_too_large: HttpStatus.PAYLOAD_TOO_LARGE,
  file_type: HttpStatus.UNSUPPORTED_MEDIA_TYPE,
  blocked: HttpStatus.FORBIDDEN,
  account_blocked: HttpStatus.FORBIDDEN,
  invalid_transition: HttpStatus.CONFLICT,
  order_unavailable: HttpStatus.CONFLICT,
  order_mismatch: HttpStatus.CONFLICT,
  car_plate_taken: HttpStatus.CONFLICT,
  car_seats_out_of_range: HttpStatus.BAD_REQUEST,
  internal: HttpStatus.INTERNAL_SERVER_ERROR,
};

/**
 * Ошибка предметной области. Сервис бросает `throw new AppError('no_seats', 'Мест нет')`;
 * HTTP-статус по умолчанию — из таблицы выше; `extra` — дополнительные поля тела
 * (`{blockedUntil}` у `blocked`).
 */
export class AppError extends HttpException {
  constructor(
    readonly code: ErrorCode,
    message: string = code,
    readonly extra: { blockedUntil?: string } = {},
    status: number = DEFAULT_STATUS[code],
  ) {
    super({ code, message, ...extra }, status);
  }
}

function codeForStatus(status: number): ErrorCode {
  switch (status) {
    case 401:
      return 'unauthorized';
    case 403:
      return 'forbidden';
    case 404:
      return 'not_found';
    default:
      return status >= 500 ? 'internal' : 'validation';
  }
}

function messageOf(response: unknown, fallback: string): string {
  if (typeof response === 'object' && response !== null && 'message' in response) {
    const { message } = response as { message: unknown };
    if (Array.isArray(message)) return message.join('; ');
    if (typeof message === 'string') return message;
  }
  return fallback;
}

/** Статус ошибки вне `HttpException` — например, `PayloadTooLargeError` парсера тела (413). */
function statusOf(error: unknown): number {
  if (typeof error === 'object' && error !== null && 'status' in error) {
    const { status } = error as { status: unknown };
    if (typeof status === 'number' && status >= 400 && status < 600) return status;
  }
  return HttpStatus.INTERNAL_SERVER_ERROR;
}

/**
 * Глобальный фильтр: любая ошибка уходит телом `{code, message}`; на 5xx — строка
 * `request_error` со стеком.
 */
@Catch()
export class ErrorFilter implements ExceptionFilter {
  catch(error: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const res = http.getResponse<Response>();
    const req = http.getRequest<Request>();

    let status: number;
    let body: ErrorBody;
    if (error instanceof AppError) {
      status = error.getStatus();
      body = { code: error.code, message: error.message, ...error.extra };
    } else if (error instanceof HttpException) {
      status = error.getStatus();
      body = { code: codeForStatus(status), message: messageOf(error.getResponse(), error.message) };
    } else {
      status = statusOf(error);
      body = {
        code: codeForStatus(status),
        message: status >= 500 ? 'Внутренняя ошибка' : messageOf(error, 'Ошибка запроса'),
      };
    }

    if (status >= 500) {
      logEvent(
        'request_error',
        {
          method: req.method,
          path: req.path,
          code: status,
          error: error instanceof Error ? error.message : String(error),
          stack: error instanceof Error ? error.stack : undefined,
        },
        'error',
      );
    }

    res.status(status).json(body);
  }
}
