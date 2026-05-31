import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment, size: 80, color: Color(0xFF1565C0)),
            const SizedBox(height: 24),
            Text('업무 보고서',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 8),
            Text('온디바이스 AI 보고서 자동화',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    )),
            const SizedBox(height: 48),
            if (authState.isLoading)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: () => ref.read(authProvider.notifier).login(),
                icon: const Icon(Icons.login),
                label: const Text('로그인'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 52),
                ),
              ),
            if (authState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  '로그인 실패: ${authState.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
