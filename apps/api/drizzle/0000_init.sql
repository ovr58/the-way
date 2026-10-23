CREATE TYPE "public"."booking_status" AS ENUM('requested', 'awaiting_payment', 'paid', 'rejected', 'cancelled');--> statement-breakpoint
CREATE TYPE "public"."parcel_size" AS ENUM('none', 'S', 'M', 'L');--> statement-breakpoint
CREATE TYPE "public"."admin_check_status" AS ENUM('pending', 'approved', 'rejected');--> statement-breakpoint
CREATE TYPE "public"."admin_check_subject" AS ENUM('user_photo', 'car', 'car_document');--> statement-breakpoint
CREATE TYPE "public"."car_document_kind" AS ENUM('sts');--> statement-breakpoint
CREATE TYPE "public"."car_status" AS ENUM('pending', 'verified', 'rejected');--> statement-breakpoint
CREATE TYPE "public"."vehicle_kind" AS ENUM('car', 'bus');--> statement-breakpoint
CREATE TYPE "public"."city_source" AS ENUM('seed', 'mapbox');--> statement-breakpoint
CREATE TYPE "public"."complaint_status" AS ENUM('open', 'closed');--> statement-breakpoint
CREATE TYPE "public"."booking_mode" AS ENUM('standard', 'instant');--> statement-breakpoint
CREATE TYPE "public"."extra_kind" AS ENUM('child_seat', 'pets', 'luggage', 'parcel_s', 'parcel_m', 'parcel_l');--> statement-breakpoint
CREATE TYPE "public"."trip_kind" AS ENUM('ride', 'parcel');--> statement-breakpoint
CREATE TYPE "public"."trip_status" AS ENUM('active', 'intake_closed', 'completed', 'cancelled');--> statement-breakpoint
CREATE TYPE "public"."block_reason" AS ENUM('cancellations', 'admin');--> statement-breakpoint
CREATE TYPE "public"."cancellation_role" AS ENUM('passenger', 'driver');--> statement-breakpoint
CREATE TYPE "public"."user_mode" AS ENUM('passenger', 'driver');--> statement-breakpoint
CREATE TABLE "sessions" (
	"token_hash" text PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "sessions_token_hash_length" CHECK (length("sessions"."token_hash") = 64)
);
--> statement-breakpoint
CREATE TABLE "booking_extras" (
	"booking_id" uuid NOT NULL,
	"kind" "extra_kind" NOT NULL,
	"price" integer NOT NULL,
	CONSTRAINT "booking_extras_booking_id_kind_pk" PRIMARY KEY("booking_id","kind")
);
--> statement-breakpoint
CREATE TABLE "bookings" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"number" serial NOT NULL,
	"trip_id" uuid NOT NULL,
	"passenger_id" uuid NOT NULL,
	"from_idx" integer NOT NULL,
	"to_idx" integer NOT NULL,
	"seats" integer NOT NULL,
	"parcel_size" "parcel_size" DEFAULT 'none' NOT NULL,
	"parcel_only" boolean DEFAULT false NOT NULL,
	"parcel_comment" text,
	"price_total" integer NOT NULL,
	"status" "booking_status" NOT NULL,
	"passenger_seen_status" "booking_status",
	"driver_seen_status" "booking_status",
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"confirmed_at" timestamp with time zone,
	"paid_at" timestamp with time zone,
	"rejected_at" timestamp with time zone,
	"cancelled_at" timestamp with time zone,
	CONSTRAINT "bookings_number_unique" UNIQUE("number")
);
--> statement-breakpoint
CREATE TABLE "admin_checks" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"subject_kind" "admin_check_subject" NOT NULL,
	"subject_id" uuid NOT NULL,
	"status" "admin_check_status" NOT NULL,
	"note" text,
	"checked_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "car_documents" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"car_id" uuid NOT NULL,
	"kind" "car_document_kind" NOT NULL,
	"file_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "cars" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"owner_id" uuid NOT NULL,
	"brand" text NOT NULL,
	"model" text NOT NULL,
	"kind" "vehicle_kind" NOT NULL,
	"seats" integer NOT NULL,
	"plate" text NOT NULL,
	"photo_file_id" uuid,
	"status" "car_status" DEFAULT 'verified' NOT NULL,
	"deleted_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "cities" (
	"id" serial PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"region" text NOT NULL,
	"lat" double precision NOT NULL,
	"lng" double precision NOT NULL,
	"source" "city_source" DEFAULT 'seed' NOT NULL,
	CONSTRAINT "cities_name_region_unique" UNIQUE("name","region")
);
--> statement-breakpoint
CREATE TABLE "files" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"owner_id" uuid NOT NULL,
	"mime" text NOT NULL,
	"path" text NOT NULL,
	"size" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "complaints" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"author_id" uuid NOT NULL,
	"target_id" uuid NOT NULL,
	"trip_id" uuid,
	"reason" text NOT NULL,
	"status" "complaint_status" DEFAULT 'open' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "reviews" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"author_id" uuid NOT NULL,
	"target_id" uuid NOT NULL,
	"trip_id" uuid NOT NULL,
	"booking_id" uuid,
	"rating" smallint NOT NULL,
	"body" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "reviews_author_booking_unique" UNIQUE("author_id","booking_id"),
	CONSTRAINT "reviews_rating_range" CHECK ("reviews"."rating" between 1 and 5)
);
--> statement-breakpoint
CREATE TABLE "route_templates" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"stops" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "trip_extras" (
	"trip_id" uuid NOT NULL,
	"kind" "extra_kind" NOT NULL,
	"price" integer NOT NULL,
	CONSTRAINT "trip_extras_trip_id_kind_pk" PRIMARY KEY("trip_id","kind")
);
--> statement-breakpoint
CREATE TABLE "trip_prices" (
	"trip_id" uuid NOT NULL,
	"from_idx" integer NOT NULL,
	"to_idx" integer NOT NULL,
	"price" integer NOT NULL,
	CONSTRAINT "trip_prices_trip_id_from_idx_to_idx_pk" PRIMARY KEY("trip_id","from_idx","to_idx")
);
--> statement-breakpoint
CREATE TABLE "trip_stops" (
	"trip_id" uuid NOT NULL,
	"idx" integer NOT NULL,
	"city_id" integer NOT NULL,
	"address" text NOT NULL,
	"lat" double precision,
	"lng" double precision,
	CONSTRAINT "trip_stops_trip_id_idx_pk" PRIMARY KEY("trip_id","idx")
);
--> statement-breakpoint
CREATE TABLE "trips" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"driver_id" uuid NOT NULL,
	"car_id" uuid NOT NULL,
	"kind" "trip_kind" NOT NULL,
	"vehicle_kind" "vehicle_kind" NOT NULL,
	"departs_at" timestamp with time zone NOT NULL,
	"arrives_at" timestamp with time zone NOT NULL,
	"seats_total" integer NOT NULL,
	"seats_taken" integer DEFAULT 0 NOT NULL,
	"price_full" integer NOT NULL,
	"price_boarding_min" integer NOT NULL,
	"booking_mode" "booking_mode" NOT NULL,
	"status" "trip_status" DEFAULT 'active' NOT NULL,
	"reverse_of" uuid,
	"number" serial NOT NULL,
	"parcel_only_allowed" boolean DEFAULT false NOT NULL,
	"parcel_seats_total" integer DEFAULT 0 NOT NULL,
	"parcel_seats_taken" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"cancelled_at" timestamp with time zone,
	CONSTRAINT "trips_number_unique" UNIQUE("number")
);
--> statement-breakpoint
CREATE TABLE "blocks" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"reason" "block_reason" NOT NULL,
	"starts_at" timestamp with time zone NOT NULL,
	"ends_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "cancellations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"role" "cancellation_role" NOT NULL,
	"booking_id" uuid,
	"trip_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"phone" text NOT NULL,
	"name" text,
	"photo_file_id" uuid,
	"city_id" integer,
	"current_mode" "user_mode" DEFAULT 'passenger' NOT NULL,
	"blocked_until" timestamp with time zone,
	"admin_blocked" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "users_phone_unique" UNIQUE("phone")
);
--> statement-breakpoint
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "booking_extras" ADD CONSTRAINT "booking_extras_booking_id_bookings_id_fk" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_passenger_id_users_id_fk" FOREIGN KEY ("passenger_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "car_documents" ADD CONSTRAINT "car_documents_car_id_cars_id_fk" FOREIGN KEY ("car_id") REFERENCES "public"."cars"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "car_documents" ADD CONSTRAINT "car_documents_file_id_files_id_fk" FOREIGN KEY ("file_id") REFERENCES "public"."files"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cars" ADD CONSTRAINT "cars_owner_id_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cars" ADD CONSTRAINT "cars_photo_file_id_files_id_fk" FOREIGN KEY ("photo_file_id") REFERENCES "public"."files"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "files" ADD CONSTRAINT "files_owner_id_users_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_author_id_users_id_fk" FOREIGN KEY ("author_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_target_id_users_id_fk" FOREIGN KEY ("target_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_author_id_users_id_fk" FOREIGN KEY ("author_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_target_id_users_id_fk" FOREIGN KEY ("target_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_booking_id_bookings_id_fk" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "route_templates" ADD CONSTRAINT "route_templates_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "trip_extras" ADD CONSTRAINT "trip_extras_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "trip_prices" ADD CONSTRAINT "trip_prices_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "trip_stops" ADD CONSTRAINT "trip_stops_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "trip_stops" ADD CONSTRAINT "trip_stops_city_id_cities_id_fk" FOREIGN KEY ("city_id") REFERENCES "public"."cities"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "trips" ADD CONSTRAINT "trips_driver_id_users_id_fk" FOREIGN KEY ("driver_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "trips" ADD CONSTRAINT "trips_car_id_cars_id_fk" FOREIGN KEY ("car_id") REFERENCES "public"."cars"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "trips" ADD CONSTRAINT "trips_reverse_of_trips_id_fk" FOREIGN KEY ("reverse_of") REFERENCES "public"."trips"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "blocks" ADD CONSTRAINT "blocks_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cancellations" ADD CONSTRAINT "cancellations_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cancellations" ADD CONSTRAINT "cancellations_booking_id_bookings_id_fk" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cancellations" ADD CONSTRAINT "cancellations_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_photo_file_id_files_id_fk" FOREIGN KEY ("photo_file_id") REFERENCES "public"."files"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_city_id_cities_id_fk" FOREIGN KEY ("city_id") REFERENCES "public"."cities"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "bookings_active_trip_passenger_unique" ON "bookings" USING btree ("trip_id","passenger_id") WHERE "bookings"."status" in ('requested', 'awaiting_payment', 'paid');