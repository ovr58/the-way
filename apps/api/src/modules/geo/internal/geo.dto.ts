import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString } from 'class-validator';
import { Place } from '../../../common/forms';

export class GeoSuggestQuery {
  @ApiProperty()
  @IsString()
  q!: string;

  /** Город для `proximity`. */
  @ApiPropertyOptional({ type: 'integer' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  cityId?: number;
}

export class GeoSuggestion {
  @ApiProperty()
  label!: string;

  /** Короткий вид для карточки поездки: «<улица>, <дом>»; без дома — улица; пункт — его имя (PN-2). */
  @ApiProperty()
  shortLabel!: string;

  @ApiProperty({ type: Number })
  lat!: number;

  @ApiProperty({ type: Number })
  lng!: number;

  @ApiProperty({ type: Place })
  place!: Place;
}
