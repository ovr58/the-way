// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TripDetails _$TripDetailsFromJson(Map<String, dynamic> json) => TripDetails(
  parcelSeatsTotal: (json['parcelSeatsTotal'] as num).toInt(),
  number: (json['number'] as num).toInt(),
  kind: TripKind.fromJson(json['kind'] as String),
  from: Stop.fromJson(json['from'] as Map<String, dynamic>),
  to: Stop.fromJson(json['to'] as Map<String, dynamic>),
  stopsCount: (json['stopsCount'] as num).toInt(),
  departsAt: DateTime.parse(json['departsAt'] as String),
  arrivesAt: DateTime.parse(json['arrivesAt'] as String),
  seatsFree: (json['seatsFree'] as num).toInt(),
  seatsTotal: (json['seatsTotal'] as num).toInt(),
  parcelSeatsFree: (json['parcelSeatsFree'] as num).toInt(),
  id: json['id'] as String,
  price: (json['price'] as num).toInt(),
  editLocked: json['editLocked'] as bool,
  isMine: json['isMine'] as bool,
  driver: UserBrief.fromJson(json['driver'] as Map<String, dynamic>),
  extras: (json['extras'] as List<dynamic>)
      .map((e) => ServiceKind.fromJson(e as String))
      .toList(),
  parcelAllowed: json['parcelAllowed'] as bool,
  parcelSizes: (json['parcelSizes'] as List<dynamic>)
      .map((e) => CarriedParcelSize.fromJson(e as String))
      .toList(),
  duplicates: (json['duplicates'] as num).toInt(),
  registrationOpen: json['registrationOpen'] as bool,
  bookable: json['bookable'] as bool,
  parcelBookable: json['parcelBookable'] as bool,
  car: Car.fromJson(json['car'] as Map<String, dynamic>),
  stops: (json['stops'] as List<dynamic>)
      .map((e) => Stop.fromJson(e as Map<String, dynamic>))
      .toList(),
  prices: (json['prices'] as List<dynamic>)
      .map((e) => Price.fromJson(e as Map<String, dynamic>))
      .toList(),
  priceBoardingMin: (json['priceBoardingMin'] as num).toInt(),
  extrasPriced: (json['extrasPriced'] as List<dynamic>)
      .map((e) => Extra.fromJson(e as Map<String, dynamic>))
      .toList(),
  parcelOnlyAllowed: json['parcelOnlyAllowed'] as bool,
  bookingMode: BookingMode.fromJson(json['bookingMode'] as String),
  effectiveStatus: TripStatus.fromJson(json['effectiveStatus'] as String),
  badge: json['badge'] == null
      ? null
      : TripBadge.fromJson(json['badge'] as String),
  distanceKm: json['distanceKm'] as num?,
  myBooking: json['myBooking'] == null
      ? null
      : Booking.fromJson(json['myBooking'] as Map<String, dynamic>),
  reverseOf: json['reverseOf'] as String?,
  paidTotal: (json['paidTotal'] as num?)?.toInt(),
);

Map<String, dynamic> _$TripDetailsToJson(TripDetails instance) =>
    <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'kind': _$TripKindEnumMap[instance.kind]!,
      'from': instance.from,
      'to': instance.to,
      'stopsCount': instance.stopsCount,
      'departsAt': instance.departsAt.toIso8601String(),
      'arrivesAt': instance.arrivesAt.toIso8601String(),
      'seatsFree': instance.seatsFree,
      'seatsTotal': instance.seatsTotal,
      'parcelSeatsFree': instance.parcelSeatsFree,
      'parcelSeatsTotal': instance.parcelSeatsTotal,
      'price': instance.price,
      'distanceKm': instance.distanceKm,
      'badge': _$TripBadgeEnumMap[instance.badge],
      'driver': instance.driver,
      'extras': instance.extras.map((e) => _$ServiceKindEnumMap[e]!).toList(),
      'parcelAllowed': instance.parcelAllowed,
      'parcelSizes': instance.parcelSizes
          .map((e) => _$CarriedParcelSizeEnumMap[e]!)
          .toList(),
      'duplicates': instance.duplicates,
      'registrationOpen': instance.registrationOpen,
      'bookable': instance.bookable,
      'parcelBookable': instance.parcelBookable,
      'effectiveStatus': _$TripStatusEnumMap[instance.effectiveStatus]!,
      'stops': instance.stops,
      'prices': instance.prices,
      'priceBoardingMin': instance.priceBoardingMin,
      'extrasPriced': instance.extrasPriced,
      'parcelOnlyAllowed': instance.parcelOnlyAllowed,
      'bookingMode': _$BookingModeEnumMap[instance.bookingMode]!,
      'car': instance.car,
      'isMine': instance.isMine,
      'editLocked': instance.editLocked,
      'myBooking': instance.myBooking,
      'reverseOf': instance.reverseOf,
      'paidTotal': instance.paidTotal,
    };

const _$TripKindEnumMap = {
  TripKind.ride: 'ride',
  TripKind.parcel: 'parcel',
  TripKind.$unknown: r'$unknown',
};

const _$TripBadgeEnumMap = {
  TripBadge.top: 'top',
  TripBadge.nearest: 'nearest',
  TripBadge.$unknown: r'$unknown',
};

const _$ServiceKindEnumMap = {
  ServiceKind.childSeat: 'child_seat',
  ServiceKind.pets: 'pets',
  ServiceKind.luggage: 'luggage',
  ServiceKind.$unknown: r'$unknown',
};

const _$CarriedParcelSizeEnumMap = {
  CarriedParcelSize.s: 'S',
  CarriedParcelSize.m: 'M',
  CarriedParcelSize.l: 'L',
  CarriedParcelSize.$unknown: r'$unknown',
};

const _$TripStatusEnumMap = {
  TripStatus.active: 'active',
  TripStatus.intakeClosed: 'intake_closed',
  TripStatus.completed: 'completed',
  TripStatus.cancelled: 'cancelled',
  TripStatus.$unknown: r'$unknown',
};

const _$BookingModeEnumMap = {
  BookingMode.standard: 'standard',
  BookingMode.instant: 'instant',
  BookingMode.$unknown: r'$unknown',
};
