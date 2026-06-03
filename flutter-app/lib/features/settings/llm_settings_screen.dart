import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/on_device_llm_service.dart';
import 'llm_settings_provider.dart';

class LlmSettingsScreen extends ConsumerStatefulWidget {
  const LlmSettingsScreen({super.key});

  @override
  ConsumerState<LlmSettingsScreen> createState() => _LlmSettingsScreenState();
}

class _LlmSettingsScreenState extends ConsumerState<LlmSettingsScreen> {
  final _customUrlController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _seedController = TextEditingController();

  String _selectedPreset = 'gemma_3_1b_gpu';
  bool _isCustomUrl = false;

  final Map<String, Map<String, String>> _presets = {
    'gemma_3_1b_gpu': {
      'name': 'Gemma 3 1B IT (GPU - 권장)',
      'url': 'https://huggingface.co/google/gemma-3-1b-it-litertlm/resolve/main/gemma-3-1b-it-gpu.litertlm',
      'file': 'gemma-3-1b-it-gpu.litertlm',
    },
    'gemma_3_1b_cpu': {
      'name': 'Gemma 3 1B IT (CPU)',
      'url': 'https://huggingface.co/google/gemma-3-1b-it-litertlm/resolve/main/gemma-3-1b-it-cpu.litertlm',
      'file': 'gemma-3-1b-it-cpu.litertlm',
    },
    'gemma_3_4b_gpu': {
      'name': 'Gemma 3 4B IT (GPU - 고성능)',
      'url': 'https://huggingface.co/google/gemma-3-4b-it-litertlm/resolve/main/gemma-3-4b-it-gpu.litertlm',
      'file': 'gemma-3-4b-it-gpu.litertlm',
    },
    'gemma_3_4b_cpu': {
      'name': 'Gemma 3 4B IT (CPU)',
      'url': 'https://huggingface.co/google/gemma-3-4b-it-litertlm/resolve/main/gemma-3-4b-it-cpu.litertlm',
      'file': 'gemma-3-4b-it-cpu.litertlm',
    },
  };

  double _temperature = 1.0;
  int _maxTokens = 1024;
  int _topK = 1;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settings = ref.read(llmSettingsProvider);
    _systemPromptController.text = settings.systemPrompt;
    _seedController.text = settings.randomSeed.toString();
    _temperature = settings.temperature;
    _maxTokens = settings.maxTokens;
    _topK = settings.topK;

    // 프리셋 매칭
    bool matched = false;
    for (final entry in _presets.entries) {
      if (entry.value['url'] == settings.modelUrl) {
        _selectedPreset = entry.key;
        matched = true;
        break;
      }
    }
    if (!matched && settings.modelUrl.isNotEmpty) {
      _selectedPreset = 'custom';
      _isCustomUrl = true;
      _customUrlController.text = settings.modelUrl;
    }
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    _systemPromptController.dispose();
    _seedController.dispose();
    super.dispose();
  }

  String _getFileSizeString(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        final mb = bytes / (1024 * 1024);
        return '${mb.toStringAsFixed(1)} MB';
      }
    } catch (_) {}
    return '알 수 없음';
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(llmSettingsProvider);
    final downloadProgress = ref.watch(llmDownloadProgressProvider);
    final service = ref.read(onDeviceLlmServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 설정'),
      ),
      body: FutureBuilder<bool>(
        future: service.isModelDownloaded(),
        builder: (context, snapshot) {
          final isDownloaded = snapshot.data ?? false;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. 모델 상태 카드
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('온디바이스 AI 상태', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDownloaded ? Colors.green.shade100 : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isDownloaded ? '설치 완료' : '미설치',
                              style: TextStyle(
                                color: isDownloaded ? Colors.green.shade800 : Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (isDownloaded) ...[
                        Text('경로: ${settings.localPath}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('크기: ${_getFileSizeString(settings.localPath)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: downloadProgress != null
                              ? null
                              : () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('모델 삭제'),
                                      content: const Text('기기에 저장된 AI 모델 파일을 삭제하시겠습니까? 다시 사용하려면 재다운로드가 필요합니다.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await service.deleteModel();
                                    setState(() {});
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모델 삭제 완료')));
                                    }
                                  }
                                },
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text('모델 삭제', style: TextStyle(color: Colors.red)),
                        ),
                      ] else ...[
                        const Text('기기 내에서 독립적으로 구동할 AI 모델이 아직 설치되지 않았습니다. 아래에서 원하는 모델을 다운로드해 주세요.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. 모델 다운로드 카드
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('모델 다운로드', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedPreset,
                        decoration: const InputDecoration(
                          labelText: 'AI 모델 선택',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          ..._presets.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value['name']!))),
                          const DropdownMenuItem(value: 'custom', child: Text('직접 URL 입력')),
                        ],
                        onChanged: downloadProgress != null
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedPreset = val;
                                    _isCustomUrl = val == 'custom';
                                  });
                                }
                              },
                      ),
                      if (_isCustomUrl) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customUrlController,
                          enabled: downloadProgress == null,
                          decoration: const InputDecoration(
                            labelText: '다운로드 URL',
                            hintText: 'https://huggingface.co/.../model.litertlm',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (downloadProgress != null) ...[
                        LinearProgressIndicator(value: downloadProgress),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('다운로드 중... ${(downloadProgress * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const Text('Wi-Fi 연결을 권장합니다', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              String url;
                              String fileName;
                              if (_isCustomUrl) {
                                url = _customUrlController.text.trim();
                                if (url.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('다운로드 URL을 입력해 주세요')));
                                  return;
                                }
                                fileName = url.split('/').last;
                                if (!fileName.contains('.')) {
                                  fileName = 'custom_model.litertlm';
                                }
                              } else {
                                final preset = _presets[_selectedPreset]!;
                                url = preset['url']!;
                                fileName = preset['file']!;
                              }

                              try {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('다운로드를 시작합니다 (대용량 파일이므로 수분이 소요될 수 있습니다)')));
                                await service.downloadModel(url, fileName);
                                setState(() {});
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모델 다운로드 및 초기화 성공!')));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('다운로드 실패: $e'), backgroundColor: Colors.red));
                                }
                              }
                            },
                            icon: const Icon(Icons.download),
                            label: Text(isDownloaded ? '새 모델로 재다운로드' : '다운로드 시작'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. 매개변수 및 시스템 프롬프트 설정 카드
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('매개변수 및 지침 설정', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Temperature (온도)'),
                          Text(_temperature.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: _temperature,
                        min: 0.1,
                        max: 2.0,
                        divisions: 19,
                        label: _temperature.toStringAsFixed(1),
                        onChanged: downloadProgress != null
                            ? null
                            : (val) => setState(() => _temperature = val),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Max Tokens (최대 토큰)'),
                          Text('$_maxTokens', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: _maxTokens.toDouble(),
                        min: 128,
                        max: 2048,
                        divisions: 15,
                        label: '$_maxTokens',
                        onChanged: downloadProgress != null
                            ? null
                            : (val) => setState(() => _maxTokens = val.toInt()),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Top K'),
                          Text('$_topK', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: _topK.toDouble(),
                        min: 1,
                        max: 100,
                        divisions: 99,
                        label: '$_topK',
                        onChanged: downloadProgress != null
                            ? null
                            : (val) => setState(() => _topK = val.toInt()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _seedController,
                        enabled: downloadProgress == null,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Random Seed (랜덤 시드)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _systemPromptController,
                        maxLines: 4,
                        enabled: downloadProgress == null,
                        decoration: const InputDecoration(
                          labelText: 'System Prompt (시스템 지침)',
                          hintText: '모델에게 부여할 기본 역할이나 지침을 입력하세요',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 4. 저장 버튼
              ElevatedButton(
                onPressed: downloadProgress != null
                    ? null
                    : () async {
                        final seed = int.tryParse(_seedController.text) ?? 1;
                        String url;
                        if (_isCustomUrl) {
                          url = _customUrlController.text.trim();
                        } else {
                          url = _presets[_selectedPreset]!['url']!;
                        }

                        final currentSettings = ref.read(llmSettingsProvider);
                        final newSettings = currentSettings.copyWith(
                          modelUrl: url,
                          temperature: _temperature,
                          maxTokens: _maxTokens,
                          randomSeed: seed,
                          topK: _topK,
                          systemPrompt: _systemPromptController.text.trim(),
                        );

                        await ref.read(llmSettingsProvider.notifier).updateSettings(newSettings);
                        
                        // 로컬 모델이 다운로드되어 있다면 초기화 갱신
                        if (currentSettings.localPath.isNotEmpty) {
                          await service.initModel();
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('설정이 정상 저장되었습니다!')));
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('설정 저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
