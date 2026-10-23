import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiNoContentResponse, ApiTags } from '@nestjs/swagger';
import { optionalUserId } from '../../../common/logger';
import { ClientLogBody } from './logs.dto';
import { LogsService } from './logs.service';

/** Принимается и без токена: ошибки шлются и до входа. */
@ApiTags('logs')
@Controller()
export class LogsController {
  constructor(private readonly service: LogsService) {}

  @Post('client-logs')
  @HttpCode(204)
  @ApiBearerAuth()
  @ApiNoContentResponse()
  writeClientLog(@Body() body: ClientLogBody): Promise<void> {
    return this.service.write(optionalUserId(), body);
  }
}
