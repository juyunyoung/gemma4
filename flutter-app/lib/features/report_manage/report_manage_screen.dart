import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

class ReportManageScreen extends ConsumerStatefulWidget {
  const ReportManageScreen({super.key});

  @override
  ConsumerState<ReportManageScreen> createState() => _ReportManageScreenState();
}

class _ReportManageScreenState extends ConsumerState<ReportManageScreen> {
  List<dynamic> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final res = await ref.read(apiClientProvider).getDailyReport(today);
      setState(() {
        _reports = res.data['reports'] as List? ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleApproval(
      int reportId, String action, BuildContext ctx) async {
    final comment = await _showCommentDialog(ctx, action);
    if (comment == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .approveReport(reportId, action, comment);
      await _loadReports();
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('${action == 'approved' ? '승인' : '반려'} 완료')));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text('처리 실패: $e')));
      }
    }
  }

  Future<String?> _showCommentDialog(BuildContext ctx, String action) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'approved' ? '승인 의견' : '반려 사유'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '의견을 입력하세요 (선택)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('확인')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('결재 대기'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadReports),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? const Center(child: Text('결재 대기 중인 보고서가 없습니다.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index] as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${report['author_name'] ?? '작성자'} — ${report['report_date']}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(report['processed_text']?.toString() ??
                                '내용 없음'),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _handleApproval(
                                      report['id'] as int, 'rejected', context),
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  label: const Text('반려',
                                      style: TextStyle(color: Colors.red)),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: () => _handleApproval(
                                      report['id'] as int, 'approved', context),
                                  icon: const Icon(Icons.check),
                                  label: const Text('승인'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
