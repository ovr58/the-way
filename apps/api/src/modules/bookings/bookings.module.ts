import { Module } from '@nestjs/common';
import { BookingsController } from './internal/bookings.controller';
import { BookingsService } from './internal/bookings.service';

@Module({
  controllers: [BookingsController],
  providers: [BookingsService],
})
export class BookingsModule {}
