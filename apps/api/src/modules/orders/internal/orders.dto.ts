/**
 * Формы модуля `orders` (план passenger-order, «Контракт» — «Формы»). Правила между полями (места по
 * виду заказа, комментарий только к посылке, времена) — в сервисе.
 */
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
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
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import {
  ORDER_EFFECTIVE_STATUSES,
  PARCEL_SIZES,
  SERVICE_KINDS,
  TRIP_KINDS,
  type OrderStatus,
  type ParcelSize,
  type ServiceKind,
  type TripKind,
} from '../../../common/enums';
import { Stop, StopInput, TripCard, UserBrief } from '../../../common/forms';

/** Строка запроса `true`/`false` → boolean. */
const toBoolean = ({ value }: { value: unknown }): unknown =>
  value === 'true' ? true : value === 'false' ? false : value;

// ── Запросы ──────────────────────────────────────────────────────────────────

/**
 * `GET /orders` — лента заказов водителя: открытые, не свои. `fromCityId`/`toCityId` — город первой /
 * последней точки заказа; `near` — первая точка в 30 км от `lat`, `lng`.
 */
export class OrderSearchQuery {
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

  @ApiPropertyOptional({ type: Boolean })
  @IsOptional()
  @Transform(toBoolean)
  @IsBoolean()
  near?: boolean;

  @ApiPropertyOptional({ enum: TRIP_KINDS, enumName: 'TripKind' })
  @IsOptional()
  @IsIn(TRIP_KINDS)
  kind?: TripKind;
}

// ── Тела ─────────────────────────────────────────────────────────────────────

/**
 * Заказ пассажира — шаги мастера «Новый заказ - Тип заказа» (вид), «Новый заказ - Маршрут» – «Новый заказ - кол-во пассажиров» (точки, дата, время выезда и прибытия, места),
 * «Новый заказ - Выбор доп услуг»/«Новый заказ - Выбор веса посылки» (услуги, посылка). `kind = ride` — мест 1–8, посылка необязательна; `kind = parcel` —
 * мест 0 и размер посылки обязателен.
 */
export class OrderInput {
  @ApiProperty({ enum: TRIP_KINDS, enumName: 'TripKind' })
  @IsIn(TRIP_KINDS)
  kind!: TripKind;

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
  seats!: number;

  @ApiProperty({ enum: PARCEL_SIZES, enumName: 'ParcelSize' })
  @IsIn(PARCEL_SIZES)
  parcelSize!: ParcelSize;

  /** «Комментарий — Вид посылки», только при `parcelSize ≠ none`. */
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

/** Отклик водителя своей поездкой (путь «а»). */
export class OrderResponseInput {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  tripId!: string;
}

// ── Ответы ───────────────────────────────────────────────────────────────────

/** Карточка заказа: лента водителя (образец «Базовые экраны - Поездки есть») и «Мои заказы» пассажира (образец «Мои заказы - Есть заказы»). */
export class OrderCard {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  /** «Заказ №». */
  @ApiProperty({ type: 'integer' })
  number!: number;

  @ApiProperty({ enum: TRIP_KINDS, enumName: 'TripKind' })
  kind!: TripKind;

  @ApiProperty({ type: Stop })
  from!: Stop;

  @ApiProperty({ type: Stop })
  to!: Stop;

  /** Число промежуточных точек (`n − 2`). */
  @ApiProperty({ type: 'integer' })
  stopsCount!: number;

  @ApiProperty({ type: String, format: 'date-time' })
  departsAt!: string;

  @ApiProperty({ type: String, format: 'date-time' })
  arrivesAt!: string;

  @ApiProperty({ type: 'integer' })
  seats!: number;

  @ApiProperty({ enum: PARCEL_SIZES, enumName: 'ParcelSize' })
  parcelSize!: ParcelSize;

  /** `kind = parcel` — посылка без проезда пассажира. */
  @ApiProperty()
  parcelOnly!: boolean;

  @ApiPropertyOptional({ type: String, nullable: true })
  parcelComment?: string | null;

  @ApiProperty({ enum: SERVICE_KINDS, enumName: 'ServiceKind', isArray: true })
  extras!: ServiceKind[];

  @ApiProperty({ type: UserBrief })
  passenger!: UserBrief;

  /** От точки зрителя до первой точки заказа — при `lat`, `lng` запроса ленты. */
  @ApiPropertyOptional({ type: Number, nullable: true })
  distanceKm?: number | null;

  /** Действующий статус. */
  @ApiProperty({ enum: ORDER_EFFECTIVE_STATUSES, enumName: 'OrderStatus' })
  status!: OrderStatus;

  /** Бронь взятого заказа: живая, иначе последняя; у открытого — нет. */
  @ApiPropertyOptional({ type: String, format: 'uuid', nullable: true })
  bookingId?: string | null;

  @ApiProperty({ type: String, format: 'date-time' })
  createdAt!: string;
}

/** Своя поездка водителя, подходящая под заказ, и сумма брони пассажира в ней. */
export class OrderTripMatch {
  @ApiProperty({ type: TripCard })
  trip!: TripCard;

  @ApiProperty({ type: 'integer' })
  fromIdx!: number;

  @ApiProperty({ type: 'integer' })
  toIdx!: number;

  @ApiProperty({ type: 'integer' })
  priceTotal!: number;
}

export class OrderDetails extends OrderCard {
  @ApiProperty({ type: [Stop] })
  stops!: Stop[];

  @ApiProperty()
  isMine!: boolean;

  /** Только не владельцу и только у открытого заказа: свои поездки зрителя по выезд ↑. */
  @ApiProperty({ type: [OrderTripMatch] })
  matchingTrips!: OrderTripMatch[];
}
