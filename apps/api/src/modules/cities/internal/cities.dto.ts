import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class CitiesQuery {
  /** Подстрока имени (ILIKE); без `q` — все города. */
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  q?: string;
}

export class City {
  @ApiProperty({ type: 'integer' })
  id!: number;

  @ApiProperty()
  name!: string;

  @ApiProperty()
  region!: string;

  @ApiProperty({ type: Number })
  lat!: number;

  @ApiProperty({ type: Number })
  lng!: number;
}
