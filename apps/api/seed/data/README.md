# Данные seed

## `city.csv` — города России

- **Источник:** [hflabs/city](https://github.com/hflabs/city), коммит
  `ae661bffe572880472249097c9b29c42b09650ea`, файл `city.csv` (1117 городов с координатами центра).
- **Авторство:** © HFLabs, проект «Города России» (hflabs/city).
- **Лицензия:** [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) — файл распространяется
  с указанием авторства и под той же лицензией; изменений в файле нет.
- **Как используется:** `seed/cities.ts`: `name` — первое непустое из `settlement`,
  `city`, `area`, `region`; `region` — `region_type` + `region`; координаты — `geo_lat`, `geo_lon`.
- **Обновить:** скачать файл той же или новой версии по адресу
  `https://raw.githubusercontent.com/hflabs/city/<коммит>/city.csv` и поправить коммит здесь.
