import { AppError } from '../../../common/errors';

/** Код входа без SMS-шлюза (`docs/task.md`). */
export const AUTH_CODE = '111111';

/** E.164: `+` и 8–15 цифр, первая — не 0; с кодом `+7` или `+1` — ровно 11 цифр. */
const E164 = /^\+(?:[17]\d{10}|[2-689]\d{7,14})$/;

/** Номер в любой записи → E.164: убираются пробелы, скобки и дефисы; иначе `validation`. */
export function normalizePhone(raw: string): string {
  const phone = raw.replace(/[\s()-]/g, '');
  if (!E164.test(phone)) throw new AppError('validation', 'Номер телефона: «+» и 8–15 цифр');
  return phone;
}

/** Для журнала — только последние 4 цифры. */
export function maskPhone(phone: string): string {
  return `***${phone.slice(-4)}`;
}
