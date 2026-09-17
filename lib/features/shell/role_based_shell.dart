import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../finance/finance_shell_page.dart';
import '../jobs/jobs_list_page.dart';
import '../jobs/my_jobs_page.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../staff/staff_list_page.dart';

/// Root shell after sign-in: role-based bottom navigation over an
/// [IndexedStack] (so switching tabs doesn't lose scroll/filter state).
/// Patron gets İşler/Tahsilatlar/Personeller/Bildirimler/Profil; personel
/// gets İşlerim/Tahsilatlar/Bildirimler/Profil.
class RoleBasedShell extends ConsumerStatefulWidget {
  const RoleBasedShell({super.key});

  @override
  ConsumerState<RoleBasedShell> createState() => _RoleBasedShellState();
}

class _RoleBasedShellState extends ConsumerState<RoleBasedShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final uid = ref.watch(authStateChangesProvider).valueOrNull?.uid;
    final isPatron = appUser?.isPatron ?? false;

    final unreadCount = uid == null
        ? 0
        : (ref.watch(notificationsProvider(uid)).valueOrNull ?? [])
              .where((n) => !n.read)
              .length;

    final pages = isPatron
        ? const [
            JobsListPage(),
            FinanceShellPage(),
            StaffListPage(),
            NotificationsPage(),
            ProfilePage(),
          ]
        : const [
            MyJobsPage(),
            FinanceShellPage(),
            NotificationsPage(),
            ProfilePage(),
          ];

    final destinations = isPatron
        ? [
            const NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work),
              label: 'İşler',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Finans',
            ),
            const NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Personeller',
            ),
            NavigationDestination(
              icon: _NotificationIcon(count: unreadCount, filled: false),
              selectedIcon: _NotificationIcon(count: unreadCount, filled: true),
              label: 'Bildirimler',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ]
        : [
            const NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'İşlerim',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Finans',
            ),
            NavigationDestination(
              icon: _NotificationIcon(count: unreadCount, filled: false),
              selectedIcon: _NotificationIcon(count: unreadCount, filled: true),
              label: 'Bildirimler',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ];

    final index = _index.clamp(0, pages.length - 1);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.count, required this.filled});

  final int count;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      filled ? Icons.notifications : Icons.notifications_outlined,
    );
    if (count == 0) return icon;
    return Badge(label: Text('$count'), child: icon);
  }
}
