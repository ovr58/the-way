CREATE TYPE "public"."order_status" AS ENUM('open', 'matched', 'cancelled');--> statement-breakpoint
CREATE TABLE "order_extras" (
	"order_id" uuid NOT NULL,
	"kind" "extra_kind" NOT NULL,
	CONSTRAINT "order_extras_order_id_kind_pk" PRIMARY KEY("order_id","kind")
);
--> statement-breakpoint
CREATE TABLE "order_stops" (
	"order_id" uuid NOT NULL,
	"idx" integer NOT NULL,
	"city_id" integer NOT NULL,
	"address" text NOT NULL,
	"short_address" text,
	"lat" double precision,
	"lng" double precision,
	CONSTRAINT "order_stops_order_id_idx_pk" PRIMARY KEY("order_id","idx")
);
--> statement-breakpoint
CREATE TABLE "orders" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"number" integer DEFAULT nextval('bookings_number_seq') NOT NULL,
	"passenger_id" uuid NOT NULL,
	"kind" "trip_kind" NOT NULL,
	"departs_at" timestamp with time zone NOT NULL,
	"arrives_at" timestamp with time zone NOT NULL,
	"seats" integer NOT NULL,
	"parcel_size" "parcel_size" DEFAULT 'none' NOT NULL,
	"parcel_comment" text,
	"status" "order_status" DEFAULT 'open' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"cancelled_at" timestamp with time zone,
	CONSTRAINT "orders_number_unique" UNIQUE("number")
);
--> statement-breakpoint
ALTER TABLE "bookings" ADD COLUMN "order_id" uuid;--> statement-breakpoint
ALTER TABLE "cars" ADD COLUMN "plate_key" text GENERATED ALWAYS AS (translate(upper(regexp_replace(plate, '[^0-9A-Za-zА-Яа-яЁё]', '', 'g')), 'АВЕКМНОРСТУХавекмнорстух', 'ABEKMHOPCTYXABEKMHOPCTYX')) STORED;--> statement-breakpoint
ALTER TABLE "order_extras" ADD CONSTRAINT "order_extras_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_stops" ADD CONSTRAINT "order_stops_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_stops" ADD CONSTRAINT "order_stops_city_id_cities_id_fk" FOREIGN KEY ("city_id") REFERENCES "public"."cities"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "orders" ADD CONSTRAINT "orders_passenger_id_users_id_fk" FOREIGN KEY ("passenger_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "bookings_active_order_unique" ON "bookings" USING btree ("order_id") WHERE "bookings"."order_id" is not null and "bookings"."status" in ('requested', 'awaiting_payment', 'paid');--> statement-breakpoint
CREATE UNIQUE INDEX "cars_owner_plate_unique" ON "cars" USING btree ("owner_id","plate_key") WHERE "cars"."deleted_at" is null;