import { Controller, Get, Query } from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { CitiesQuery, City } from './cities.dto';
import { CitiesService } from './cities.service';

/** Открыт без токена: город выбирается до входа («Выбор города»). */
@ApiTags('cities')
@Controller()
export class CitiesController {
  constructor(private readonly service: CitiesService) {}

  @Get('cities')
  @ApiOkResponse({ type: [City] })
  listCities(@Query() query: CitiesQuery): Promise<City[]> {
    return this.service.list(query);
  }
}
