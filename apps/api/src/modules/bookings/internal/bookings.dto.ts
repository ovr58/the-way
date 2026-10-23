import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import { IsArray, IsBoolean, IsIn, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import {
  LIST_STATUSES,
  PARCEL_SIZES,
  SERVICE_KINDS,
  UPDATE_KINDS,
  type ListStatus,
  type ParcelSize,
  type ServiceKind,
  type UpdateKind,
} from '../../../common/enums';

/** `a,b,c` → `['a','b','c']`; пустая строка → `[]`. */
const toList = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.split(',').map((s) => s.trim()).filter((s) => s !== '') : value;

/** `GET /trips/{id}/quote` — итог брони до отправки; `extras` — через запятую. */
export class QuoteQuery {
  @ApiProperty({ type: 'integer' })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  fromIdx!: number;

  @ApiProperty({ type: 'integer' })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  toIdx!: number;

  @ApiProperty({ type: 'integer' })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  seats!: number;

  /** По умолчанию `none`. */
  @ApiPropertyOptional({ enum: PARCEL_SIZES, enumName: 'ParcelSize' })
  @IsOptional()
  @IsIn(PARCEL_SIZES)
  parcelSize?: ParcelSize;

  /** Услуги через запятую: `child_seat,pets`. */
  @ApiPropertyOptional({ type: String, example: 'child_seat,pets' })
  @IsOptional()
  @Transform(toList)
  @IsIn(SERVICE_KINDS, { each: true })
  extras?: ServiceKind[];
}

export class Quote {
  @ApiProperty({ type: 'integer' })
  segmentPrice!: number;

  @ApiProperty({ type: 'integer' })
  priceTotal!: number;
}

/** Тело брони; правила — «Правила поездки и цены» (строка «Бронь»). */
export class BookingInput {
  @ApiProperty({ type: 'integer' })
  @IsInt()
  @Min(0)
  fromIdx!: number;

  @ApiProperty({ type: 'integer' })
  @IsInt()
  @Min(0)
  toIdx!: number;

  @ApiProperty({ type: 'integer' })
  @IsInt()
  @Min(0)
  seats!: number;

  @ApiProperty({ enum: PARCEL_SIZES, enumName: 'ParcelSize' })
  @IsIn(PARCEL_SIZES)
  parcelSize!: ParcelSize;

  @ApiProperty()
  @IsBoolean()
  parcelOnly!: boolean;

  /** «Комментарий — Вид посылки» («Бронирование»), только при `parcelSize ≠ none`. */
  @ApiPropertyOptional({ type: String, nullable: true, maxLength: 250 })
  @IsOptional()
  @IsString()
  @MaxLength(250)
  parcelComment?: string | null;

  @ApiProperty({ enum: SERVICE_KINDS, enumName: 'ServiceKind', isArray: true })
  @IsArray()
  @IsIn(SERVICE_KINDS, { each: true })
  extras!: ServiceKind[];
}

export class MyBookingsQuery {
  /** Без `status` — все брони, новые сверху. */
  @ApiPropertyOptional({ enum: LIST_STATUSES, enumName: 'ListStatus' })
  @IsOptional()
  @IsIn(LIST_STATUSES)
  status?: ListStatus;
}

/** Событие «при открытии». */
export class Update {
  @ApiProperty({ format: 'uuid' })
  bookingId!: string;

  @ApiProperty({ format: 'uuid' })
  tripId!: string;

  @ApiProperty({ enum: UPDATE_KINDS, enumName: 'UpdateKind' })
  kind!: UpdateKind;

  @ApiProperty({ type: String, format: 'date-time' })
  at!: string;
}
