import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/audio/stt_service.dart';
import '../../core/database/app_database.dart';
import '../../core/network/api_client.dart';
import '../../core/network/on_device_llm_service.dart';
import '../../features/settings/llm_settings_provider.dart';
import '../../core/sync/sync_service.dart';

part 'report_create_notifier.g.dart';

const List<String> _defaultTemplates = [
  '인부출역현황',
  '재고현황',
  '작업진행현황',
  '장비가동율현황',
];

class ReportCreateState {
  final String voiceRawText;
  final Map<String, String> classifiedItems;
  final bool isRecording;
  final bool isClassifying;
  final bool isSaving;
  final String? error;

  const ReportCreateState({
    this.voiceRawText = '',
    this.classifiedItems = const {},
    this.isRecording = false,
    this.isClassifying = false,
    this.isSaving = false,
    this.error,
  });

  ReportCreateState copyWith({
    String? voiceRawText,
    Map<String, String>? classifiedItems,
    bool? isRecording,
    bool? isClassifying,
    bool? isSaving,
    String? error,
  }) =>
      ReportCreateState(
        voiceRawText: voiceRawText ?? this.voiceRawText,
        classifiedItems: classifiedItems ?? this.classifiedItems,
        isRecording: isRecording ?? this.isRecording,
        isClassifying: isClassifying ?? this.isClassifying,
        isSaving: isSaving ?? this.isSaving,
        error: error,
      );
}

@riverpod
class ReportCreateNotifier extends _$ReportCreateNotifier {
  @override
  ReportCreateState build() => const ReportCreateState();

  // 1단계: 음성 녹음 시작
  Future<void> startRecording() async {
    final stt = ref.read(sttServiceProvider);
    final ok = await stt.initialize();
    if (!ok) {
      state = state.copyWith(error: 'STT를 초기화할 수 없습니다.');
      return;
    }
    state = state.copyWith(isRecording: true, error: null);
    await stt.startListening(onResult: _onSttResult);
  }

  Future<void> stopRecording() async {
    await ref.read(sttServiceProvider).stopListening();
    state = state.copyWith(isRecording: false);
  }

  // 2단계: STT 결과 → Gemma 분류
  void _onSttResult(String rawText) {
    state = state.copyWith(
      voiceRawText: rawText,
      isRecording: false,
      isClassifying: true,
    );
    _classifyWithGemma(rawText);
  }

  Future<void> _classifyWithGemma(String rawText) async {
    try {
      final onDeviceService = ref.read(onDeviceLlmServiceProvider);
      final isDownloaded = await onDeviceService.isModelDownloaded();

      if (!isDownloaded) {
        state = state.copyWith(
          classifiedItems: {
            for (final t in _defaultTemplates) t: '',
            'unmatched': rawText,
          },
          isClassifying: false,
          error: '온디바이스 AI 모델이 설치되지 않았습니다. AI 설정 화면에서 먼저 다운로드해 주세요.',
        );
        return;
      }

      final settings = ref.read(llmSettingsProvider);
      final systemPrompt = settings.systemPrompt.isNotEmpty
          ? '${settings.systemPrompt}\n\n'
          : '';

      final prompt = '''
${systemPrompt}활성 템플릿: ${jsonEncode(_defaultTemplates)}
음성 원문: "$rawText"

각 템플릿 항목에 해당하는 내용을 분류하고,
자연스러운 보고 문장으로 정제하여 JSON으로만 반환하세요.
해당 내용이 없는 항목은 빈 문자열로, 어느 항목에도 해당되지 않는 내용은 "unmatched" 키에 넣으세요.
예시: {"인부출역현황": "오늘 12명 출역", "재고현황": "", ..., "unmatched": ""}
''';

      // 온디바이스 모델을 이용한 로컬 추론 실행
      final response = await onDeviceService.generate(prompt);

      // JSON 파싱 (Gemma가 ```json ... ``` 래핑 포함할 수 있음)
      final jsonStr = _extractJson(response);
      final classified = jsonDecode(jsonStr) as Map<String, dynamic>;
      state = state.copyWith(
        classifiedItems:
            classified.map((k, v) => MapEntry(k, v.toString())),
        isClassifying: false,
        error: null,
      );
    } catch (e) {
      // Gemma 오류 시 수동 입력으로 폴백
      state = state.copyWith(
        classifiedItems: {
          for (final t in _defaultTemplates) t: '',
          'unmatched': rawText,
        },
        isClassifying: false,
        error: '온디바이스 AI 분류 실패 ($e) — 직접 입력해 주세요.',
      );
    }
  }

  String _extractJson(String text) {
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    return match?.group(0) ?? '{}';
  }

  // 3단계: 사용자 수정
  void updateItem(String key, String value) {
    final updated = Map<String, String>.from(state.classifiedItems);
    updated[key] = value;
    state = state.copyWith(classifiedItems: updated);
  }

  // 로컬 SQLite 저장
  Future<void> saveLocally() async {
    state = state.copyWith(isSaving: true);
    try {
      final db = ref.read(dbProvider);
      await db.upsertReport(LocalReportsCompanion.insert(
        reportDate: DateTime.now(),
        voiceRawText: Value(state.voiceRawText),
        processedText: Value(state.classifiedItems.entries
            .where((e) => e.key != 'unmatched' && e.value.isNotEmpty)
            .map((e) => '${e.key}: ${e.value}')
            .join('\n')),
        itemsJson: Value(jsonEncode(state.classifiedItems)),
        status: const Value('draft'),
      ));
      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: '저장 실패: $e');
    }
  }

  // 서버 전송
  Future<bool> submit(int authorId, int teamId) async {
    state = state.copyWith(isSaving: true);
    try {
      final payload = {
        'author_id': authorId,
        'report_date': DateTime.now().toIso8601String().substring(0, 10),
        'voice_raw_text': state.voiceRawText,
        'processed_text': state.classifiedItems.entries
            .where((e) => e.key != 'unmatched' && e.value.isNotEmpty)
            .map((e) => '${e.key}: ${e.value}')
            .join('\n'),
        'items': state.classifiedItems,
        'team_id': teamId,
        'submitted_at': DateTime.now().toIso8601String(),
      };

      await ref.read(apiClientProvider).submitReport(payload);
      state = state.copyWith(isSaving: false);
      return true;
    } catch (_) {
      // 오프라인 → 동기화 큐에 추가
      final payload = {
        'author_id': authorId,
        'report_date': DateTime.now().toIso8601String().substring(0, 10),
        'voice_raw_text': state.voiceRawText,
        'items': state.classifiedItems,
        'team_id': teamId,
        'submitted_at': DateTime.now().toIso8601String(),
      };
      await ref.read(syncServiceProvider).enqueue(
            '/webhook/reports/submit',
            payload,
          );
      state = state.copyWith(isSaving: false);
      return false; // 오프라인 대기 중
    }
  }
}
