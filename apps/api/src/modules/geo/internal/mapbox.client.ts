/**
 * Клиент Mapbox Geocoding v6 forward. Токен приходит параметром и в сообщения ошибок не
 * попадает. Без `country`: проверяющий может быть вне РФ.
 */
const ENDPOINT = 'https://api.mapbox.com/search/geocode/v6/forward';
const TIMEOUT_MS = 3000;

interface MapboxContextItem {
  name?: string;
}

export interface MapboxFeature {
  properties?: {
    name?: string;
    name_preferred?: string;
    full_address?: string;
    feature_type?: string;
    context?: {
      address?: MapboxContextItem & { address_number?: string; street_name?: string };
      street?: MapboxContextItem;
      place?: MapboxContextItem;
      locality?: MapboxContextItem;
      region?: MapboxContextItem;
      country?: MapboxContextItem;
    };
  };
  /** `[lng, lat]`. */
  geometry?: { coordinates?: number[] };
}

export interface MapboxRequest {
  q: string;
  token: string;
  proximity?: { lat: number; lng: number };
}

export interface MapboxClient {
  /** Бросает при сетевой ошибке, таймауте (3 с) и ответе не 2xx. */
  forward(request: MapboxRequest): Promise<MapboxFeature[]>;
}

export const MAPBOX_CLIENT = Symbol('MAPBOX_CLIENT');

export function createMapboxClient(fetchImpl: typeof fetch = fetch): MapboxClient {
  return {
    async forward({ q, token, proximity }) {
      const url = new URL(ENDPOINT);
      url.searchParams.set('q', q);
      url.searchParams.set('language', 'ru');
      url.searchParams.set('limit', '5');
      if (proximity) url.searchParams.set('proximity', `${proximity.lng},${proximity.lat}`);
      url.searchParams.set('access_token', token);
      const res = await fetchImpl(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
      if (!res.ok) throw new Error(`mapbox ответил ${res.status}`);
      const body = (await res.json()) as { features?: MapboxFeature[] };
      return body.features ?? [];
    },
  };
}
