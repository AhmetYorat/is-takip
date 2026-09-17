import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/auth_service.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/expenses/staff_expenses_page.dart';
import '../features/jobs/job_create_page.dart';
import '../features/jobs/job_detail_page.dart';
import '../features/jobs/job_edit_page.dart';
import '../features/receivables/receivable_detail_page.dart';
import '../features/shell/role_based_shell.dart';
import '../features/shell/splash_page.dart';
import 'constants.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authStateChangesProvider);
      final loggingIn =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;
      final onSplash = state.matchedLocation == AppRoutes.splash;

      if (authState.isLoading) {
        return onSplash ? null : AppRoutes.splash;
      }

      final user = authState.valueOrNull;
      if (user == null) {
        return loggingIn ? null : AppRoutes.login;
      }

      // Signed in: wait for the users/{uid} profile doc (role) before
      // entering the role-based shell.
      final appUserState = ref.read(currentAppUserProvider);
      if (appUserState.isLoading || appUserState.valueOrNull == null) {
        return onSplash ? null : AppRoutes.splash;
      }

      if (loggingIn || onSplash) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const RoleBasedShell(),
      ),
      GoRoute(
        path: AppRoutes.jobCreate,
        builder: (context, state) => const JobCreatePage(),
      ),
      GoRoute(
        path: AppRoutes.jobDetail,
        builder: (context, state) =>
            JobDetailPage(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.jobEdit,
        builder: (context, state) =>
            JobEditPage(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.receivableDetail,
        builder: (context, state) =>
            ReceivableDetailPage(receivableId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.staffExpenses,
        builder: (context, state) =>
            StaffExpensesPage(uid: state.pathParameters['uid']!),
      ),
    ],
  );
});

/// Bridges Riverpod's async auth/profile streams to go_router's
/// [Listenable]-based `refreshListenable`, so navigation redirects
/// re-evaluate whenever sign-in state or role changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateChangesProvider, (_, _) => notifyListeners());
    ref.listen(currentAppUserProvider, (_, _) => notifyListeners());
  }
}
