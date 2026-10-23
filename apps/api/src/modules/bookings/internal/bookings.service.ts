import { Inject, Injectable } from '@nestjs/common';
import { countCancellations30, nextCancellationBlocks, recordCancellation } from '../../../common/cancellations';
import type { BookingStatus } from '../../../common/enums';
import { AppError } from '../../../common/errors';
import type { Booking, CancelPreview, CancelResult } from '../../../common/forms';
import { closeOrder, reopenOrders } from '../../../common/order-response';
import { bookingViews, tripCards } from '../../../common/views';
import { DATABASE, type Database, type DbExecutor, type Transaction } from '../../../db/client';
import type { BookingInput, MyBookingsQuery, Quote, QuoteQuery, Update } from './bookings.dto';
import {
  activeBookingId,
  findBooking,
  insertBooking,
  lockTrip,
  passengerBookingIds,
  tripBookingIds,
  setStatus,
  shiftTaken,
  tripOwner,
  tripPricing,
  type BookingRow,
  type TripRow,
} from './bookings.repository';
import { logBookingEvent, seenOnCreate, seenOnTransition, type BookingTransitionEvent } from './events';
import { priceBooking } from '../../../common/pricing';
import { BOOKING_TRANSITIONS, initialStatus, nextStatus, type BookingAction, type BookingSide } from './status-machine';
import { listUpdates, markSeen } from './updates';

/** Возврат за отменённую оплаченную бронь — заглушка (V-07), `refund.days` контракта. */
const REFUND_DAYS = 3;
/**
 * Идёт ли отмена пассажиром в счёт 2/30: принятая бронь — да; заявка `requested` — нет; бронь из
 * заказа до оплаты — нет, это отказ от отклика водителя.
 */
function countsCancellation(booking: Pick<BookingRow, 'status' | 'orderId'>): boolean {
  if (booking.orderId && booking.status === 'awaiting_payment') return false;
  return COUNTED_CANCEL_FROM.includes(booking.status);
}

/** Отмена брони из этих статусов (водитель уже принял) идёт в счёт 2/30; отмена заявки `requested` — нет. */
const COUNTED_CANCEL_FROM: readonly BookingStatus[] = ['awaiting_payment', 'paid'];

const EVENT_OF: Record<BookingAction, BookingTransitionEvent> = {
  confirm: 'booking_confirmed',
  reject: 'booking_rejected',
  pay: 'booking_paid',
  cancel: 'booking_cancelled',
};

/** Свободных мест (и при посылке — мест для посылок) меньше, чем нужно брони. */
function lacksSeats(trip: TripRow, seats: number, withParcel: boolean): boolean {
  return trip.seatsTotal - trip.seatsTaken < seats || (withParcel && trip.parcelSeatsTotal - trip.parcelSeatsTaken < 1);
}

function noSeats(tripId: string): AppError {
  logBookingEvent('booking_rejected_no_seats', { tripId });
  return new AppError('no_seats', 'Мест нет');
}

/** Брони: создание, ответ водителя, оплата, отмена, события (строка A2). */
@Injectable()
export class BookingsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async quote(viewerId: string, tripId: string, query: QuoteQuery): Promise<Quote> {
    const [card] = await tripCards(this.db, [tripId], { viewerId });
    if (!card) throw new AppError('not_found', 'Поездка не найдена');
    const pricing = await tripPricing(this.db, { id: tripId, priceFull: card.price });
    const { segmentPrice, priceTotal } = priceBooking(pricing, {
      fromIdx: query.fromIdx,
      toIdx: query.toIdx,
      seats: query.seats,
      parcelSize: query.parcelSize ?? 'none',
      services: query.extras ?? [],
    });
    return { segmentPrice, priceTotal };
  }

  /**
   * Порядок проверок — шаг A2.1: активная бронь → `booking_exists`; поездка не бронируема (не
   * `registrationOpen` или своя) → `trip_unavailable`; мест меньше запрошенного или нет мест
   * для посылки → `no_seats`; затем правила тела и цена → `validation`.
   */
  async create(viewerId: string, tripId: string, body: BookingInput): Promise<Booking> {
    return this.db.transaction(async (tx) => {
      const trip = await lockTrip(tx, tripId);
      if (!trip) throw new AppError('not_found', 'Поездка не найдена');
      if (await activeBookingId(tx, tripId, viewerId)) throw new AppError('booking_exists', 'Бронь на эту поездку уже есть');
      const [card] = await tripCards(tx, [tripId], { viewerId });
      if (!card?.registrationOpen || trip.driverId === viewerId) {
        logBookingEvent('booking_trip_unavailable', { tripId });
        throw new AppError('trip_unavailable', 'Поездку нельзя забронировать');
      }
      const withParcel = body.parcelSize !== 'none';
      if (lacksSeats(trip, body.seats, withParcel)) throw noSeats(tripId);

      if (body.parcelOnly) {
        if (!trip.parcelOnlyAllowed) throw new AppError('validation', 'Посылка без проезда не разрешена водителем');
        if (body.seats !== 0 || !withParcel) throw new AppError('validation', 'Посылка без проезда — 0 мест и размер посылки');
      } else if (body.seats < 1) {
        throw new AppError('validation', 'Нужно хотя бы одно место');
      }
      if (!withParcel && body.parcelComment) throw new AppError('validation', 'Комментарий — только к посылке');
      const price = priceBooking(await tripPricing(tx, trip), {
        fromIdx: body.fromIdx,
        toIdx: body.toIdx,
        seats: body.seats,
        parcelSize: body.parcelSize,
        services: body.extras,
      });

      const status = initialStatus(trip.bookingMode);
      const id = await insertBooking(
        tx,
        {
          tripId,
          passengerId: viewerId,
          fromIdx: body.fromIdx,
          toIdx: body.toIdx,
          seats: body.seats,
          parcelSize: body.parcelSize,
          parcelOnly: body.parcelOnly,
          parcelComment: withParcel ? (body.parcelComment ?? null) : null,
          priceTotal: price.priceTotal,
          status,
          ...seenOnCreate(status),
          confirmedAt: status === 'awaiting_payment' ? new Date() : null,
        },
        price.extras,
      );
      logBookingEvent('booking_created', {
        bookingId: id,
        tripId,
        statusFrom: null,
        statusTo: status,
        seats: body.seats,
        priceTotal: price.priceTotal,
      });
      return this.view(tx, id, viewerId);
    });
  }

  /** Заявки поездки — только её водителю (чужому — 404, как чужая бронь). */
  async listForTrip(viewerId: string, tripId: string): Promise<Booking[]> {
    if ((await tripOwner(this.db, tripId)) !== viewerId) throw new AppError('not_found', 'Поездка не найдена');
    return bookingViews(this.db, await tripBookingIds(this.db, tripId), { viewerId });
  }

  async mine(viewerId: string, query: MyBookingsQuery): Promise<Booking[]> {
    return bookingViews(this.db, await passengerBookingIds(this.db, viewerId, query.status), { viewerId });
  }

  async get(viewerId: string, bookingId: string): Promise<Booking> {
    await this.access(this.db, viewerId, bookingId);
    return this.view(this.db, bookingId, viewerId);
  }

  async confirm(viewerId: string, bookingId: string): Promise<Booking> {
    return this.transition(viewerId, bookingId, 'confirm');
  }

  async reject(viewerId: string, bookingId: string): Promise<Booking> {
    return this.transition(viewerId, bookingId, 'reject');
  }

  async pay(viewerId: string, bookingId: string): Promise<Booking> {
    return this.transition(viewerId, bookingId, 'pay');
  }

  /** Что даст отмена: счёт 2/30 и блокировка (только принятой брони), возврат за `paid`; отменить нельзя — те же отказы, что у отмены. */
  async cancelPreview(viewerId: string, bookingId: string): Promise<CancelPreview> {
    const { booking, side } = await this.access(this.db, viewerId, bookingId);
    if (BOOKING_TRANSITIONS.cancel.actor !== side) throw new AppError('forbidden', 'Это действие другой стороны брони');
    nextStatus('cancel', booking.status);
    const counts = countsCancellation(booking);
    return {
      cancellationsLast30: await countCancellations30(this.db, viewerId),
      willBlock: counts && (await nextCancellationBlocks(this.db, viewerId)),
      refundAmount: booking.status === 'paid' ? booking.priceTotal : null,
      counts,
    };
  }

  /** Отмена пассажиром: принятая бронь идёт в счёт 2/30; отмена `paid` возвращает места и деньги за 3 дня. */
  async cancel(viewerId: string, bookingId: string): Promise<CancelResult> {
    return this.db.transaction(async (tx) => {
      const before = await this.move(tx, viewerId, bookingId, 'cancel');
      const outcome = countsCancellation(before)
        ? await recordCancellation(tx, { userId: viewerId, role: 'passenger', bookingId })
        : { cancellationsLast30: await countCancellations30(tx, viewerId) };
      // Бронь из заказа: до оплаты — отказ от отклика, заказ снова открыт; оплаченная — заказ закрыт.
      if (before.orderId) {
        if (before.status === 'paid') await closeOrder(tx, before.orderId, bookingId);
        else await reopenOrders(tx, [{ id: bookingId, orderId: before.orderId }], 'passenger_declined');
      }
      return {
        status: 'cancelled',
        cancellationsLast30: outcome.cancellationsLast30,
        blockedUntil: outcome.blockedUntil ?? null,
        refund: before.status === 'paid' ? { amount: before.priceTotal, days: REFUND_DAYS } : null,
      };
    });
  }

  async updates(viewerId: string): Promise<Update[]> {
    return listUpdates(this.db, viewerId);
  }

  async markSeen(viewerId: string, bookingId: string): Promise<void> {
    const { booking, side } = await this.access(this.db, viewerId, bookingId);
    await markSeen(this.db, side, booking);
  }

  /**
   * Переход брони — единственное место, где меняется статус: доступ (посторонний — 404, не та
   * сторона — 403), блокировка строки поездки, машина статусов, места (подтверждение проверяет,
   * оплата проверяет и занимает, отмена `paid` возвращает), `*_seen_status`
   * действующего, строка лога. Статус и места читаются заново после блокировки: параллельный
   * переход уже мог их сменить. Возвращает бронь, какой она была до перехода.
   */
  private async move(tx: Transaction, viewerId: string, bookingId: string, action: BookingAction): Promise<BookingRow> {
    const { booking: found, side } = await this.access(tx, viewerId, bookingId);
    if (BOOKING_TRANSITIONS[action].actor !== side) throw new AppError('forbidden', 'Это действие другой стороны брони');

    const trip = (await lockTrip(tx, found.tripId)) as TripRow;
    const booking = (await findBooking(tx, bookingId)) as BookingRow;
    const to = nextStatus(action, booking.status);
    const withParcel = booking.parcelSize !== 'none';
    if ((action === 'confirm' || action === 'pay') && lacksSeats(trip, booking.seats, withParcel)) throw noSeats(trip.id);
    if (action === 'pay') await shiftTaken(tx, trip.id, booking.seats, withParcel ? 1 : 0);
    if (action === 'cancel' && booking.status === 'paid') await shiftTaken(tx, trip.id, -booking.seats, withParcel ? -1 : 0);

    const now = new Date();
    await setStatus(tx, bookingId, {
      status: to,
      ...seenOnTransition(side, to),
      ...(action === 'confirm' ? { confirmedAt: now } : {}),
      ...(action === 'pay' ? { paidAt: now } : {}),
      ...(action === 'reject' ? { rejectedAt: now } : {}),
      ...(action === 'cancel' ? { cancelledAt: now } : {}),
    });
    logBookingEvent(EVENT_OF[action], {
      bookingId,
      tripId: trip.id,
      statusFrom: booking.status,
      statusTo: to,
      seats: booking.seats,
      priceTotal: booking.priceTotal,
    });
    return booking;
  }

  private transition(viewerId: string, bookingId: string, action: BookingAction): Promise<Booking> {
    return this.db.transaction(async (tx) => {
      await this.move(tx, viewerId, bookingId, action);
      return this.view(tx, bookingId, viewerId);
    });
  }

  /** Сторона зрителя в брони: её пассажир или водитель её поездки; остальным — 404 (NFR-04). */
  private async access(tx: DbExecutor, viewerId: string, bookingId: string): Promise<{ booking: BookingRow; side: BookingSide }> {
    const booking = await findBooking(tx, bookingId);
    if (booking?.passengerId === viewerId) return { booking, side: 'passenger' };
    if (booking && (await tripOwner(tx, booking.tripId)) === viewerId) return { booking, side: 'driver' };
    throw new AppError('not_found', 'Бронь не найдена');
  }

  private async view(tx: DbExecutor, bookingId: string, viewerId: string): Promise<Booking> {
    const [view] = await bookingViews(tx, [bookingId], { viewerId });
    return view;
  }
}
