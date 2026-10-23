import { Inject, Injectable } from '@nestjs/common';
import { and, asc, eq, inArray, isNull } from 'drizzle-orm';
import { AppError } from '../../../common/errors';
import type { Car } from '../../../common/forms';
import type { VehicleKind } from '../../../common/enums';
import { logEvent } from '../../../common/logger';
import { BUS_SEATS_MAX, BUS_SEATS_MIN, CAR_SEATS_MAX } from '../../../common/trip-times';
import { fileUrl } from '../../../common/views';
import { DATABASE, type Database, type DbExecutor } from '../../../db/client';
import { files } from '../../files/internal/schema';
import type { CarDocumentInput, CarInput, CarPatch } from './cars.dto';
import { adminChecks, carDocuments, cars, normalizePlate } from './schema';

/** Уникальный индекс госномера у владельца. */
const PLATE_INDEX = 'cars_owner_plate_unique';

/** Нарушение уникального индекса госномера — в цепочке причин ошибки запроса (`23505`). */
function isPlateTaken(error: unknown): boolean {
  for (let e: unknown = error; typeof e === 'object' && e !== null; e = (e as { cause?: unknown }).cause) {
    const { code, constraint } = e as { code?: unknown; constraint?: unknown };
    if (code === '23505' && constraint === PLATE_INDEX) return true;
  }
  return false;
}

/** У легкового — от 1 до 8 мест, у автобуса — от 9 до 60. */
function checkCarSeats(kind: VehicleKind, seats: number): void {
  const [min, max, label] = kind === 'bus' ? [BUS_SEATS_MIN, BUS_SEATS_MAX, 'автобуса'] : [1, CAR_SEATS_MAX, 'легкового авто'];
  if (seats < min || seats > max) {
    logEvent('car_rejected', { reason: 'car_seats_out_of_range', seats });
    throw new AppError('car_seats_out_of_range', `У ${label} — от ${min} до ${max} мест`);
  }
}

/** Госномер занят у владельца — `car_plate_taken`; прочие ошибки — как есть. */
function rethrowPlate(error: unknown): never {
  if (isPlateTaken(error)) {
    logEvent('car_rejected', { reason: 'car_plate_taken' });
    throw new AppError('car_plate_taken', 'Авто с таким госномером уже есть в вашем списке');
  }
  throw error;
}

/** Автомобили водителя и документы (A3.2). */
@Injectable()
export class CarsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async list(viewerId: string): Promise<Car[]> {
    const rows = await this.db
      .select({ id: cars.id })
      .from(cars)
      .where(and(eq(cars.ownerId, viewerId), isNull(cars.deletedAt)))
      .orderBy(asc(cars.createdAt), asc(cars.id));
    return this.views(this.db, rows.map((r) => r.id));
  }

  async create(viewerId: string, body: CarInput): Promise<Car> {
    checkCarSeats(body.kind, body.seats);
    if (body.photoFileId) await this.requireOwnFile(viewerId, body.photoFileId);
    const carId = await this.db.transaction(async (tx) => {
      const [row] = await tx
        .insert(cars)
        .values({
          ownerId: viewerId,
          brand: body.brand,
          model: body.model,
          kind: body.kind,
          seats: body.seats,
          plate: normalizePlate(body.plate),
          photoFileId: body.photoFileId ?? null,
          status: 'verified',
        })
        .returning({ id: cars.id });
      await tx
        .insert(adminChecks)
        .values({ subjectKind: 'car', subjectId: row.id, status: 'approved', checkedAt: new Date() });
      return row.id;
    }).catch(rethrowPlate);
    logEvent('car_created', { car_id: carId });
    return (await this.views(this.db, [carId]))[0];
  }

  /** Правка авто («Транспортные средства»): только названные поля (null у фото — не менять); статус «Проверен» — как при добавлении (ТЗ §3). */
  async update(viewerId: string, carId: string, body: CarPatch): Promise<Car> {
    const current = await this.requireOwnCar(viewerId, carId);
    checkCarSeats(body.kind ?? current.kind, body.seats ?? current.seats);
    if (body.photoFileId) await this.requireOwnFile(viewerId, body.photoFileId);
    await this.db
      .update(cars)
      .set({
        brand: body.brand,
        model: body.model,
        kind: body.kind,
        seats: body.seats,
        plate: body.plate == null ? undefined : normalizePlate(body.plate),
        // null — «не менять», как у PATCH /me: сгенерированный клиент шлёт все поля.
        photoFileId: body.photoFileId ?? undefined,
        status: 'verified',
      })
      .where(eq(cars.id, carId))
      .catch(rethrowPlate);
    return (await this.views(this.db, [carId]))[0];
  }

  async remove(viewerId: string, carId: string): Promise<void> {
    await this.requireOwnCar(viewerId, carId);
    await this.db.update(cars).set({ deletedAt: new Date() }).where(eq(cars.id, carId));
    logEvent('car_deleted', { car_id: carId });
  }

  async addDocument(viewerId: string, carId: string, body: CarDocumentInput): Promise<Car> {
    await this.requireOwnCar(viewerId, carId);
    await this.requireOwnFile(viewerId, body.fileId);
    await this.db.insert(carDocuments).values({ carId, kind: body.kind, fileId: body.fileId });
    logEvent('car_document_added', { car_id: carId });
    return (await this.views(this.db, [carId]))[0];
  }

  /** Чужое, удалённое и несуществующее авто неразличимы — `not_found` (NFR-04). */
  private async requireOwnCar(viewerId: string, carId: string): Promise<{ kind: VehicleKind; seats: number }> {
    const [car] = await this.db
      .select({ kind: cars.kind, seats: cars.seats })
      .from(cars)
      .where(and(eq(cars.id, carId), eq(cars.ownerId, viewerId), isNull(cars.deletedAt)));
    if (!car) throw new AppError('not_found', 'Автомобиль не найден');
    return car;
  }

  private async requireOwnFile(viewerId: string, fileId: string): Promise<void> {
    const [file] = await this.db
      .select({ id: files.id })
      .from(files)
      .where(and(eq(files.id, fileId), eq(files.ownerId, viewerId)));
    if (!file) throw new AppError('validation', 'Файл не найден');
  }

  private async views(tx: DbExecutor, carIds: string[]): Promise<Car[]> {
    if (carIds.length === 0) return [];
    const [rows, docs] = await Promise.all([
      tx.select().from(cars).where(inArray(cars.id, carIds)),
      tx.select().from(carDocuments).where(inArray(carDocuments.carId, carIds)).orderBy(asc(carDocuments.createdAt), asc(carDocuments.id)),
    ]);
    const byId = new Map(rows.map((c) => [c.id, c]));
    return carIds.flatMap((id) => {
      const c = byId.get(id);
      if (!c) return [];
      return [
        {
          id: c.id,
          brand: c.brand,
          model: c.model,
          kind: c.kind,
          seats: c.seats,
          plate: normalizePlate(c.plate), // старые строки хранят номер как набран
          photoUrl: c.photoFileId ? fileUrl(c.photoFileId) : null,
          status: c.status,
          documents: docs.filter((d) => d.carId === id).map((d) => ({ id: d.id, kind: d.kind, url: fileUrl(d.fileId) })),
        },
      ];
    });
  }
}
