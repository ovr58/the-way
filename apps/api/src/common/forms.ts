/**
 * Общие формы контракта («Эндпоинты и формы ответа»): их отдают несколько модулей
 * (`TripCard` — в поездках и внутри `Booking`, `Car` — в авто и в деталях поездки, `Me` — во входе
 * и в профиле). Строит их `common/views.ts`; модули только возвращают.
 *
 * Входные формы, общие для нескольких тел (`StopInput`, `Price`, `Extra`), несут проверки
 * `class-validator`: глобальный `ValidationPipe` (`configure-app.ts`) отвечает на нарушение
 * кодом `validation`. Правила между полями (ровно одно из `cityId`/`place`, пары цен) — в сервисах.
 */
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import {
  BOOKING_STATUSES,
  CANCELLED_STATUSES,
  CAR_DOCUMENT_KINDS,
  CAR_STATUSES,
  CARRIED_PARCEL_SIZES,
  EXTRA_KINDS,
  PARCEL_SIZES,
  SERVICE_KINDS,
  TRIP_BADGES,
  TRIP_KINDS,
  TRIP_STATUSES,
  USER_MODES,
  VEHICLE_KINDS,
  type BookingStatus,
  type CancelledStatus,
  type CarDocumentKind,
  type CarStatus,
  type CarriedParcelSize,
  type ExtraKind,
  type ParcelSize,
  type ServiceKind,
  type TripBadge,
  type TripKind,
  type TripStatus,
  type UserMode,
  type VehicleKind,
} from './enums';

// ── Пользователь ─────────────────────────────────────────────────────────────

export class Rating {
  /** Среднее `reviews.rating`; 0 отзывов → 5. */
  @ApiProperty({ type: Number })
  value!: number;

  @ApiProperty({ type: 'integer' })
  count!: number;
}

export class UserBrief {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiPropertyOptional({ type: String, nullable: true })
  name?: string | null;

  @ApiPropertyOptional({ type: String, nullable: true })
  photoUrl?: string | null;

  @ApiProperty({ type: Rating })
  rating!: Rating;

  @ApiProperty({ type: 'integer' })
  tripsCount!: number;

  /** Только второй стороне принятой брони (`awaiting_payment`, `paid`). */
  @ApiPropertyOptional({ type: String, nullable: true })
  phone?: string | null;
}

export class CityRef {
  @ApiProperty({ type: 'integer' })
  id!: number;

  @ApiProperty()
  name!: string;
}

export class Me {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty()
  phone!: string;

  @ApiPropertyOptional({ type: String, nullable: true })
  name?: string | null;

  @ApiPropertyOptional({ type: String, nullable: true })
  photoUrl?: string | null;

  @ApiPropertyOptional({ type: CityRef, nullable: true })
  city?: CityRef | null;

  @ApiProperty({ enum: USER_MODES, enumName: 'UserMode' })
  mode!: UserMode;

  @ApiProperty({ type: Rating })
  rating!: Rating;

  @ApiProperty({ type: 'integer' })
  tripsCount!: number;

  @ApiPropertyOptional({ type: String, format: 'date-time', nullable: true })
  blockedUntil?: string | null;

  @ApiProperty({ type: 'integer' })
  cancellationsLast30!: number;
}

// ── Точки маршрута ───────────────────────────────────────────────────────────

/** Населённый пункт из подсказки `GET /geo/suggest`. */
export class Place {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  name!: string;

  @ApiProperty()
  @IsString()
  region!: string;
}

export class Stop {
  @ApiProperty({ type: 'integer' })
  idx!: number;

  @ApiProperty({ type: 'integer' })
  cityId!: number;

  @ApiProperty()
  cityName!: string;

  /** Полный адрес — детали поездки. */
  @ApiProperty()
  address!: string;

  /** Короткий адрес — карточка поездки (PN-2); без короткого из подсказки — тот же текст, что `address`. */
  @ApiProperty()
  shortAddress!: string;

  @ApiPropertyOptional({ type: Number, nullable: true })
  lat?: number | null;

  @ApiPropertyOptional({ type: Number, nullable: true })
  lng?: number | null;
}

/** Точка во входе: ровно одно из `cityId` (город из списка) или `place` (подсказка) — проверяет `resolveCityId`. */
export class StopInput {
  @ApiPropertyOptional({ type: 'integer', nullable: true })
  @IsOptional()
  @IsInt()
  cityId?: number | null;

  @ApiPropertyOptional({ type: Place, nullable: true })
  @IsOptional()
  @ValidateNested()
  @Type(() => Place)
  place?: Place | null;

  @ApiProperty()
  @IsString()
  address!: string;

  /** `GeoSuggestion.shortLabel` выбранной подсказки; нет — карточка покажет `address`. */
  @ApiPropertyOptional({ type: String, nullable: true })
  @IsOptional()
  @IsString()
  shortAddress?: string | null;

  @ApiPropertyOptional({ type: Number, nullable: true })
  @IsOptional()
  @IsNumber()
  lat?: number | null;

  @ApiPropertyOptional({ type: Number, nullable: true })
  @IsOptional()
  @IsNumber()
  lng?: number | null;
}

/** Цена участка между соседними точками `(fromIdx, toIdx = fromIdx + 1)`, целые рубли. */
export class Price {
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
  price!: number;
}

/** Услуга или размер посылки с ценой водителя. */
export class Extra {
  @ApiProperty({ enum: EXTRA_KINDS, enumName: 'ExtraKind' })
  @IsIn(EXTRA_KINDS)
  kind!: ExtraKind;

  @ApiProperty({ type: 'integer' })
  @IsInt()
  @Min(0)
  price!: number;
}

// ── Автомобиль ───────────────────────────────────────────────────────────────

export class CarDocument {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty({ enum: CAR_DOCUMENT_KINDS, enumName: 'CarDocumentKind' })
  kind!: CarDocumentKind;

  /** `fileUrl(id)` = `/files/{id}`. */
  @ApiProperty()
  url!: string;
}

export class Car {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty()
  brand!: string;

  @ApiProperty()
  model!: string;

  @ApiProperty({ enum: VEHICLE_KINDS, enumName: 'VehicleKind' })
  kind!: VehicleKind;

  @ApiProperty({ type: 'integer' })
  seats!: number;

  @ApiProperty()
  plate!: string;

  @ApiPropertyOptional({ type: String, nullable: true })
  photoUrl?: string | null;

  @ApiProperty({ enum: CAR_STATUSES, enumName: 'CarStatus' })
  status!: CarStatus;

  @ApiProperty({ type: [CarDocument] })
  documents!: CarDocument[];
}

// ── Поездка ──────────────────────────────────────────────────────────────────

/** Карточка поездки; смысл флагов — «Флаги поездки». */
export class TripCard {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty({ type: 'integer' })
  number!: number;

  @ApiProperty({ enum: TRIP_KINDS, enumName: 'TripKind' })
  kind!: TripKind;

  @ApiProperty({ type: Stop })
  from!: Stop;

  @ApiProperty({ type: Stop })
  to!: Stop;

  @ApiProperty({ type: 'integer' })
  stopsCount!: number;

  @ApiProperty({ type: String, format: 'date-time' })
  departsAt!: string;

  @ApiProperty({ type: String, format: 'date-time' })
  arrivesAt!: string;

  @ApiProperty({ type: 'integer' })
  seatsFree!: number;

  @ApiProperty({ type: 'integer' })
  seatsTotal!: number;

  @ApiProperty({ type: 'integer' })
  parcelSeatsFree!: number;

  @ApiProperty({ type: 'integer' })
  parcelSeatsTotal!: number;

  /** `priceFull`. */
  @ApiProperty({ type: 'integer' })
  price!: number;

  @ApiPropertyOptional({ type: Number, nullable: true })
  distanceKm?: number | null;

  /** Плашка у имени водителя («Базовые экраны - Поездки есть», «Базовые экраны - Идёт регистрация пассажиров»); не больше одной — правило в «Флагах поездки». */
  @ApiPropertyOptional({ enum: TRIP_BADGES, enumName: 'TripBadge', nullable: true })
  badge?: TripBadge | null;

  @ApiProperty({ type: UserBrief })
  driver!: UserBrief;

  /** Разрешённые услуги (бейджи). */
  @ApiProperty({ enum: SERVICE_KINDS, enumName: 'ServiceKind', isArray: true })
  extras!: ServiceKind[];

  @ApiProperty()
  parcelAllowed!: boolean;

  @ApiProperty({ enum: CARRIED_PARCEL_SIZES, enumName: 'CarriedParcelSize', isArray: true })
  parcelSizes!: CarriedParcelSize[];

  @ApiProperty({ type: 'integer' })
  duplicates!: number;

  @ApiProperty()
  registrationOpen!: boolean;

  @ApiProperty()
  bookable!: boolean;

  @ApiProperty()
  parcelBookable!: boolean;

  @ApiProperty({ enum: TRIP_STATUSES, enumName: 'TripStatus' })
  effectiveStatus!: TripStatus;
}

// ── Бронь ────────────────────────────────────────────────────────────────────

export class Booking {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty({ type: 'integer' })
  number!: number;

  @ApiProperty({ enum: BOOKING_STATUSES, enumName: 'BookingStatus' })
  status!: BookingStatus;

  @ApiProperty({ type: 'integer' })
  seats!: number;

  @ApiProperty({ type: 'integer' })
  fromIdx!: number;

  @ApiProperty({ type: 'integer' })
  toIdx!: number;

  @ApiProperty({ type: Stop })
  from!: Stop;

  @ApiProperty({ type: Stop })
  to!: Stop;

  /** `segPrice(fromIdx, toIdx)`: весь маршрут — `priceFull`, иначе сумма участков. */
  @ApiProperty({ type: 'integer' })
  segmentPrice!: number;

  @ApiProperty({ enum: PARCEL_SIZES, enumName: 'ParcelSize' })
  parcelSize!: ParcelSize;

  @ApiProperty()
  parcelOnly!: boolean;

  @ApiPropertyOptional({ type: String, nullable: true })
  parcelComment?: string | null;

  /** Выбранные услуги и посылка (`parcel_<size>`) с ценами. */
  @ApiProperty({ type: [Extra] })
  extras!: Extra[];

  @ApiProperty({ type: 'integer' })
  priceTotal!: number;

  @ApiPropertyOptional({ type: Number, nullable: true })
  segmentKm?: number | null;

  @ApiProperty({ type: String, format: 'date-time' })
  createdAt!: string;

  @ApiPropertyOptional({ type: String, format: 'date-time', nullable: true })
  paidAt?: string | null;

  /** Водитель — `trip.driver` (с `phone` — только второй стороне принятой брони). */
  @ApiProperty({ type: TripCard })
  trip!: TripCard;

  @ApiProperty({ type: UserBrief })
  passenger!: UserBrief;

  /** Заказ пассажира, из которого родилась бронь (отклик водителя, план passenger-order). */
  @ApiPropertyOptional({ type: String, format: 'uuid', nullable: true })
  orderId?: string | null;

  /** Номер этого заказа: карточка пассажира показывает его вместо `number`. */
  @ApiPropertyOptional({ type: 'integer', nullable: true })
  orderNumber?: number | null;
}

// ── Отмена ───────────────────────────────────────────────────────────────────

export class CancelPreview {
  @ApiProperty({ type: 'integer' })
  cancellationsLast30!: number;

  @ApiProperty()
  willBlock!: boolean;

  @ApiPropertyOptional({ type: 'integer', nullable: true })
  refundAmount?: number | null;

  /** Идёт ли эта отмена в счёт 2/30; сервер заполняет всегда. */
  @ApiPropertyOptional({ type: Boolean, nullable: true })
  counts?: boolean | null;
}

export class Refund {
  @ApiProperty({ type: 'integer' })
  amount!: number;

  @ApiProperty({ type: 'integer' })
  days!: number;
}

export class CancelResult {
  @ApiProperty({ enum: CANCELLED_STATUSES, enumName: 'CancelledStatus' })
  status!: CancelledStatus;

  @ApiProperty({ type: 'integer' })
  cancellationsLast30!: number;

  @ApiPropertyOptional({ type: String, format: 'date-time', nullable: true })
  blockedUntil?: string | null;

  @ApiPropertyOptional({ type: Refund, nullable: true })
  refund?: Refund | null;
}
