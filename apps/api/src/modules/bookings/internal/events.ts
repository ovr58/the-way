/**
 * События брони: строка лога на каждый переход и отказ («Журнал событий») и события «при
 * открытии» («События») — чистыми функциями над статусом и `*_seen_status`.
 */
import type { BookingStatus, UpdateKind } from '../../../common/enums';
import { logEvent } from '../../../common/logger';
import type { BookingSide } from './status-machine';

export type BookingTransitionEvent = 'booking_created' | 'booking_confirmed' | 'booking_rejected' | 'booking_paid' | 'booking_cancelled';
export type BookingRefusalEvent = 'booking_rejected_no_seats' | 'booking_trip_unavailable';

export interface BookingEventFields {
  tripId: string;
  bookingId?: string;
  statusFrom?: BookingStatus | null;
  statusTo?: BookingStatus;
  seats?: number;
  priceTotal?: number;
}

/** Одна строка лога брони; у отказа — только `trip_id`. */
export function logBookingEvent(name: BookingTransitionEvent | BookingRefusalEvent, f: BookingEventFields): void {
  const fields: Record<string, unknown> = { trip_id: f.tripId };
  if (f.bookingId !== undefined) {
    Object.assign(fields, {
      booking_id: f.bookingId,
      status_from: f.statusFrom ?? null,
      status_to: f.statusTo,
      seats: f.seats,
      price_total: f.priceTotal,
    });
  }
  logEvent(name, fields);
}

export interface SeenStatuses {
  passengerSeenStatus?: BookingStatus | null;
  driverSeenStatus?: BookingStatus | null;
}

/** Создание: пассажир сам видит, что создал; водитель ещё не видел. */
export function seenOnCreate(status: BookingStatus): Required<SeenStatuses> {
  return { passengerSeenStatus: status, driverSeenStatus: null };
}

/** Переход пишет `<сторона действующего>_seen_status = новый status`; так же — `seen` запрашивающего. */
export function seenOnTransition(side: BookingSide, status: BookingStatus): SeenStatuses {
  return side === 'driver' ? { driverSeenStatus: status } : { passengerSeenStatus: status };
}

/** Событие для стороны `side` по таблице «События»; нет события — `null`. */
export function updateKind(
  side: BookingSide,
  b: { status: BookingStatus; passengerSeenStatus: BookingStatus | null; driverSeenStatus: BookingStatus | null },
): UpdateKind | null {
  if (side === 'driver') {
    if (b.status === 'requested' && b.driverSeenStatus !== 'requested') return 'new_request';
    if (b.status === 'awaiting_payment' && b.driverSeenStatus === null) return 'new_request';
    if (b.status === 'paid' && b.driverSeenStatus !== 'paid') return 'passenger_paid';
    return null;
  }
  if (b.status === 'awaiting_payment' && b.passengerSeenStatus !== 'awaiting_payment') return 'driver_accepted';
  if (b.status === 'rejected' && b.passengerSeenStatus !== 'rejected') return 'driver_rejected';
  return null;
}
