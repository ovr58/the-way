/**
 * Значения перечислений контракта — один носитель для схемы базы (`pgEnum`) и для OpenAPI
 * (`@ApiProperty({ enum, enumName })`). Смысл значений — «Контракт данных».
 */

export const USER_MODES = ['passenger', 'driver'] as const;
export type UserMode = (typeof USER_MODES)[number];

export const CITY_SOURCES = ['seed', 'mapbox'] as const;
export type CitySource = (typeof CITY_SOURCES)[number];

/** `cars.kind` и `trips.vehicle_kind` — одно перечисление. */
export const VEHICLE_KINDS = ['car', 'bus'] as const;
export type VehicleKind = (typeof VEHICLE_KINDS)[number];

export const CAR_STATUSES = ['pending', 'verified', 'rejected'] as const;
export type CarStatus = (typeof CAR_STATUSES)[number];

export const CAR_DOCUMENT_KINDS = ['sts'] as const;
export type CarDocumentKind = (typeof CAR_DOCUMENT_KINDS)[number];

export const ADMIN_CHECK_SUBJECTS = ['user_photo', 'car', 'car_document'] as const;
export const ADMIN_CHECK_STATUSES = ['pending', 'approved', 'rejected'] as const;

export const TRIP_KINDS = ['ride', 'parcel'] as const;
export type TripKind = (typeof TRIP_KINDS)[number];

export const BOOKING_MODES = ['standard', 'instant'] as const;
export type BookingMode = (typeof BOOKING_MODES)[number];

/** `trips.status`; он же — множество значений `effectiveStatus`. */
export const TRIP_STATUSES = ['active', 'intake_closed', 'completed', 'cancelled'] as const;
export type TripStatus = (typeof TRIP_STATUSES)[number];

/** Услуги и размеры посылки, которые задаёт водитель (`trip_extras.kind`). */
export const EXTRA_KINDS = ['child_seat', 'pets', 'luggage', 'parcel_s', 'parcel_m', 'parcel_l'] as const;
export type ExtraKind = (typeof EXTRA_KINDS)[number];

/** Услуги, которые пассажир выбирает в брони (`extras` тела брони и `quote`), и бейджи карточки. */
export const SERVICE_KINDS = ['child_seat', 'pets', 'luggage'] as const;
export type ServiceKind = (typeof SERVICE_KINDS)[number];

/** Плашка карточки ленты («Базовые экраны - Поездки есть», «Базовые экраны - Идёт регистрация пассажиров»): «Топ» · «Ближайший»; правило — `tripCards` в `views.ts`. */
export const TRIP_BADGES = ['top', 'nearest'] as const;
export type TripBadge = (typeof TRIP_BADGES)[number];

export const PARCEL_SIZES = ['none', 'S', 'M', 'L'] as const;
export type ParcelSize = (typeof PARCEL_SIZES)[number];

/** Возимые размеры посылки (`parcelSizes` в ответе). */
export const CARRIED_PARCEL_SIZES = ['S', 'M', 'L'] as const;
export type CarriedParcelSize = (typeof CARRIED_PARCEL_SIZES)[number];

export const BOOKING_STATUSES = ['requested', 'awaiting_payment', 'paid', 'rejected', 'cancelled'] as const;
export type BookingStatus = (typeof BOOKING_STATUSES)[number];

/** `orders.status`: открыт · найден водитель · отменён. */
export const ORDER_STATUSES = ['open', 'matched', 'cancelled'] as const;
export type OrderStatusStored = (typeof ORDER_STATUSES)[number];

/** Действующий статус заказа в ответе: открытый с выездом в прошлом — `expired` (без крона). */
export const ORDER_EFFECTIVE_STATUSES = ['open', 'matched', 'cancelled', 'expired'] as const;
export type OrderStatus = (typeof ORDER_EFFECTIVE_STATUSES)[number];

export const CANCELLATION_ROLES = ['passenger', 'driver'] as const;
export type CancellationRole = (typeof CANCELLATION_ROLES)[number];

export const BLOCK_REASONS = ['cancellations', 'admin'] as const;
export type BlockReason = (typeof BLOCK_REASONS)[number];

export const COMPLAINT_STATUSES = ['open', 'closed'] as const;
export type ComplaintStatus = (typeof COMPLAINT_STATUSES)[number];

/** Фильтр списков `GET /trips/mine`, `GET /bookings/mine`. */
export const LIST_STATUSES = ['active', 'completed'] as const;
export type ListStatus = (typeof LIST_STATUSES)[number];

/** События «при открытии» (таблица «События»). */
export const UPDATE_KINDS = ['new_request', 'passenger_paid', 'driver_accepted', 'driver_rejected'] as const;
export type UpdateKind = (typeof UPDATE_KINDS)[number];

export const CLIENT_LOG_LEVELS = ['error', 'warn', 'info'] as const;
export type ClientLogLevel = (typeof CLIENT_LOG_LEVELS)[number];

/** Статус, который возвращает отмена поездки или брони. */
export const CANCELLED_STATUSES = ['cancelled'] as const;
export type CancelledStatus = (typeof CANCELLED_STATUSES)[number];
