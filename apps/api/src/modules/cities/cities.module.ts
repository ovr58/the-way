import { Module } from '@nestjs/common';
import { CitiesController } from './internal/cities.controller';
import { CitiesService } from './internal/cities.service';

@Module({
  controllers: [CitiesController],
  providers: [CitiesService],
})
export class CitiesModule {}
