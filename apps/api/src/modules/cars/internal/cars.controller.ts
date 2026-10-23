import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiCreatedResponse, ApiNoContentResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Car } from '../../../common/forms';
import { requestUserId } from '../../../common/logger';
import { CarDocumentInput, CarInput, CarPatch } from './cars.dto';
import { CarsService } from './cars.service';

@ApiTags('cars')
@ApiBearerAuth()
@Controller()
export class CarsController {
  constructor(private readonly service: CarsService) {}

  @Get('cars')
  @ApiOkResponse({ type: [Car] })
  listCars(): Promise<Car[]> {
    return this.service.list(requestUserId());
  }

  @Post('cars')
  @ApiCreatedResponse({ type: Car })
  createCar(@Body() body: CarInput): Promise<Car> {
    return this.service.create(requestUserId(), body);
  }

  @Patch('cars/:id')
  @ApiOkResponse({ type: Car })
  updateCar(@Param('id', ParseUUIDPipe) id: string, @Body() body: CarPatch): Promise<Car> {
    return this.service.update(requestUserId(), id, body);
  }

  @Delete('cars/:id')
  @HttpCode(204)
  @ApiNoContentResponse()
  deleteCar(@Param('id', ParseUUIDPipe) id: string): Promise<void> {
    return this.service.remove(requestUserId(), id);
  }

  @Post('cars/:id/documents')
  @ApiCreatedResponse({ type: Car })
  addCarDocument(@Param('id', ParseUUIDPipe) id: string, @Body() body: CarDocumentInput): Promise<Car> {
    return this.service.addDocument(requestUserId(), id, body);
  }
}
