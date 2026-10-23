import { logBookingEvent, seenOnCreate, seenOnTransition, updateKind } from './events';

describe('События брони', () => {
  it('создание: пассажир видел свой статус, водитель — нет', () => {
    expect(seenOnCreate('requested')).toEqual({ passengerSeenStatus: 'requested', driverSeenStatus: null });
  });

  it('переход пишет сторону действующего', () => {
    expect(seenOnTransition('driver', 'awaiting_payment')).toEqual({ driverSeenStatus: 'awaiting_payment' });
    expect(seenOnTransition('passenger', 'paid')).toEqual({ passengerSeenStatus: 'paid' });
  });

  it('таблица «События»', () => {
    const b = (status: string, passengerSeenStatus: string | null, driverSeenStatus: string | null) =>
      ({ status, passengerSeenStatus, driverSeenStatus }) as Parameters<typeof updateKind>[1];
    expect(updateKind('driver', b('requested', 'requested', null))).toBe('new_request');
    expect(updateKind('driver', b('requested', 'requested', 'requested'))).toBeNull();
    expect(updateKind('driver', b('awaiting_payment', 'awaiting_payment', null))).toBe('new_request');
    expect(updateKind('driver', b('awaiting_payment', 'awaiting_payment', 'requested'))).toBeNull();
    expect(updateKind('driver', b('paid', 'paid', 'awaiting_payment'))).toBe('passenger_paid');
    expect(updateKind('passenger', b('awaiting_payment', 'requested', 'awaiting_payment'))).toBe('driver_accepted');
    expect(updateKind('passenger', b('awaiting_payment', 'awaiting_payment', null))).toBeNull();
    expect(updateKind('passenger', b('rejected', 'requested', 'rejected'))).toBe('driver_rejected');
    expect(updateKind('passenger', b('cancelled', 'paid', 'paid'))).toBeNull();
    expect(updateKind('driver', b('cancelled', 'cancelled', 'paid'))).toBeNull();
  });

  it('строка лога перехода — поля «Журнала событий»', () => {
    const lines: Record<string, unknown>[] = [];
    const spy = jest.spyOn(process.stdout, 'write').mockImplementation((chunk: string | Uint8Array) => {
      lines.push(JSON.parse(String(chunk)) as Record<string, unknown>);
      return true;
    });
    logBookingEvent('booking_paid', { bookingId: 'b', tripId: 't', statusFrom: 'awaiting_payment', statusTo: 'paid', seats: 2, priceTotal: 900 });
    logBookingEvent('booking_rejected_no_seats', { tripId: 't' });
    spy.mockRestore();
    expect(lines[0]).toMatchObject({
      event: 'booking_paid',
      booking_id: 'b',
      trip_id: 't',
      status_from: 'awaiting_payment',
      status_to: 'paid',
      seats: 2,
      price_total: 900,
    });
    expect(lines[1]).toMatchObject({ event: 'booking_rejected_no_seats', trip_id: 't' });
    expect(lines[1]).not.toHaveProperty('booking_id');
  });
});
