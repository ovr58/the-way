// pm2: API «Путь» на стенде. Переменные — один файл /srv/theway/app.env (права 600, вне клона).
// Запуск: pm2 start /srv/theway/deploy/ecosystem.config.cjs   (node — /srv/theway/node/bin в PATH)
module.exports = {
  apps: [
    {
      name: 'theway-api',
      cwd: '/srv/theway/app/apps/api',
      script: 'dist/main.js',
      node_args: '--env-file=/srv/theway/app.env',
      out_file: '/srv/theway/logs/api.out.log',
      error_file: '/srv/theway/logs/api.err.log',
      time: true,
      max_memory_restart: '400M',
    },
  ],
};
