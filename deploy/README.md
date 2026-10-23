# deploy — стенд «Путь»

Стенд: `https://theway.dabooke.com` — VPS с Linux, nginx и Docker. API работает под `pm2` из клона
репозитория (`git pull`), в Docker — только PostgreSQL; демо-данные пополняются ночью по cron.
На VPS живут и другие приложения: их nginx-файлы, контейнеры и порты этот стенд не трогает, nginx —
только `nginx -t` и `reload`.

## Раскладка `/srv/theway/`

| Путь | Что |
| --- | --- |
| `app/` | клон репозитория (ветка `main`); доступ на чтение — SSH-ключом развёртывания через `core.sshCommand` клона |
| `app.env` | переменные API, права 600, вне клона |
| `deploy/` | файлы этого каталога (`scp` — клон берёт запушенный `main`) |
| `logs/` | `api.out.log`, `api.err.log`, `demo-cron.log` |
| `node/` | Node 24 (системный на VPS — 22, а `engines` проекта — `>=24`) и `pm2` — оба внутри этого префикса |
| `acme/` | корень ACME-проверки для certbot |
| ключ развёртывания, `known_hosts` | read-only SSH-ключ репозитория (приватный, только на VPS) и отпечаток github.com |

## Занятые номера

| Что | Значение |
| --- | --- |
| PostgreSQL | контейнер `theway-db` (`postgres:18.6`, том `theway-pgdata`, `--memory 256m`), `127.0.0.1:5440` |
| API | `127.0.0.1:3100` |
| Процесс pm2 | `theway-api` |

## Переменные `/srv/theway/app.env`

Только имена (значения не в git): `DATABASE_URL`, `PORT`, `APP_TZ` (`Europe/Moscow`), `PUBLIC_ORIGIN`
(`https://theway.dabooke.com`), `MAPBOX_TOKEN`. Любая ручная команда API на VPS начинается с
`set -a; . /srv/theway/app.env; set +a` и `export PATH=/srv/theway/node/bin:$PATH`.

## Первичная установка

Выполняется один раз; шаги, меняющие систему VPS, — от root.

1. Node 24 и pm2 внутри `/srv/theway/node` (системный Node не трогаем):
   ```sh
   cd /srv/theway
   curl -fsSLO https://nodejs.org/dist/v24.22.1/node-v24.22.1-linux-x64.tar.xz
   echo "6c172a9ab6718f7b801fb5a7bd486af2ee5e32758086a04b84fcce2aa77095e6  node-v24.22.1-linux-x64.tar.xz" | sha256sum -c -
   mkdir -p node && tar -xJf node-v24.22.1-linux-x64.tar.xz -C node --strip-components=1 && rm node-v24.22.1-linux-x64.tar.xz
   export PATH=/srv/theway/node/bin:$PATH
   npm i -g pm2 && pm2 -v
   ```
2. Ротация логов pm2:
   ```sh
   pm2 install pm2-logrotate && pm2 set pm2-logrotate:max_size 10M && pm2 set pm2-logrotate:retain 10
   ```
3. Ключ развёртывания: `ssh-keygen -t ed25519 -N "" -C theway-stand -f /srv/theway/<ключ>`, публичную
   часть (`<ключ>.pub`) добавить в GitHub: репозиторий → Settings → Deploy keys, только чтение. Затем:
   ```sh
   export SSHC="ssh -i /srv/theway/<ключ> -o UserKnownHostsFile=/srv/theway/known_hosts -o IdentitiesOnly=yes"
   ssh-keyscan -t ed25519 github.com > /srv/theway/known_hosts
   GIT_SSH_COMMAND="$SSHC" git clone <адрес репозитория> /srv/theway/app
   git -C /srv/theway/app config core.sshCommand "$SSHC"
   ```
   Клону нужен запушенный `main`.
4. Сборка и база (с `set -a; . /srv/theway/app.env; set +a` и `PATH` из п. 1):
   `cd /srv/theway/app && npm ci && npm run build --workspace=api`, затем
   `cd apps/api && npm run db:migrate && npm run db:seed` — seed один раз.
5. Запуск: `pm2 start /srv/theway/deploy/ecosystem.config.cjs && pm2 save`.
   Автозапуск: `pm2 startup systemd -u root --hp /root` (служба `pm2-root`), список процессов — `pm2 save`; после добавления или снятия процесса — снова `pm2 save`. Контейнер PostgreSQL поднимается сам (`--restart unless-stopped`).
6. nginx + сертификат (`nginx -t` перед каждым `reload`):
   ```sh
   cp /srv/theway/deploy/nginx-the-way-acme.conf /etc/nginx/sites-available/theway.conf
   ln -s /etc/nginx/sites-available/theway.conf /etc/nginx/sites-enabled/theway.conf
   nginx -t && systemctl reload nginx
   certbot certonly --webroot -w /srv/theway/acme -d theway.dabooke.com
   cp /srv/theway/deploy/nginx-the-way.conf /etc/nginx/sites-available/theway.conf
   nginx -t && systemctl reload nginx
   ```
   Продление сертификата — штатный таймер certbot.
7. Ночные демо-данные, после того как API отвечает: `crontab /srv/theway/deploy/demo-cron`.
   00:00 UTC = 03:00 МСК.

## Обновление

`sh /srv/theway/deploy/update.sh` — `git pull --ff-only → npm ci → build → db:migrate → pm2 restart`,
без полного seed.

## Проверка

- `curl -s https://theway.dabooke.com/health` → `{"ok":true}`
- `curl -s -X POST https://theway.dabooke.com/auth/verify -H 'content-type: application/json' -d '{"phone":"+79000000011","code":"111111"}'` → JSON с `token`
- cron в окружении как у демона: `env -i HOME="$HOME" PATH=/usr/bin:/bin sh -c '<строка demo-cron без расписания>'` → код 0, лог `/srv/theway/logs/demo-cron.log` без ошибки
