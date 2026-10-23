import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString } from 'class-validator';
import { CLIENT_LOG_LEVELS, type ClientLogLevel } from '../../../common/enums';

/** Тело `POST /client-logs` (≤ 4 КБ — предел парсера в `configure-app.ts`, сверх — 413). */
export class ClientLogBody {
  @ApiProperty({ enum: CLIENT_LOG_LEVELS, enumName: 'ClientLogLevel' })
  @IsIn(CLIENT_LOG_LEVELS)
  level!: ClientLogLevel;

  @ApiProperty()
  @IsString()
  message!: string;

  @ApiPropertyOptional({ type: String, nullable: true })
  @IsOptional()
  @IsString()
  screen?: string | null;

  @ApiPropertyOptional({ type: String, nullable: true })
  @IsOptional()
  @IsString()
  traceId?: string | null;

  @ApiProperty()
  @IsString()
  appVersion!: string;

  @ApiProperty()
  @IsString()
  device!: string;
}
