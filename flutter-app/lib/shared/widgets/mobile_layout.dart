import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/report_create/report_create_screen.dart';
import '../../features/report_view/report_view_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/llm_settings_screen.dart';

class MobileLayout extends ConsumerStatefulWidget {
  const MobileLayout({super.key});

  @override
  ConsumerState<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends ConsumerState<MobileLayout> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    ReportCreateScreen(),
    ReportViewScreen(),
    SearchScreen(),
    LlmSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: '보고서 작성',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: '보고서 보기',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: '검색',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'AI 설정',
          ),
        ],
      ),
    );
  }
}
