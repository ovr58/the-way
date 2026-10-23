import { Module } from '@nestjs/common';
import { RouteTemplatesController, TripsController } from './internal/trips.controller';
import { TripsService } from './internal/trips.service';

@Module({
  controllers: [TripsController, RouteTemplatesController],
  providers: [TripsService],
})
export class TripsModule {}
