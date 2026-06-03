import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/settings/llm_settings_provider.dart';

final llmDownloadProgressProvider = StateProvider<double?>((ref) => null);

class OnDeviceLlmService {
  final Ref _ref;

  OnDeviceLlmService(this._ref);

  // 로컬 모델 파일 존재 여부 확인
  Future<bool> isModelDownloaded() async {
    final settings = _ref.read(llmSettingsProvider);
    if (settings.localPath.isEmpty) return false;
    final file = File(settings.localPath);
    return await file.exists();
  }

  // 로컬 모델 초기화
  Future<bool> initModel() async {
    final settings = _ref.read(llmSettingsProvider);
    if (settings.localPath.isEmpty) return false;
    final file = File(settings.localPath);
    if (!await file.exists()) {
      await _ref.read(llmSettingsProvider.notifier).clearLocalPath();
      return false;
    }

    try {
      // 0.2.4 버전의 FlutterGemmaPlugin.instance.init() 호출
      await FlutterGemmaPlugin.instance.init(
        modelPath: settings.localPath,
        maxTokens: settings.maxTokens,
        temperature: settings.temperature,
        randomSeed: settings.randomSeed,
        topK: settings.topK,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // 모델 다운로드
  Future<void> downloadModel(String url, String fileName) async {
    try {
      _ref.read(llmDownloadProgressProvider.notifier).state = 0.0;
      final appDir = await getApplicationDocumentsDirectory();
      
      final dir = Directory('${appDir.path}/models');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      final localPath = '${dir.path}/$fileName';
      
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 30), // 대용량 다운로드 고려
      ));

      await dio.download(
        url,
        localPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            _ref.read(llmDownloadProgressProvider.notifier).state = progress;
          }
        },
      );
      
      // 다운로드 완료 시 경로 저장
      await _ref.read(llmSettingsProvider.notifier).setLocalPath(localPath);
      _ref.read(llmDownloadProgressProvider.notifier).state = null;
      
      // 즉시 로딩
      await initModel();
    } catch (e) {
      _ref.read(llmDownloadProgressProvider.notifier).state = null;
      rethrow;
    }
  }

  // 다운로드된 모델 파일 삭제
  Future<void> deleteModel() async {
    final settings = _ref.read(llmSettingsProvider);
    if (settings.localPath.isNotEmpty) {
      final file = File(settings.localPath);
      if (await file.exists()) {
        await file.delete();
      }
      await _ref.read(llmSettingsProvider.notifier).clearLocalPath();
    }
  }

  // 로컬 추론 실행
  Future<String> generate(String prompt) async {
    final hasModel = await isModelDownloaded();
    if (!hasModel) {
      throw Exception('온디바이스 AI 모델이 다운로드되지 않았습니다. 설정 화면에서 먼저 다운로드해 주세요.');
    }

    final isInit = await FlutterGemmaPlugin.instance.isInitialized;
    if (!isInit) {
      final ok = await initModel();
      if (!ok) {
        throw Exception('온디바이스 AI 모델을 초기화할 수 없습니다.');
      }
    }

    final response = await FlutterGemmaPlugin.instance.getResponse(prompt: prompt);
    if (response == null) {
      throw Exception('온디바이스 AI 모델로부터 응답이 없습니다.');
    }
    return response;
  }
}

final onDeviceLlmServiceProvider = Provider<OnDeviceLlmService>((ref) {
  return OnDeviceLlmService(ref);
});
