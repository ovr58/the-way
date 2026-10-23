/**
 * Перечисления PostgreSQL. Живут отдельно от схем модулей: ими пользуются несколько модулей
 * (`vehicle_kind` — `cars` и `trips`, `extra_kind` — `trips` и `bookings`), а схемы ссылаются
 * друг на друга внешними ключами — значение перечисления, взятое из чужой схемы при её
 * незавершённой загрузке (цикл импортов), было бы `undefined`. Каждое перечисление
 * экспортируется ровно из одной схемы-владельца, чтобы `drizzle-kit` его увидел.
 */
import { pgEnum } from 'drizzle-orm/pg-core';
import {
  ADMIN_CHECK_STATUSES,
  ADMIN_CHECK_SUBJECTS,
  BLOCK_REASONS,
  BOOKING_MODES,
  BOOKING_STATUSES,
  CANCELLATION_ROLES,
  CAR_DOCUMENT_KINDS,
  CAR_STATUSES,
  CITY_SOURCES,
  COMPLAINT_STATUSES,
  EXTRA_KINDS,
  ORDER_STATUSES,
  PARCEL_SIZES,
  TRIP_KINDS,
  TRIP_STATUSES,
  USER_MODES,
  VEHICLE_KINDS,
} from '../common/enums';

export const userModeEnum = pgEnum('user_mode', USER_MODES);
export const citySourceEnum = pgEnum('city_source', CITY_SOURCES);
export const vehicleKindEnum = pgEnum('vehicle_kind', VEHICLE_KINDS);
export const carStatusEnum = pgEnum('car_status', CAR_STATUSES);
export const carDocumentKindEnum = pgEnum('car_document_kind', CAR_DOCUMENT_KINDS);
export const adminCheckSubjectEnum = pgEnum('admin_check_subject', ADMIN_CHECK_SUBJECTS);
export const adminCheckStatusEnum = pgEnum('admin_check_status', ADMIN_CHECK_STATUSES);
export const tripKindEnum = pgEnum('trip_kind', TRIP_KINDS);
export const bookingModeEnum = pgEnum('booking_mode', BOOKING_MODES);
export const tripStatusEnum = pgEnum('trip_status', TRIP_STATUSES);
export const extraKindEnum = pgEnum('extra_kind', EXTRA_KINDS);
export const parcelSizeEnum = pgEnum('parcel_size', PARCEL_SIZES);
export const bookingStatusEnum = pgEnum('booking_status', BOOKING_STATUSES);
export const cancellationRoleEnum = pgEnum('cancellation_role', CANCELLATION_ROLES);
export const blockReasonEnum = pgEnum('block_reason', BLOCK_REASONS);
export const complaintStatusEnum = pgEnum('complaint_status', COMPLAINT_STATUSES);
export const orderStatusEnum = pgEnum('order_status', ORDER_STATUSES);
