import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AuthGuard } from './common/auth.guard';
import { BlockGuard } from './common/block.guard';
import { DbModule } from './db/client';
import { AuthModule } from './modules/auth/auth.module';
import { BookingsModule } from './modules/bookings/bookings.module';
import { CarsModule } from './modules/cars/cars.module';
import { CitiesModule } from './modules/cities/cities.module';
import { FilesModule } from './modules/files/files.module';
import { GeoModule } from './modules/geo/geo.module';
import { LogsModule } from './modules/logs/logs.module';
import { OrdersModule } from './modules/orders/orders.module';
import { ReviewsModule } from './modules/reviews/reviews.module';
import { TripsModule } from './modules/trips/trips.module';
import { UsersModule } from './modules/users/users.module';

/**
 * Корневой модуль. Guard-ы глобальные и идут в порядке регистрации: сначала токен, потом
 * блокировка (её проверке нужен пользователь).
 */
@Module({
  imports: [
    DbModule,
    AuthModule,
    UsersModule,
    CitiesModule,
    FilesModule,
    CarsModule,
    TripsModule,
    BookingsModule,
    OrdersModule,
    ReviewsModule,
    GeoModule,
    LogsModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: AuthGuard },
    { provide: APP_GUARD, useClass: BlockGuard },
  ],
})
export class AppModule {}
