import { Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { GeoSuggestion, GeoSuggestQuery } from './geo.dto';
import { GeoService } from './geo.service';

@ApiTags('geo')
@ApiBearerAuth()
@Controller()
export class GeoController {
  constructor(private readonly service: GeoService) {}

  @Get('geo/suggest')
  @ApiOkResponse({ type: [GeoSuggestion] })
  suggestAddress(@Query() query: GeoSuggestQuery): Promise<GeoSuggestion[]> {
    return this.service.suggest(query);
  }
}
