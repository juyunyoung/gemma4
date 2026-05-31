import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SttService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _stt.initialize(
      onStatus: (s) => debugPrint('[STT] 상태: $s'),
      onError: (e) => debugPrint('[STT] 오류: $e'),
    );
    return _initialized;
  }

  bool get isListening => _stt.isListening;
  bool get isAvailable => _initialized;

  Future<void> startListening({
    required void Function(String text) onResult,
    String localeId = 'ko_KR',
  }) async {
    if (!_initialized) await initialize();
    await _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      localeId: localeId,
      pauseFor: const Duration(seconds: 3),
      listenMode: ListenMode.dictation,
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }

  Future<void> cancelListening() async {
    await _stt.cancel();
  }
}

final sttServiceProvider = Provider<SttService>((_) => SttService());
