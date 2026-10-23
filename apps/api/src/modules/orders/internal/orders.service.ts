import { Inject, Injectable } from '@nestjs/common';
import { desc, eq } from 'drizzle-orm';
import { AppError } from '../../../common/errors';
import type { Booking } from '../../../common/forms';
import { logEvent } from '../../../common/logger';
import { loadOrder, matchingTripsFor, respondToOrder } from '../../../common/order-response';
import { SAME_PLACE_KM, haversineKm, resolveCityId } from '../../../common/places';
import { CAR_SEATS_MAX, checkTimes } from '../../../common/trip-times';
import { bookingViews, tripCards } from '../../../common/views';
import { DATABASE, type Database, type DbExecutor } from '../../../db/client';
import type { OrderCard, OrderDetails, OrderInput, OrderResponseInput, OrderSearchQuery } from './orders.dto';
import { feedOrderIds, insertOrder, orderCards, orderStopsOf, plainStop, pointOf } from './orders.repository';
import { orders } from './schema';

/** Правила формы заказа (план passenger-order, «Формы» — `OrderInput`); нарушение — `validation`. */
function checkOrder(body: OrderInput): void {
  const withParcel = body.parcelSize !== 'none';
  if (body.kind === 'ride') {
    if (body.seats < 1 || body.seats > CAR_SEATS_MAX) throw new AppError('validation', `Мест — от 1 до ${CAR_SEATS_MAX}`);
  } else {
    if (body.seats !== 0) throw new AppError('validation', 'У заказа-посылки мест для пассажиров нет');
    if (!withParcel) throw new AppError('validation', 'Выберите размер посылки');
    if (body.extras.length > 0) throw new AppError('validation', 'Услуги — только к поездке');
  }
  if (!withParcel && body.parcelComment) throw new AppError('validation', 'Комментарий — только к посылке');
  if (new Set(body.extras).size !== body.extras.length) throw new AppError('validation', 'Услуга указана дважды');
}

/**
 * Заказы пассажиров (план passenger-order): публикация, лента водителя, мои, детали с подходящими
 * поездками зрителя, отмена, отклик. Правила подбора и отклика — `common/order-response.ts`.
 */
@Injectable()
export class OrdersService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async create(viewerId: string, body: OrderInput): Promise<OrderDetails> {
    const departsAt = new Date(body.departsAt);
    const arrivesAt = new Date(body.arrivesAt);
    checkTimes(departsAt, arrivesAt);
    checkOrder(body);
    return this.db.transaction(async (tx) => {
      const stops = [];
      for (const stop of body.stops) {
        stops.push({
          cityId: await resolveCityId(tx, stop),
          address: stop.address,
          shortAddress: stop.shortAddress ?? null,
          lat: stop.lat ?? null,
          lng: stop.lng ?? null,
        });
      }
      const id = await insertOrder(tx, {
        passengerId: viewerId,
        kind: body.kind,
        departsAt,
        arrivesAt,
        seats: body.seats,
        parcelSize: body.parcelSize,
        parcelComment: body.parcelSize !== 'none' ? (body.parcelComment ?? null) : null,
        stops,
        services: body.extras,
      });
      logEvent('order_created', { order_id: id, kind: body.kind });
      return (await this.view(tx, id, viewerId)) as OrderDetails;
    });
  }

  /** Лента водителя: открытые чужие заказы, выезд ↑; «поблизости» — первая точка в 30 км. */
  async search(viewerId: string, query: OrderSearchQuery): Promise<OrderCard[]> {
    let rows = await feedOrderIds(this.db, viewerId, query);
    if (query.near && typeof query.lat === 'number' && typeof query.lng === 'number') {
      const stops = await orderStopsOf(this.db, rows.map((r) => r.id));
      const point = { lat: query.lat, lng: query.lng };
      rows = rows.filter((r) => {
        const start = stops.get(r.id)?.[0];
        return start !== undefined && haversineKm(point, pointOf(start)) <= SAME_PLACE_KM;
      });
    }
    return orderCards(this.db, rows.map((r) => r.id), { viewerId, lat: query.lat, lng: query.lng });
  }

  /** Свои заказы любого статуса, новые сверху. */
  async mine(viewerId: string): Promise<OrderCard[]> {
    const rows = await this.db
      .select({ id: orders.id })
      .from(orders)
      .where(eq(orders.passengerId, viewerId))
      .orderBy(desc(orders.createdAt), desc(orders.id));
    return orderCards(this.db, rows.map((r) => r.id), { viewerId });
  }

  /** Владельцу — всегда; остальным — только открытый, с подходящими своими поездками. */
  async details(viewerId: string, orderId: string): Promise<OrderDetails> {
    const view = await this.view(this.db, orderId, viewerId);
    if (!view || (!view.isMine && view.status !== 'open')) throw new AppError('not_found', 'Заказ не найден');
    return view;
  }

  /** Пассажир отменяет открытый заказ; в счёт 2/30 не идёт. */
  async cancel(viewerId: string, orderId: string): Promise<OrderDetails> {
    return this.db.transaction(async (tx) => {
      const order = await loadOrder(tx, orderId, true);
      if (!order || order.passengerId !== viewerId) throw new AppError('not_found', 'Заказ не найден');
      if (order.status !== 'open') throw new AppError('invalid_transition', 'Заказ уже не открыт');
      await tx.update(orders).set({ status: 'cancelled', cancelledAt: new Date() }).where(eq(orders.id, orderId));
      logEvent('order_cancelled', { order_id: orderId });
      return (await this.view(tx, orderId, viewerId)) as OrderDetails;
    });
  }

  /** Отклик водителя своей поездкой (путь «а»): бронь «Ожидает оплаты» в ней. */
  async respond(viewerId: string, orderId: string, body: OrderResponseInput): Promise<Booking> {
    return this.db.transaction(async (tx) => {
      const bookingId = await respondToOrder(tx, { orderId, tripId: body.tripId, driverId: viewerId, via: 'trip' });
      const [view] = await bookingViews(tx, [bookingId], { viewerId });
      return view;
    });
  }

  /** Форма `OrderDetails` для зрителя; заказа нет — `null`. */
  private async view(tx: DbExecutor, orderId: string, viewerId: string): Promise<OrderDetails | null> {
    const [card] = await orderCards(tx, [orderId], { viewerId });
    if (!card) return null;
    const isMine = card.passenger.id === viewerId;
    const stops = (await orderStopsOf(tx, [orderId])).get(orderId) ?? [];
    let matchingTrips: OrderDetails['matchingTrips'] = [];
    if (!isMine && card.status === 'open') {
      const order = await loadOrder(tx, orderId);
      const matches = order ? await matchingTripsFor(tx, order, viewerId) : [];
      const cards = await tripCards(tx, matches.map((m) => m.tripId), { viewerId });
      const cardById = new Map(cards.map((c) => [c.id, c]));
      matchingTrips = matches.flatMap((m) => {
        const trip = cardById.get(m.tripId);
        return trip ? [{ trip, fromIdx: m.fromIdx, toIdx: m.toIdx, priceTotal: m.priceTotal }] : [];
      });
    }
    return { ...card, stops: stops.map(plainStop), isMine, matchingTrips };
  }
}
