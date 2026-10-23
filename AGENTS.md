# Путь (The Way) — вводная для ИИ-агента

Монорепозиторий: мобильное приложение на Flutter (`apps/mobile`, Android и iOS) и REST API на NestJS
(`apps/api`) с PostgreSQL. Приложение говорит с сервером только по HTTP через клиент,
порождённый из OpenAPI-контракта. Что строится и зачем — [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md);
как устроено — [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) и
[`docs/SPECIFICATION.md`](docs/SPECIFICATION.md); как запустить — [`README.md`](README.md).

## Стек

Flutter 3.47 (Dart 3.13; Android, iOS) · TypeScript, Node.js 24 · NestJS 12 · Drizzle ORM ·
PostgreSQL 18 (Docker Compose) · Jest · `swagger_parser` (кодоген Dart-клиента).

## Где что

| Путь | Назначение |
| --- | --- |
| `apps/api/src/main.ts` | точка входа сервера; миграции применяются при старте |
| `apps/api/src/configure-app.ts` | общая настройка приложения (проверка тел, фильтр ошибок, Swagger) — одна для сервера, эмиттера контракта и тестов |
| `apps/api/src/modules/<модуль>/` | модули предметной области: `auth`, `users`, `cities`, `cars`, `files`, `geo`, `trips`, `bookings`, `orders`, `reviews`, `logs`; наружу — `*.module.ts`, всё прочее — в `internal/` |
| `apps/api/src/common/` | общее для модулей: охрана (токен, блокировка), коды ошибок, счёт отмен и блокировка, формы чтения (`views.ts`), логгер |
| `apps/api/drizzle/` | SQL-миграции (`npm run db:generate --workspace=api` после правки `schema.ts`) |
| `apps/api/seed/` | демо-данные: `index.ts` — полная заливка, `demo.ts` — ночное пополнение поездок |
| `apps/api/test/` | интеграционные проверки правил (`rules/`) и сквозные сценарии (`e2e/`) через HTTP |
| `apps/mobile/lib/main.dart` | точка входа приложения |
| `apps/mobile/lib/src/app/` | оболочка: сессия, HTTP-клиент и перехватчики, маршруты, нижняя панель, проверка событий при открытии |
| `apps/mobile/lib/src/features/<раздел>/` | экраны по разделам макета; `data/` — репозиторий раздела над клиентом API |
| `apps/mobile/lib/src/widgets/` | общие виджеты по компонентам макета (перечень — `components.md` там же) |
| `apps/mobile/lib/src/theme/` | цвета, типографика, размеры — порождены из токенов дизайна |
| `apps/mobile/lib/l10n/app_ru.arb` | все строки интерфейса (только русский) |
| `contracts/openapi.json` | контракт API |
| `packages/api-client-dart/` | Dart-клиент API |

## Бизнес-правила — только на сервере

Лимиты публикаций, ранжирование и дубли поездок, цены отрезков, статусы броней, места, счёт
отмен и блокировки считает сервер. Клиент показывает ответ и выбирает экран по полям ответа и
коду ошибки, сам ничего не считает. Новое правило — в сервис модуля API и его тест, не в виджет.

Статус брони меняется только через машину статусов
(`apps/api/src/modules/bookings/internal/status-machine.ts`); отмены и блокировка — только через
`apps/api/src/common/cancellations.ts`.

## Контракт → клиент

Контракт порождается кодом сервера (декораторы `@nestjs/swagger` в DTO и контроллерах), клиент —
контрактом. Правка формы запроса или ответа — всегда в одном изменении:

```sh
npm run openapi:emit     # contracts/openapi.json из кода API (база не нужна)
npm run codegen:dart     # packages/api-client-dart/lib/src/generated/ (нужен Dart SDK)
```

## Команды

| Что | Команда |
| --- | --- |
| PostgreSQL для разработки | `docker compose up -d` (порт `5433`) |
| Зависимости | `npm ci` · `cd apps/mobile; flutter pub get` |
| Миграции · демо-данные | `npm run db:migrate` · `npm run db:seed` |
| API в режиме разработки | `npm run dev` (порт из `PORT`, по умолчанию `3000`) |
| Сборка API | `npm run build` |
| Тесты API | `npm test` (нужен `DATABASE_URL` на отдельную базу, например `dev_1`) |
| Один набор API | `npm test --workspace=api -- <часть имени файла>` |
| Анализ и тесты приложения | `cd apps/mobile; flutter analyze; flutter test` |
| APK | `cd apps/mobile; flutter build apk --release` |

Переменные окружения сервера — имена в `.env.example`; сервер читает окружение процесса,
файлов `.env` не загружает.

## Конвенции кода

**TypeScript (`apps/api`):** `strict`, без `any` (`unknown` + сужение); именованные экспорты;
`async/await`; ошибки предметной области — `throw new AppError('<код>', '<сообщение>')` с кодом из
`ERROR_CODES` (`common/errors.ts`), HTTP-статус берётся из таблицы там же; проверка тел — на
границе (DTO с `class-validator`, лишние поля — отказ); модуль не вызывает сервисы другого
модуля — из чужого `internal/` берётся только `schema.ts`, общее чтение лежит в
`common/views.ts`; печать — только логгер проекта
(`common/logger`), не `console.log`; новый `NOT NULL`-столбец — с `DEFAULT` в той же миграции.

**Dart (`apps/mobile`):** `flutter_lints`; строки — только из ARB (`AppLocalizations`), без
литералов в `Text()`; цвета, шрифты и отступы — только из `AppColors`, `AppType`, `AppSize`, без
hex-литералов и `Colors.*` в экранах; иконки и картинки — экспортом из макета (`assets/`), не
`Icons.*`; состояние экрана — `ChangeNotifier`/`FutureBuilder`, сторонних менеджеров состояния нет;
запросы — только через `TheWayApi` поверх общего `Dio` из `lib/src/app/http.dart`.

**Тесты:** правило сервера — интеграционная проверка в `apps/api/test/rules/` или модульный
`*.spec.ts` рядом с сервисом; экран — widget-тест в `apps/mobile/test/features/<раздел>/` на
поддельном сервере (`test/support/fake_api.dart`: `Dio`-адаптер с заготовленными ответами).

## Что не трогать руками

- `contracts/openapi.json` и `packages/api-client-dart/lib/src/generated/**` — порождаются (см. выше).
- `apps/mobile/lib/src/theme/app_colors.dart`, `app_type.dart`, `app_size.dart` — порождены из токенов
  `design/tokens/` и спецификаций компонентов макета (`tool/build_tokens.dart`); спецификаций в
  репозитории нет, поэтому новое значение темы — правка этих файлов вместе с токеном в `design/tokens/`.
- `apps/mobile/lib/l10n/app_localizations*.dart` — порождаются Flutter из `app_ru.arb` при сборке.
- Применённые миграции в `apps/api/drizzle/` — новая правка схемы идёт новой миграцией.
- `apps/api/seed/data/city.csv`, `apps/mobile/assets/data/car_catalog.json` — открытые наборы
  данных закреплённых версий; источник и условия — `README.md` рядом с каждым.

Секреты (ключ Mapbox, строка подключения стенда) в репозиторий не попадают; в git — только
`.env.example` с именами.
