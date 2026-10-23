#!/bin/sh
# Обновление стенда: git pull -> npm ci -> build -> db:migrate -> pm2 restart (seed не гоняется).
# Запуск на VPS: sh /srv/theway/deploy/update.sh
set -e
set -a; . /srv/theway/app.env; set +a
export PATH=/srv/theway/node/bin:/usr/bin:/bin
cd /srv/theway/app
git pull --ff-only
npm ci
npm run build --workspace=api
(cd apps/api && npm run db:migrate)
pm2 restart theway-api --update-env
