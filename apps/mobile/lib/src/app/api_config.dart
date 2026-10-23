/// Адрес API. Задаётся сборкой: `--dart-define=API_URL=https://…`; по умолчанию — стенд
/// проверяющего. Для эмулятора с локальным API —
/// `--dart-define=API_URL=http://10.0.2.2:3000`.
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://theway.dabooke.com');
