import { AppError } from '../../../common/errors';
import { BOOKING_TRANSITIONS, initialStatus, nextStatus } from './status-machine';

describe('машина статусов брони (V-07)', () => {
  it('стандартное бронирование — requested, быстрое — awaiting_payment', () => {
    expect(initialStatus('standard')).toBe('requested');
    expect(initialStatus('instant')).toBe('awaiting_payment');
  });

  it('переходы V-07 и сторона, которая их делает', () => {
    expect(nextStatus('confirm', 'requested')).toBe('awaiting_payment');
    expect(nextStatus('reject', 'requested')).toBe('rejected');
    expect(nextStatus('pay', 'awaiting_payment')).toBe('paid');
    for (const from of ['requested', 'awaiting_payment', 'paid'] as const) expect(nextStatus('cancel', from)).toBe('cancelled');
    expect(BOOKING_TRANSITIONS.confirm.actor).toBe('driver');
    expect(BOOKING_TRANSITIONS.reject.actor).toBe('driver');
    expect(BOOKING_TRANSITIONS.pay.actor).toBe('passenger');
    expect(BOOKING_TRANSITIONS.cancel.actor).toBe('passenger');
  });

  it('перехода нет — invalid_transition', () => {
    for (const [action, from] of [
      ['pay', 'requested'],
      ['confirm', 'awaiting_payment'],
      ['reject', 'paid'],
      ['cancel', 'rejected'],
      ['pay', 'paid'],
    ] as const) {
      let code: string | undefined;
      try {
        nextStatus(action, from);
      } catch (e) {
        code = e instanceof AppError ? e.code : 'other';
      }
      expect(code).toBe('invalid_transition');
    }
  });
});
