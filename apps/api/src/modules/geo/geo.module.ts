import { Module } from '@nestjs/common';
import { GeoController } from './internal/geo.controller';
import { GeoService } from './internal/geo.service';

@Module({
  controllers: [GeoController],
  providers: [GeoService],
})
export class GeoModule {}
