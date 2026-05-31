import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'report_create_notifier.dart';

class ReportCreateScreen extends ConsumerWidget {
  const ReportCreateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportCreateNotifierProvider);
    final notifier = ref.read(reportCreateNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 보고서'),
        actions: [
          if (!state.isClassifying && state.classifiedItems.isNotEmpty)
            TextButton(
              onPressed: state.isSaving
                  ? null
                  : () async {
                      final sent = await notifier.submit(1, 2); // TODO: 실제 ID
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(sent ? '제출 완료!' : '오프라인 — 나중에 자동 전송됩니다'),
                        ));
                      }
                    },
              child: const Text('제출'),
            ),
        ],
      ),
      body: Column(
        children: [
          // 음성 입력 영역
          _VoiceInputCard(state: state, notifier: notifier),

          // STT 원문
          if (state.voiceRawText.isNotEmpty)
            _RawTextCard(text: state.voiceRawText),

          // Gemma 분류 결과
          if (state.isClassifying)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(width: 12),
                  Text('AI가 내용을 분류 중...'),
                ],
              ),
            )
          else if (state.classifiedItems.isNotEmpty)
            Expanded(
              child: _ClassifiedItemsList(
                items: state.classifiedItems,
                onUpdate: notifier.updateItem,
              ),
            ),

          // 오류 메시지
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(state.error!,
                  style: const TextStyle(color: Colors.orange)),
            ),
        ],
      ),
    );
  }
}

class _VoiceInputCard extends StatelessWidget {
  final ReportCreateState state;
  final ReportCreateNotifier notifier;

  const _VoiceInputCard({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('음성으로 보고 내용을 말씀하세요',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: state.isRecording
                  ? notifier.stopRecording
                  : notifier.startRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.isRecording
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                ),
                child: Icon(
                  state.isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(state.isRecording ? '녹음 중... (탭하여 중지)' : '탭하여 녹음 시작',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _RawTextCard extends StatelessWidget {
  final String text;
  const _RawTextCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('음성 원문', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(text),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassifiedItemsList extends StatelessWidget {
  final Map<String, String> items;
  final void Function(String key, String value) onUpdate;

  const _ClassifiedItemsList(
      {required this.items, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final key = items.keys.elementAt(index);
        final value = items[key] ?? '';
        return _ItemCard(
          templateName: key,
          content: value,
          onChanged: (v) => onUpdate(key, v),
        );
      },
    );
  }
}

class _ItemCard extends StatefulWidget {
  final String templateName;
  final String content;
  final ValueChanged<String> onChanged;

  const _ItemCard({
    required this.templateName,
    required this.content,
    required this.onChanged,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUnmatched = widget.templateName == 'unmatched';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isUnmatched ? Icons.help_outline : Icons.check_circle_outline,
                  size: 16,
                  color: isUnmatched ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  isUnmatched ? '미분류 항목' : widget.templateName,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: '내용을 입력하거나 수정하세요',
              ),
              onChanged: widget.onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
