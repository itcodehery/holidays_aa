import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/leave/presentation/employee/apply_leave_screen.dart';
import '../../features/leave/presentation/employee/my_requests_screen.dart';
import '../../features/leave/presentation/employee/request_detail_screen.dart';
import '../../features/leave/presentation/manager/pending_requests_screen.dart';
import '../widgets/adaptive_scaffold.dart';

final _routerLog = Logger('Router');

/// Intentional two-option employee navigation: "Home" and "Add a Leave Request".
const _employeeDestinations = <AdaptiveDestination>[
  AdaptiveDestination(
    label: 'Home',
    icon: LucideIcons.house,
    selectedIcon: LucideIcons.house,
    route: '/employee/requests',
  ),
  AdaptiveDestination(
    label: 'Add a Leave Request',
    icon: LucideIcons.plus,
    selectedIcon: LucideIcons.plus,
    route: '/employee/apply',
  ),
];

/// Intentional two-option manager/HR navigation: "Home" and "History".
const _approverDestinations = <AdaptiveDestination>[
  AdaptiveDestination(
    label: 'Home',
    icon: LucideIcons.house,
    selectedIcon: LucideIcons.house,
    route: '/approver/pending',
  ),
  AdaptiveDestination(
    label: 'History',
    icon: LucideIcons.layers,
    selectedIcon: LucideIcons.layers,
    route: '/approver/history',
  ),
];

/// Provides the application's [GoRouter] with role-based redirect guards.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(authRouterNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final user = ref.read(currentUserProvider);
      final path = state.uri.path;
      final isLoginRoute = path == '/login';

      if (user == null) {
        return isLoginRoute ? null : '/login';
      }

      if (user.isEmployee) {
        if (isLoginRoute || path == '/' || path.startsWith('/approver')) {
          _routerLog.fine('Redirecting employee to /employee/requests');
          return '/employee/requests';
        }
        return null;
      }

      if (isLoginRoute || path == '/' || path.startsWith('/employee')) {
        _routerLog.fine('Redirecting ${user.role.name} to /approver/pending');
        return '/approver/pending';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/employee/requests',
        builder: (context, state) => AdaptiveScaffold(
          title: 'My Leave Requests',
          destinations: _employeeDestinations,
          selectedIndex: 0,
          onDestinationSelected: (idx) =>
              context.go(_employeeDestinations[idx].route),
          body: const MyRequestsScreen(),
        ),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => RequestDetailScreen(
              requestId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/employee/apply',
        builder: (context, state) => AdaptiveScaffold(
          title: 'Add a Leave Request',
          destinations: _employeeDestinations,
          selectedIndex: 1,
          onDestinationSelected: (idx) =>
              context.go(_employeeDestinations[idx].route),
          body: const ApplyLeaveScreen(),
        ),
      ),
      GoRoute(
        path: '/approver/pending',
        builder: (context, state) => AdaptiveScaffold(
          title: 'Pending Leave Approvals',
          destinations: _approverDestinations,
          selectedIndex: 0,
          onDestinationSelected: (idx) =>
              context.go(_approverDestinations[idx].route),
          body: const PendingRequestsScreen(isHistory: false),
        ),
      ),
      GoRoute(
        path: '/approver/history',
        builder: (context, state) => AdaptiveScaffold(
          title: 'Approval History',
          destinations: _approverDestinations,
          selectedIndex: 1,
          onDestinationSelected: (idx) =>
              context.go(_approverDestinations[idx].route),
          body: const PendingRequestsScreen(isHistory: true),
        ),
      ),
    ],
  );
});
