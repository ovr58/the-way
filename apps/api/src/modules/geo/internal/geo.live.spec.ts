/**
 * Живая проверка геокодинга: настоящий Mapbox, три запроса. Без `MAPBOX_CONTRACT_LIVE=1` или
 * `MAPBOX_TOKEN` блок пропускается. Ловит «провайдер уехал в другой город» — моками не ловится.
 */
import { type Database } from '../../../db/client';
import { haversineKm } from '../../../common/places';
import { GeoService } from './geo.service';
import { createMapboxClient } from './mapbox.client';

const live = process.env.MAPBOX_CONTRACT_LIVE === '1' && Boolean(process.env.MAPBOX_TOKEN);

(live ? describe : describe.skip)('Mapbox, живой контракт', () => {
  // Запросы без cityId базу не трогают.
  const service = new GeoService({} as Database, createMapboxClient());

  it('«Ярославль, улица Свободы 1» → Ярославль, точка в 30 км от центра', async () => {
    const [first] = await service.suggest({ q: 'Ярославль, улица Свободы 1' });
    expect(first.place.name).toBe('Ярославль');
    expect(haversineKm({ lat: first.lat, lng: first.lng }, { lat: 57.626, lng: 39.884 })).toBeLessThan(30);
  });

  it('«Минск, проспект Победителей 1» → Минск, точка в 30 км от центра', async () => {
    const [first] = await service.suggest({ q: 'Минск, проспект Победителей 1' });
    expect(first.place.name).toBe('Минск');
    expect(haversineKm({ lat: first.lat, lng: first.lng }, { lat: 53.902, lng: 27.561 })).toBeLessThan(30);
  });

  it('«село Великое Ярославская область» → Великое, точка в 100 км от Ярославля', async () => {
    const [first] = await service.suggest({ q: 'село Великое Ярославская область' });
    expect(first.place.name).toBe('Великое');
    expect(haversineKm({ lat: first.lat, lng: first.lng }, { lat: 57.626, lng: 39.884 })).toBeLessThan(100);
  });
});
