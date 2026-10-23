import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiCreatedResponse, ApiNoContentResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Booking, CancelPreview, CancelResult } from '../../../common/forms';
import { requestUserId } from '../../../common/logger';
import { BookingInput, MyBookingsQuery, Quote, QuoteQuery, Update } from './bookings.dto';
import { BookingsService } from './bookings.service';

/** `bookings/mine` объявлен раньше `bookings/:id`. */
@ApiTags('bookings')
@ApiBearerAuth()
@Controller()
export class BookingsController {
  constructor(private readonly service: BookingsService) {}

  @Get('trips/:id/quote')
  @ApiOkResponse({ type: Quote })
  quoteBooking(@Param('id', ParseUUIDPipe) id: string, @Query() query: QuoteQuery): Promise<Quote> {
    return this.service.quote(requestUserId(), id, query);
  }

  @Post('trips/:id/bookings')
  @ApiCreatedResponse({ type: Booking })
  createBooking(@Param('id', ParseUUIDPipe) id: string, @Body() body: BookingInput): Promise<Booking> {
    return this.service.create(requestUserId(), id, body);
  }

  @Get('trips/:id/bookings')
  @ApiOkResponse({ type: [Booking] })
  tripBookings(@Param('id', ParseUUIDPipe) id: string): Promise<Booking[]> {
    return this.service.listForTrip(requestUserId(), id);
  }

  @Get('bookings/mine')
  @ApiOkResponse({ type: [Booking] })
  myBookings(@Query() query: MyBookingsQuery): Promise<Booking[]> {
    return this.service.mine(requestUserId(), query);
  }

  @Get('bookings/:id')
  @ApiOkResponse({ type: Booking })
  getBooking(@Param('id', ParseUUIDPipe) id: string): Promise<Booking> {
    return this.service.get(requestUserId(), id);
  }

  @Post('bookings/:id/confirm')
  @HttpCode(200)
  @ApiOkResponse({ type: Booking })
  confirmBooking(@Param('id', ParseUUIDPipe) id: string): Promise<Booking> {
    return this.service.confirm(requestUserId(), id);
  }

  @Post('bookings/:id/reject')
  @HttpCode(200)
  @ApiOkResponse({ type: Booking })
  rejectBooking(@Param('id', ParseUUIDPipe) id: string): Promise<Booking> {
    return this.service.reject(requestUserId(), id);
  }

  @Post('bookings/:id/pay')
  @HttpCode(200)
  @ApiOkResponse({ type: Booking })
  payBooking(@Param('id', ParseUUIDPipe) id: string): Promise<Booking> {
    return this.service.pay(requestUserId(), id);
  }

  @Get('bookings/:id/cancel-preview')
  @ApiOkResponse({ type: CancelPreview })
  bookingCancelPreview(@Param('id', ParseUUIDPipe) id: string): Promise<CancelPreview> {
    return this.service.cancelPreview(requestUserId(), id);
  }

  @Post('bookings/:id/cancel')
  @HttpCode(200)
  @ApiOkResponse({ type: CancelResult })
  cancelBooking(@Param('id', ParseUUIDPipe) id: string): Promise<CancelResult> {
    return this.service.cancel(requestUserId(), id);
  }

  @Get('updates')
  @ApiOkResponse({ type: [Update] })
  listUpdates(): Promise<Update[]> {
    return this.service.updates(requestUserId());
  }

  @Post('updates/:bookingId/seen')
  @HttpCode(204)
  @ApiNoContentResponse()
  markUpdateSeen(@Param('bookingId', ParseUUIDPipe) bookingId: string): Promise<void> {
    return this.service.markSeen(requestUserId(), bookingId);
  }
}
