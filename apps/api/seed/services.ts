/**
 * Seed идёт тем же путём, что клиент (кадр «Базовые экраны - Поездки есть»): тела проходят ту же проверку, что
 * у контроллеров (`validationPipe` из `configure-app.ts`), затем — те же методы сервисов модулей.
 * Сервисы получают транзакцию seed вместо пула: их собственные транзакции становятся точками
 * сохранения, и заливка остаётся одной транзакцией.
 */
import type { ArgumentMetadata } from '@nestjs/common';
import type { Database, DbExecutor } from '../src/db/client';
import { validationPipe } from '../src/configure-app';
import { AuthService } from '../src/modules/auth/internal/auth.service';
import { BookingsService } from '../src/modules/bookings/internal/bookings.service';
import { CarsService } from '../src/modules/cars/internal/cars.service';
import { FilesService } from '../src/modules/files/internal/files.service';
import { OrdersService } from '../src/modules/orders/internal/orders.service';
import { TripsService } from '../src/modules/trips/internal/trips.service';
import { UsersService } from '../src/modules/users/internal/users.service';

export interface Services {
  auth: AuthService;
  users: UsersService;
  files: FilesService;
  cars: CarsService;
  trips: TripsService;
  bookings: BookingsService;
  orders: OrdersService;
}

export function services(tx: DbExecutor): Services {
  const db = tx as unknown as Database;
  return {
    auth: new AuthService(db),
    users: new UsersService(db),
    files: new FilesService(db),
    cars: new CarsService(db),
    trips: new TripsService(db),
    bookings: new BookingsService(db),
    orders: new OrdersService(db),
  };
}

const pipe = validationPipe();

/** Тело запроса после проверки контроллера: класс DTO, лишние поля и нарушения — отказ, как у клиента. */
export async function body<T>(metatype: new () => T, plain: object): Promise<T> {
  const meta: ArgumentMetadata = { type: 'body', metatype, data: undefined };
  return (await pipe.transform(plain, meta)) as T;
}
