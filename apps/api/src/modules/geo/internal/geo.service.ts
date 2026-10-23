import { Inject, Injectable, Optional } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DATABASE, type Database } from '../../../db/client';
import { cities } from '../../cities/internal/schema';
import type { GeoSuggestion, GeoSuggestQuery } from './geo.dto';
import { MAPBOX_CLIENT, type MapboxClient, type MapboxFeature, createMapboxClient } from './mapbox.client';

/** Подсказка → `GeoSuggestion`; без населённого пункта или координат — `null`. */
function toSuggestion(feature: MapboxFeature): GeoSuggestion | null {
  const props = feature.properties;
  const context = props?.context;
  const isPlace = props?.feature_type === 'place' || props?.feature_type === 'locality';
  // `name` — вариант, совпавший с запросом (латиницей — «Konstantinovskiy»); `name_preferred` — на языке `language`.
  const name = (isPlace ? (props?.name_preferred ?? props?.name) : undefined) ?? context?.place?.name ?? context?.locality?.name;
  const [lng, lat] = feature.geometry?.coordinates ?? [];
  if (!name || typeof lng !== 'number' || typeof lat !== 'number') return null;
  const fullAddress = props?.full_address ?? props?.name ?? name;
  const house = context?.address;
  const shortLabel =
    house?.street_name && house.address_number
      ? `${house.street_name}, ${house.address_number}`
      : (context?.street?.name ?? (isPlace ? name : undefined) ?? props?.name_preferred ?? props?.name ?? fullAddress);
  const region = context?.region?.name ?? context?.country?.name ?? '';
  return {
    label: pointLabel(name, shortLabel, region),
    shortLabel,
    lat,
    lng,
    place: { name, region },
  };
}

/** «Город, улица, дом» без страны и индекса; пункт без улицы — «Город, область». */
function pointLabel(name: string, shortLabel: string, region: string): string {
  if (shortLabel !== name) return shortLabel.startsWith(`${name},`) ? shortLabel : `${name}, ${shortLabel}`;
  return region ? `${name}, ${region}` : name;
}

/** Подсказки адреса Mapbox; без `MAPBOX_TOKEN`, при ошибке и таймауте — `[]`. */
@Injectable()
export class GeoService {
  private readonly mapbox: MapboxClient;

  constructor(
    @Inject(DATABASE) private readonly db: Database,
    @Optional() @Inject(MAPBOX_CLIENT) mapbox?: MapboxClient,
  ) {
    this.mapbox = mapbox ?? createMapboxClient();
  }

  async suggest(query: GeoSuggestQuery): Promise<GeoSuggestion[]> {
    const token = process.env.MAPBOX_TOKEN;
    const q = query.q.trim();
    if (!token || !q) return [];
    try {
      const proximity = query.cityId === undefined ? undefined : await this.cityPoint(query.cityId);
      const features = await this.mapbox.forward({ q, token, proximity });
      return features.flatMap((f) => toSuggestion(f) ?? []);
    } catch {
      return [];
    }
  }

  private async cityPoint(cityId: number): Promise<{ lat: number; lng: number } | undefined> {
    const [city] = await this.db.select({ lat: cities.lat, lng: cities.lng }).from(cities).where(eq(cities.id, cityId));
    return city ? { lat: city.lat, lng: city.lng } : undefined;
  }
}
