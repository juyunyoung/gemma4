import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 패널')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminSection(
            title: '사용자 관리',
            icon: Icons.people,
            items: const ['사용자 역할 변경', '팀 구성원 관리', '계정 비활성화'],
          ),
          const SizedBox(height: 16),
          _AdminSection(
            title: '템플릿 관리',
            icon: Icons.list_alt,
            items: const ['템플릿 추가/수정', '팀별 템플릿 설정', '템플릿 비활성화'],
          ),
          const SizedBox(height: 16),
          _AdminSection(
            title: '시스템',
            icon: Icons.settings,
            items: const ['감사 로그 조회', '동기화 상태 확인', 'n8n 워크플로우 상태'],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('로그아웃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AdminSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _AdminSection(
      {required this.title, required this.icon, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.map((item) => ListTile(
                title: Text(item),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$item — 준비 중'))),
              )),
        ],
      ),
    );
  }
}
