import 'package:dio/dio.dart';

/// Код ошибки сервера (`{code, message}`) из исключения запроса; `null` — ответа нет
/// (сеть, таймаут) или тело не того вида.
String? apiErrorCode(Object error) {
  if (error is! DioException) return null;
  final data = error.response?.data;
  if (data is Map && data['code'] is String) return data['code'] as String;
  return null;
}
