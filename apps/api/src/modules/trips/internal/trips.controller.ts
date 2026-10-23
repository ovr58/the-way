import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiCreatedResponse, ApiNoContentResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { CancelPreview, CancelResult, TripCard } from '../../../common/forms';
import { requestUserId } from '../../../common/logger';
import {
  DriverTripCard,
  MyTripsQuery,
  ReverseInput,
  RouteTemplate,
  RouteTemplateInput,
  SeatsInput,
  TripDetails,
  TripInput,
  TripLimits,
  TripLimitsQuery,
  TripPatch,
  TripSearchQuery,
} from './trips.dto';
import { TripsService } from './trips.service';

/** Пути без параметра (`mine`, `limits`) объявлены раньше `trips/:id`. */
@ApiTags('trips')
@ApiBearerAuth()
@Controller()
export class TripsController {
  constructor(private readonly service: TripsService) {}

  @Get('trips')
  @ApiOkResponse({ type: [TripCard] })
  searchTrips(@Query() query: TripSearchQuery): Promise<TripCard[]> {
    return this.service.search(requestUserId(), query);
  }

  @Get('trips/mine')
  @ApiOkResponse({ type: [DriverTripCard] })
  myTrips(@Query() query: MyTripsQuery): Promise<DriverTripCard[]> {
    return this.service.mine(requestUserId(), query);
  }

  @Get('trips/limits')
  @ApiOkResponse({ type: TripLimits })
  tripLimits(@Query() query: TripLimitsQuery): Promise<TripLimits> {
    return this.service.limits(requestUserId(), query);
  }

  @Get('trips/:id')
  @ApiOkResponse({ type: TripDetails })
  getTrip(@Param('id', ParseUUIDPipe) id: string): Promise<TripDetails> {
    return this.service.details(requestUserId(), id);
  }

  @Post('trips')
  @ApiCreatedResponse({ type: TripDetails })
  createTrip(@Body() body: TripInput): Promise<TripDetails> {
    return this.service.create(requestUserId(), body);
  }

  @Patch('trips/:id')
  @ApiOkResponse({ type: TripDetails })
  updateTrip(@Param('id', ParseUUIDPipe) id: string, @Body() body: TripPatch): Promise<TripDetails> {
    return this.service.update(requestUserId(), id, body);
  }

  @Post('trips/:id/reverse')
  @ApiCreatedResponse({ type: TripDetails })
  reverseTrip(@Param('id', ParseUUIDPipe) id: string, @Body() body: ReverseInput): Promise<TripDetails> {
    return this.service.reverse(requestUserId(), id, body);
  }

  @Post('trips/:id/seats')
  @HttpCode(200)
  @ApiOkResponse({ type: TripDetails })
  setTripSeats(@Param('id', ParseUUIDPipe) id: string, @Body() body: SeatsInput): Promise<TripDetails> {
    return this.service.setSeats(requestUserId(), id, body);
  }

  @Post('trips/:id/close-intake')
  @HttpCode(200)
  @ApiOkResponse({ type: TripDetails })
  closeTripIntake(@Param('id', ParseUUIDPipe) id: string): Promise<TripDetails> {
    return this.service.closeIntake(requestUserId(), id);
  }

  @Get('trips/:id/cancel-preview')
  @ApiOkResponse({ type: CancelPreview })
  tripCancelPreview(@Param('id', ParseUUIDPipe) id: string): Promise<CancelPreview> {
    return this.service.cancelPreview(requestUserId(), id);
  }

  @Post('trips/:id/cancel')
  @HttpCode(200)
  @ApiOkResponse({ type: CancelResult })
  cancelTrip(@Param('id', ParseUUIDPipe) id: string): Promise<CancelResult> {
    return this.service.cancel(requestUserId(), id);
  }
}

@ApiTags('trips')
@ApiBearerAuth()
@Controller()
export class RouteTemplatesController {
  constructor(private readonly service: TripsService) {}

  @Get('route-templates')
  @ApiOkResponse({ type: [RouteTemplate] })
  listRouteTemplates(): Promise<RouteTemplate[]> {
    return this.service.listTemplates(requestUserId());
  }

  @Post('route-templates')
  @ApiCreatedResponse({ type: RouteTemplate })
  createRouteTemplate(@Body() body: RouteTemplateInput): Promise<RouteTemplate> {
    return this.service.createTemplate(requestUserId(), body);
  }

  @Delete('route-templates/:id')
  @HttpCode(204)
  @ApiNoContentResponse()
  deleteRouteTemplate(@Param('id', ParseUUIDPipe) id: string): Promise<void> {
    return this.service.deleteTemplate(requestUserId(), id);
  }
}
