/** Ключ поиска: кириллица и латиница сводятся к одной латинице. Те же случаи проверяет клиент. */
import cases from './search-key.cases.json';
import matches from './search-key.matches.json';
import { matchesSearch, searchKey, startsWithSearch } from './search-key';

describe('searchKey', () => {
  it.each(cases as [string, string][])('%s → %s', (input, key) => {
    expect(searchKey(input)).toBe(key);
  });

  it('латиница находит кириллическое название по вхождению', () => {
    expect(searchKey('Переславль-Залесский')).toContain(searchKey('Pereslavl'));
    expect(searchKey('Ярославль').startsWith(searchKey('yar'))).toBe(true);
  });
});

/** Привычные английские написания (проверяющий вне РФ): название кодируется несколькими вариантами. */
describe('matchesSearch', () => {
  it.each(matches as [string, string][])('%s находит «%s»', (query, name) => {
    expect(matchesSearch(query, name)).toBe(true);
  });

  it('чужое не находит', () => {
    expect(matchesSearch('Nizhny', 'Москва')).toBe(false);
  });

  it('начало названия — по любому варианту: «Yekat» — начало «Екатеринбурга»', () => {
    expect(startsWithSearch('Yekat', 'Екатеринбург')).toBe(true);
    expect(startsWithSearch('slavl', 'Ярославль')).toBe(false);
  });
});
