import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiCreatedResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Booking } from '../../../common/forms';
import { requestUserId } from '../../../common/logger';
import { OrderCard, OrderDetails, OrderInput, OrderResponseInput, OrderSearchQuery } from './orders.dto';
import { OrdersService } from './orders.service';

/** Заказы пассажиров (план passenger-order). `orders/mine` объявлен раньше `orders/:id`. */
@ApiTags('orders')
@ApiBearerAuth()
@Controller()
export class OrdersController {
  constructor(private readonly service: OrdersService) {}

  @Post('orders')
  @ApiCreatedResponse({ type: OrderDetails })
  createOrder(@Body() body: OrderInput): Promise<OrderDetails> {
    return this.service.create(requestUserId(), body);
  }

  @Get('orders')
  @ApiOkResponse({ type: [OrderCard] })
  searchOrders(@Query() query: OrderSearchQuery): Promise<OrderCard[]> {
    return this.service.search(requestUserId(), query);
  }

  @Get('orders/mine')
  @ApiOkResponse({ type: [OrderCard] })
  myOrders(): Promise<OrderCard[]> {
    return this.service.mine(requestUserId());
  }

  @Get('orders/:id')
  @ApiOkResponse({ type: OrderDetails })
  getOrder(@Param('id', ParseUUIDPipe) id: string): Promise<OrderDetails> {
    return this.service.details(requestUserId(), id);
  }

  @Post('orders/:id/cancel')
  @HttpCode(200)
  @ApiOkResponse({ type: OrderDetails })
  cancelOrder(@Param('id', ParseUUIDPipe) id: string): Promise<OrderDetails> {
    return this.service.cancel(requestUserId(), id);
  }

  @Post('orders/:id/respond')
  @ApiCreatedResponse({ type: Booking })
  respondToOrder(@Param('id', ParseUUIDPipe) id: string, @Body() body: OrderResponseInput): Promise<Booking> {
    return this.service.respond(requestUserId(), id, body);
  }
}
