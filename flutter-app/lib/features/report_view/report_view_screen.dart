import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';

class ReportViewScreen extends ConsumerWidget {
  const ReportViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('보고서 목록')),
      body: FutureBuilder<List<LocalReport>>(
        future: db.getAllReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('작성된 보고서가 없습니다.'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _ReportCard(report: report);
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final LocalReport report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('yyyy년 MM월 dd일').format(report.reportDate);
    final statusColor = switch (report.status) {
      'submitted' => Colors.blue,
      'team_approved' => Colors.orange,
      'dept_approved' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.grey,
    };
    final statusLabel = switch (report.status) {
      'submitted' => '제출됨',
      'team_approved' => '팀장 승인',
      'dept_approved' => '최종 승인',
      'rejected' => '반려',
      _ => '초안',
    };

    Map<String, dynamic> items = {};
    if (report.itemsJson != null) {
      try {
        items = jsonDecode(report.itemsJson!) as Map<String, dynamic>;
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(dateStr,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Text(statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 12)),
            ),
            if (!report.isSynced) ...[
              const SizedBox(width: 8),
              const Icon(Icons.cloud_off, size: 14, color: Colors.orange),
              const Text(' 미동기화', style: TextStyle(fontSize: 12)),
            ]
          ],
        ),
        children: [
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.entries
                    .where((e) => e.value.toString().isNotEmpty)
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey)),
                              Text(e.value.toString()),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
