import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart'; // secureStorageProvider가 정의된 곳

class LlmSettings {
  final String modelUrl;
  final String localPath;
  final double temperature;
  final int maxTokens;
  final int randomSeed;
  final int topK;
  final String systemPrompt;

  const LlmSettings({
    required this.modelUrl,
    required this.localPath,
    required this.temperature,
    required this.maxTokens,
    required this.randomSeed,
    required this.topK,
    required this.systemPrompt,
  });

  LlmSettings copyWith({
    String? modelUrl,
    String? localPath,
    double? temperature,
    int? maxTokens,
    int? randomSeed,
    int? topK,
    String? systemPrompt,
  }) {
    return LlmSettings(
      modelUrl: modelUrl ?? this.modelUrl,
      localPath: localPath ?? this.localPath,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      randomSeed: randomSeed ?? this.randomSeed,
      topK: topK ?? this.topK,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }

  Map<String, dynamic> toJson() => {
        'modelUrl': modelUrl,
        'localPath': localPath,
        'temperature': temperature,
        'maxTokens': maxTokens,
        'randomSeed': randomSeed,
        'topK': topK,
        'systemPrompt': systemPrompt,
      };

  factory LlmSettings.fromJson(Map<String, dynamic> json) => LlmSettings(
        modelUrl: json['modelUrl'] as String? ??
            'https://huggingface.co/google/gemma-3-1b-it-litertlm/resolve/main/gemma-3-1b-it-gpu.litertlm',
        localPath: json['localPath'] as String? ?? '',
        temperature: (json['temperature'] as num?)?.toDouble() ?? 1.0,
        maxTokens: json['maxTokens'] as int? ?? 1024,
        randomSeed: json['randomSeed'] as int? ?? 1,
        topK: json['topK'] as int? ?? 1,
        systemPrompt: json['systemPrompt'] as String? ?? '',
      );
}

class LlmSettingsNotifier extends StateNotifier<LlmSettings> {
  final Ref _ref;
  static const _storageKey = 'llm_on_device_settings';

  LlmSettingsNotifier(this._ref)
      : super(const LlmSettings(
          modelUrl:
              'https://huggingface.co/google/gemma-3-1b-it-litertlm/resolve/main/gemma-3-1b-it-gpu.litertlm',
          localPath: '',
          temperature: 1.0,
          maxTokens: 1024,
          randomSeed: 1,
          topK: 1,
          systemPrompt: '',
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final storage = _ref.read(secureStorageProvider);
      final jsonStr = await storage.read(key: _storageKey);
      if (jsonStr != null) {
        state = LlmSettings.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      }
    } catch (_) {
      // 로드 실패 시 기본값 사용
    }
  }

  Future<void> updateSettings(LlmSettings newSettings) async {
    state = newSettings;
    try {
      final storage = _ref.read(secureStorageProvider);
      await storage.write(
        key: _storageKey,
        value: jsonEncode(newSettings.toJson()),
      );
    } catch (_) {}
  }

  Future<void> setLocalPath(String path) async {
    await updateSettings(state.copyWith(localPath: path));
  }

  Future<void> clearLocalPath() async {
    await updateSettings(state.copyWith(localPath: ''));
  }
}

final llmSettingsProvider =
    StateNotifierProvider<LlmSettingsNotifier, LlmSettings>((ref) {
  return LlmSettingsNotifier(ref);
});
