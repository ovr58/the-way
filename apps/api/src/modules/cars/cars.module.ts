import { Module } from '@nestjs/common';
import { CarsController } from './internal/cars.controller';
import { CarsService } from './internal/cars.service';

@Module({
  controllers: [CarsController],
  providers: [CarsService],
})
export class CarsModule {}
