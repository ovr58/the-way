-- Базы dev_1…dev_6 для разработки и тестов: параллельные прогоны тестов берут каждый свою
-- (`DATABASE_URL=postgres://postgres:postgres@localhost:5433/dev_<N>`). Скрипт выполняется образом postgres один раз — при первом старте с пустым томом.
CREATE DATABASE dev_1;
CREATE DATABASE dev_2;
CREATE DATABASE dev_3;
CREATE DATABASE dev_4;
CREATE DATABASE dev_5;
CREATE DATABASE dev_6;
