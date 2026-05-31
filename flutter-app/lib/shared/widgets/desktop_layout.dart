import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/report_view/report_view_screen.dart';
import '../../features/report_manage/report_manage_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/admin/admin_screen.dart';

class DesktopLayout extends ConsumerStatefulWidget {
  const DesktopLayout({super.key});

  @override
  ConsumerState<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends ConsumerState<DesktopLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final isApprover = user?.isTeamLeader ?? false;
    final isAdmin = user?.isAdmin ?? false;

    final destinations = [
      const NavigationRailDestination(
        icon: Icon(Icons.article_outlined),
        selectedIcon: Icon(Icons.article),
        label: Text('보고서 조회'),
      ),
      if (isApprover)
        const NavigationRailDestination(
          icon: Icon(Icons.approval_outlined),
          selectedIcon: Icon(Icons.approval),
          label: Text('결재'),
        ),
      const NavigationRailDestination(
        icon: Icon(Icons.search),
        selectedIcon: Icon(Icons.search),
        label: Text('검색'),
      ),
      if (isAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: Text('관리'),
        ),
    ];

    final screens = [
      const ReportViewScreen(),
      if (isApprover) const ReportManageScreen(),
      const SearchScreen(),
      if (isAdmin) const AdminScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex.clamp(0, destinations.length - 1),
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: destinations,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.assignment, size: 32, color: Color(0xFF1565C0)),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(user?.username ?? '',
                          style: const TextStyle(fontSize: 12)),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        tooltip: '로그아웃',
                        onPressed: () =>
                            ref.read(authProvider.notifier).logout(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: screens[_selectedIndex.clamp(0, screens.length - 1)],
          ),
        ],
      ),
    );
  }
}
