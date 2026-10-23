import { ApiProperty, ApiPropertyOptional, OmitType, PartialType } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsUUID,
  Matches,
  Min,
  ValidateNested,
} from 'class-validator';
import {
  BOOKING_MODES,
  LIST_STATUSES,
  TRIP_KINDS,
  VEHICLE_KINDS,
  type BookingMode,
  type ListStatus,
  type TripKind,
  type VehicleKind,
} from '../../../common/enums';
import { Booking, Car, Extra, Price, Stop, StopInput, TripCard } from '../../../common/forms';

/** Строка запроса `true`/`false` → boolean. */
const toBoolean = ({ value }: { value: unknown }): unknown =>
  value === 'true' ? true : value === 'false' ? false : value;

// ── Запросы ──────────────────────────────────────────────────────────────────

/** `GET /trips` — лента; смысл фильтров — «Флаги поездки». */
export class TripSearchQuery {
  @ApiPropertyOptional({ type: 'integer' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  fromCityId?: number;

  @ApiPropertyOptional({ type: 'integer' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  toCityId?: number;

  @ApiPropertyOptional({ type: Number })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  lat?: number;

  @ApiPropertyOptional({ type: Number })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  lng?: number;

  /** «Поблизости (30 км)» — старт поездки в 30 км от `lat`, `lng`. */
  @ApiPropertyOptional({ type: Boolean })
  @IsOptional()
  @Transform(toBoolean)
  @IsBoolean()
  near?: boolean;

  @ApiPropertyOptional({ enum: TRIP_KINDS, enumName: 'TripKind' })
  @IsOptional()
  @IsIn(TRIP_KINDS)
  kind?: TripKind;

  /** По умолчанию `car`. */
  @ApiPropertyOptional({ enum: VEHICLE_KINDS, enumName: 'VehicleKind' })
  @IsOptional()
  @IsIn(VEHICLE_KINDS)
  vehicleKind?: VehicleKind;
}

export class MyTripsQuery {
  @ApiProperty({ enum: LIST_STATUSES, enumName: 'ListStatus' })
  @IsIn(LIST_STATUSES)
  status!: ListStatus;
}

export class TripLimitsQuery {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  carId!: string;

  /** Сутки в `APP_TZ`, `YYYY-MM-DD`. */
  @ApiProperty({ example: '2026-10-22', pattern: '^\\d{4}-\\d{2}-\\d{2}$' })
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  date!: string;
}

// ── Тела ─────────────────────────────────────────────────────────────────────

/** Поездка водителя; правила между полями — «Правила поездки и цены» (сервис). */
export class TripInput {
  @ApiProperty({ enum: TRIP_KINDS, enumName: 'TripKind' })
  @IsIn(TRIP_KINDS)
  kind!: TripKind;

  @ApiProperty({ enum: VEHICLE_KINDS, enumName: 'VehicleKind' })
  @IsIn(VEHICLE_KINDS)
  vehicleKind!: VehicleKind;

  @ApiProperty({ type: [StopInput] })
  @IsArray()
  @ArrayMinSize(2)
  @ValidateNested({ each: true })
  @Type(() => StopInput)
  stops!: StopInput[];

  /** ISO-8601 со смещением (`…+03:00`). */
  @ApiProperty({ type: String, format: 'date-time' })
  @IsISO8601()
  departsAt!: string;

  @ApiProperty({ type: String, format: 'date-time' })
  @IsISO8601()
  arrivesAt!: string;

  @ApiProperty({ type: 'integer' })
  @IsInt()
  @Min(0)
  seatsTotal!: number;

  @ApiProperty({ type: 'integer' })
  @IsInt()
  @Min(0)
  priceFull!: number;

  /** Цены участков между соседними точками `(k, k+1)`; при двух остановках — пусто. */
  @ApiProperty({ type: [Price] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => Price)
  prices!: Price[];

  @ApiProperty({ type: 'integer' })
  @IsInt()
  @Min(0)
  priceBoardingMin!: number;

  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  carId!: string;

  @ApiProperty({ type: [Extra] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => Extra)
  extras!: Extra[];

  @ApiProperty()
  @IsBoolean()
  parcelOnlyAllowed!: boolean;

  @ApiProperty({ type: 'integer' })
  @IsInt()
  @Min(0)
  parcelSeatsTotal!: number;

  @ApiProperty({ enum: BOOKING_MODES, enumName: 'BookingMode' })
  @IsIn(BOOKING_MODES)
  bookingMode!: BookingMode;

  /**
   * Отклик водителя новой поездкой: поездка и бронь пассажира этого
   * заказа создаются одной транзакцией; заказ уже взят — поездка не создаётся.
   */
  @ApiPropertyOptional({ type: String, format: 'uuid', nullable: true })
  @IsOptional()
  @IsUUID()
  orderId?: string | null;
}

/** `PATCH /trips/{id}` — частичная поездка; проверяется результат слияния с текущей. Заказ правкой не меняется. */
export class TripPatch extends PartialType(OmitType(TripInput, ['orderId'] as const)) {}

export class ReverseInput {
  @ApiProperty({ type: String, format: 'date-time' })
  @IsISO8601()
  departsAt!: string;

  @ApiProperty({ type: String, format: 'date-time' })
  @IsISO8601()
  arrivesAt!: string;
}

export class SeatsInput {
  @ApiProperty({ type: 'integer' })
  @IsInt()
  @Min(0)
  seatsTotal!: number;
}

export class RouteTemplateInput {
  @ApiProperty({ type: [StopInput] })
  @IsArray()
  @ArrayMinSize(2)
  @ValidateNested({ each: true })
  @Type(() => StopInput)
  stops!: StopInput[];
}

// ── Ответы ───────────────────────────────────────────────────────────────────

export class TripLimits {
  @ApiProperty({ type: 'integer' })
  forwardUsed!: number;

  @ApiProperty({ type: 'integer' })
  reverseUsed!: number;

  /** Неотменённые поездки водителя (все его авто) в календарную неделю даты (пн–вс). */
  @ApiProperty({ type: 'integer' })
  weekUsed!: number;

  @ApiProperty({ type: 'integer', example: 10 })
  weekLimit!: number;

  @ApiProperty({ type: 'integer', example: 3 })
  maxDaysAhead!: number;
}

export class TripDetails extends TripCard {
  @ApiProperty({ type: [Stop] })
  stops!: Stop[];

  @ApiProperty({ type: [Price] })
  prices!: Price[];

  @ApiProperty({ type: 'integer' })
  priceBoardingMin!: number;

  /** Услуги и размеры посылки с ценами водителя. */
  @ApiProperty({ type: [Extra] })
  extrasPriced!: Extra[];

  @ApiProperty()
  parcelOnlyAllowed!: boolean;

  @ApiProperty({ enum: BOOKING_MODES, enumName: 'BookingMode' })
  bookingMode!: BookingMode;

  @ApiProperty({ type: Car })
  car!: Car;

  @ApiProperty()
  isMine!: boolean;

  @ApiProperty()
  editLocked!: boolean;

  @ApiPropertyOptional({ type: Booking, nullable: true })
  myBooking?: Booking | null;

  @ApiPropertyOptional({ type: String, format: 'uuid', nullable: true })
  reverseOf?: string | null;

  /** Сумма `priceTotal` оплаченных броней — только водителю поездки. */
  @ApiPropertyOptional({ type: 'integer', nullable: true })
  paidTotal?: number | null;
}

export class Responder {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiPropertyOptional({ type: String, nullable: true })
  photoUrl?: string | null;
}

export class DriverTripCard extends TripCard {
  @ApiProperty({ type: 'integer' })
  requested!: number;

  @ApiProperty({ type: 'integer' })
  awaitingPayment!: number;

  @ApiProperty({ type: 'integer' })
  paid!: number;

  @ApiProperty({ type: 'integer' })
  parcels!: number;

  /** До 2 откликнувшихся по `created_at ↑` (аватары «Базовые экраны - Поездок нет»). */
  @ApiProperty({ type: [Responder] })
  responders!: Responder[];
}

export class RouteTemplate {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty({ type: [Stop] })
  stops!: Stop[];
}
