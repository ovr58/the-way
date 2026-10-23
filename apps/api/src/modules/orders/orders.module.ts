import { Module } from '@nestjs/common';
import { OrdersController } from './internal/orders.controller';
import { OrdersService } from './internal/orders.service';

@Module({
  controllers: [OrdersController],
  providers: [OrdersService],
})
export class OrdersModule {}
