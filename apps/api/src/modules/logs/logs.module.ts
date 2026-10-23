import { Module } from '@nestjs/common';
import { LogsController } from './internal/logs.controller';
import { LogsService } from './internal/logs.service';

@Module({
  controllers: [LogsController],
  providers: [LogsService],
})
export class LogsModule {}
