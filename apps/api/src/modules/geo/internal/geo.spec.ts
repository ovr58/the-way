/** Строка A3.4: подсказки адреса. Сеть не трогаем: клиент Mapbox — дублёр или `fetch` с заглушкой. */
import type { INestApplication } from '@nestjs/common';
import { createTestApp, call } from '../../../../test/helpers/app';
import { closeDb, createCity, createUser, db } from '../../../../test/helpers/db';
import { GeoService } from './geo.service';
import { type MapboxClient, type MapboxFeature, type MapboxRequest, createMapboxClient } from './mapbox.client';

let app: INestApplication;
const savedToken = process.env.MAPBOX_TOKEN;

beforeAll(async () => {
  delete process.env.MAPBOX_TOKEN;
  app = await createTestApp();
});

afterAll(async () => {
  if (savedToken === undefined) delete process.env.MAPBOX_TOKEN;
  else process.env.MAPBOX_TOKEN = savedToken;
  await app.close();
  await closeDb();
});

/** Дублёр `mapbox.client.ts`: отдаёт заданные features и запоминает запросы. */
function double(features: MapboxFeature[]): MapboxClient & { requests: MapboxRequest[] } {
  const requests: MapboxRequest[] = [];
  return {
    requests,
    forward: async (req) => {
      requests.push(req);
      return features;
    },
  };
}

function feature(
  label: string,
  lng: number,
  lat: number,
  context: Record<string, { name: string }>,
  properties: Record<string, unknown> = {},
): MapboxFeature {
  return {
    properties: { full_address: label, feature_type: 'address', context, ...properties },
    geometry: { coordinates: [lng, lat] },
  } as MapboxFeature;
}

const THREE = [
  feature('Ярославль, улица Свободы 1', 39.884, 57.626, { place: { name: 'Ярославль' }, region: { name: 'Ярославская область' } }),
  feature('Минск, проспект Победителей 1', 27.561, 53.902, { place: { name: 'Минск' }, country: { name: 'Беларусь' } }),
  feature('Безымянная улица', 30, 50, { region: { name: 'Где-то' } }),
];

describe('GET /geo/suggest без токена', () => {
  it('→ 200 [] и клиент Mapbox не вызывается', async () => {
    const user = await createUser();
    const res = await call(app, user.token).get('/geo/suggest').query({ q: 'Ярославль' });
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);

    const mapbox = double(THREE);
    expect(await new GeoService(db, mapbox).suggest({ q: 'Ярославль' })).toEqual([]);
    expect(mapbox.requests).toHaveLength(0);
  });

  it('без q → 400 validation', async () => {
    const user = await createUser();
    const res = await call(app, user.token).get('/geo/suggest');
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('validation');
  });
});

describe('GeoService с токеном (дублёр)', () => {
  beforeEach(() => {
    process.env.MAPBOX_TOKEN = 'test-token';
  });
  afterEach(() => {
    delete process.env.MAPBOX_TOKEN;
  });

  it('три features, у одной нет place и locality → две подсказки: lat/lng в верном порядке, place', async () => {
    const result = await new GeoService(db, double(THREE)).suggest({ q: 'адрес' });
    expect(result).toEqual([
      {
        label: 'Ярославль, улица Свободы 1',
        shortLabel: 'Ярославль, улица Свободы 1',
        lat: 57.626,
        lng: 39.884,
        place: { name: 'Ярославль', region: 'Ярославская область' },
      },
      {
        label: 'Минск, проспект Победителей 1',
        shortLabel: 'Минск, проспект Победителей 1',
        lat: 53.902,
        lng: 27.561,
        place: { name: 'Минск', region: 'Беларусь' },
      },
    ]);
  });

  it('подсказка сама населённый пункт — name из properties.name; нет place — берётся locality', async () => {
    const village = feature('Великое, Ярославская область', 39.7, 57.8, { region: { name: 'Ярославская область' } }, { feature_type: 'place', name: 'Великое' });
    const viaLocality = feature('улица, Посёлок', 38, 56, { locality: { name: 'Посёлок' }, region: { name: 'Область' } });
    const result = await new GeoService(db, double([village, viaLocality])).suggest({ q: 'x' });
    expect(result.map((s) => s.place)).toEqual([
      { name: 'Великое', region: 'Ярославская область' },
      { name: 'Посёлок', region: 'Область' },
    ]);
  });

  it('запрос латиницей: name — совпавший вариант («Konstantinovskiy»), в справочник идёт name_preferred', async () => {
    // Живой ответ Mapbox v6 на q=Konstantinovskiy, language=ru (2026-10-22).
    const village = feature(
      'Константиновский, Тутаевский район, Ярославская область, Россия',
      39.59,
      57.83,
      { region: { name: 'Ярославская область' } },
      { feature_type: 'place', name: 'Konstantinovskiy', name_preferred: 'Константиновский' },
    );
    const [suggestion] = await new GeoService(db, double([village])).suggest({ q: 'Konstantinovskiy' });
    expect(suggestion.place).toEqual({ name: 'Константиновский', region: 'Ярославская область' });
  });

  it('shortLabel — «<улица>, <дом>» для карточки (PN-2); без дома — улица; пункт — его имя', async () => {
    // Живой ответ Mapbox v6 на «Ярославль, Портовая набережная 10», language=ru (2026-10-22).
    const house = feature(
      'Россия, Ярославская область, Ярославль, Фрунзенский, 150001, Портовая набережная 10',
      39.9,
      57.6,
      {
        place: { name: 'Ярославль' },
        region: { name: 'Ярославская область' },
        address: { name: 'Портовая набережная 10', address_number: '10', street_name: 'Портовая набережная' },
        street: { name: 'Портовая набережная' },
      } as unknown as Record<string, { name: string }>,
      { name: 'Портовая набережная 10' },
    );
    const street = feature('Россия, Ярославль, улица Свободы', 39.88, 57.62, { place: { name: 'Ярославль' }, street: { name: 'улица Свободы' } }, { feature_type: 'street', name: 'улица Свободы' });
    const village = feature('Великое, Ярославская область', 39.7, 57.8, { region: { name: 'Ярославская область' } }, { feature_type: 'place', name: 'Velikoye', name_preferred: 'Великое' });
    const result = await new GeoService(db, double([house, street, village])).suggest({ q: 'x' });
    expect(result.map((r) => r.shortLabel)).toEqual(['Портовая набережная, 10', 'улица Свободы', 'Великое']);
  });

  it('label — «Город, улица, дом» без страны и индекса; пункт без улицы — «Город, область»', async () => {
    const house = feature(
      'Россия, Свердловская область, Краснотурьинск, 624447, улица Попова 18',
      60.2,
      59.77,
      {
        place: { name: 'Краснотурьинск' },
        region: { name: 'Свердловская область' },
        address: { name: 'улица Попова 18', address_number: '18', street_name: 'улица Попова' },
        street: { name: 'улица Попова' },
      } as unknown as Record<string, { name: string }>,
      { name: 'улица Попова 18' },
    );
    const town = feature('Серов, Свердловская область, Россия', 60.58, 59.6, { region: { name: 'Свердловская область' } }, { feature_type: 'place', name: 'Серов' });
    const result = await new GeoService(db, double([house, town])).suggest({ q: 'x' });
    expect(result.map((r) => r.label)).toEqual(['Краснотурьинск, улица Попова, 18', 'Серов, Свердловская область']);
  });

  it('proximity — координаты города cityId; без cityId его нет; токен уходит клиенту', async () => {
    const cityId = await createCity('Проксими', 57.5, 39.5);
    const mapbox = double(THREE);
    const service = new GeoService(db, mapbox);
    await service.suggest({ q: 'a', cityId });
    await service.suggest({ q: 'a' });
    expect(mapbox.requests[0]).toMatchObject({ q: 'a', token: 'test-token', proximity: { lat: 57.5, lng: 39.5 } });
    expect(mapbox.requests[1].proximity).toBeUndefined();
  });

  it('ошибка или таймаут клиента → []', async () => {
    const broken: MapboxClient = {
      forward: async () => {
        throw new Error('timeout');
      },
    };
    expect(await new GeoService(db, broken).suggest({ q: 'a' })).toEqual([]);
  });
});

describe('createMapboxClient', () => {
  function recordingFetch(status = 200): { fetchImpl: typeof fetch; urls: URL[] } {
    const urls: URL[] = [];
    const fetchImpl = (async (input: string | URL | Request) => {
      urls.push(new URL(String(input)));
      return new Response(JSON.stringify({ features: THREE }), { status });
    }) as typeof fetch;
    return { fetchImpl, urls };
  }

  it('запрос: v6 forward, language=ru, limit=5, токен; без proximity и без country', async () => {
    const { fetchImpl, urls } = recordingFetch();
    const features = await createMapboxClient(fetchImpl).forward({ q: 'Минск, проспект Победителей 1', token: 'tok' });
    expect(features).toHaveLength(3);
    const url = urls[0];
    expect(url.origin + url.pathname).toBe('https://api.mapbox.com/search/geocode/v6/forward');
    expect(url.searchParams.get('q')).toBe('Минск, проспект Победителей 1');
    expect(url.searchParams.get('language')).toBe('ru');
    expect(url.searchParams.get('limit')).toBe('5');
    expect(url.searchParams.get('access_token')).toBe('tok');
    expect(url.searchParams.has('proximity')).toBe(false);
    expect(url.searchParams.has('country')).toBe(false);
  });

  it('proximity — «lng,lat»', async () => {
    const { fetchImpl, urls } = recordingFetch();
    await createMapboxClient(fetchImpl).forward({ q: 'a', token: 'tok', proximity: { lat: 57.626, lng: 39.884 } });
    expect(urls[0].searchParams.get('proximity')).toBe('39.884,57.626');
    expect(urls[0].searchParams.has('country')).toBe(false);
  });

  it('ответ не 2xx → ошибка без токена в тексте', async () => {
    const { fetchImpl } = recordingFetch(401);
    const failure = createMapboxClient(fetchImpl).forward({ q: 'a', token: 'secret-token' });
    await expect(failure).rejects.toThrow(/401/);
    await expect(failure).rejects.not.toThrow(/secret-token/);
  });
});
