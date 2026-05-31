import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'interceptors/auth_interceptor.dart';

// 빌드 시 주입: flutter run --dart-define=N8N_BASE_URL=http://192.168.1.10:5678
const String kBaseUrl = String.fromEnvironment(
  'N8N_BASE_URL',
  defaultValue: 'http://localhost:5678',
);
const String kOllamaUrl = String.fromEnvironment(
  'OLLAMA_URL',
  defaultValue: 'http://localhost:11434',
);

class ApiClient {
  late final Dio _dio;
  late final Dio _ollamaDio;

  ApiClient(FlutterSecureStorage storage) {
    _dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(AuthInterceptor(storage));

    _ollamaDio = Dio(BaseOptions(
      baseUrl: kOllamaUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 60), // LLM 추론 시간 고려
    ));
  }

  Future<Response> submitReport(Map<String, dynamic> payload) =>
      _dio.post('/webhook/reports/submit', data: payload);

  Future<Response> getDailyReport(String date) =>
      _dio.get('/webhook/reports/daily', queryParameters: {'date': date});

  Future<Response> searchReports(String query, {String? dateFrom}) =>
      _dio.get('/webhook/reports/search', queryParameters: {
        'q': query,
        if (dateFrom != null) 'date_from': dateFrom,
      });

  Future<Response> approveReport(int reportId, String action, String comment) =>
      _dio.post('/webhook/reports/approve', data: {
        'report_id': reportId,
        'action': action,
        'comment': comment,
      });

  // Ollama (Gemma E4B) 호출
  Future<String> generateWithGemma(String prompt) async {
    final res = await _ollamaDio.post('/api/generate', data: {
      'model': 'gemma3:4b',
      'prompt': prompt,
      'stream': false,
    });
    return res.data['response'] as String;
  }
}

final secureStorageProvider =
    Provider<FlutterSecureStorage>((_) => const FlutterSecureStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage);
});
