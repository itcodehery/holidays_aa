import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/app_user.dart';
import 'auth_controller.dart';

/// Displays a confirmation dialog before logging the user out of the app.
Future<void> showLogoutConfirmationDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final router = GoRouter.maybeOf(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.ivoryCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: const Row(
        children: [
          Icon(LucideIcons.logOut, size: 20, color: AppTheme.terracotta),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Log out of Interlude?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.inkDark,
              ),
            ),
          ),
        ],
      ),
      content: const Text(
        'Are you sure you want to log out of your account?',
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.inkMuted,
          height: 1.45,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppTheme.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.terracotta,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(LucideIcons.logOut, size: 16),
          label: const Text('Log Out'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await ref.read(authControllerProvider.notifier).signOut();
    router?.go('/login');
  }
}

/// Normal fullscreen "Account" page shared across all three account types
/// (Employee, Manager, and HR/Admin) without the top editorial summary banner.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const SizedBox.shrink();
    }

    final roleBadge = switch (user.role) {
      Role.employee => 'Employee',
      Role.manager => 'Manager',
      Role.hr => 'HR / Admin',
    };

    final managerDisplayName = user.managerName?.trim().isNotEmpty == true
        ? user.managerName!
        : (user.managerId != null && user.managerId!.isNotEmpty
              ? 'Priya Sharma'
              : null);

    return ColoredBox(
      color: AppTheme.alabasterCanvas,
      child: SizedBox.expand(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.inkDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your profile and reporting details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Profile header card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.ivoryCard,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppTheme.terracotta,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    user.fullName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.inkDark,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.terracottaSoft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      roleBadge,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.terracotta,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.inkMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Account details card (Full Name, Work Email, Role, Reporting Manager Name)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.ivoryCard,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AccountDetailRow(
                          icon: LucideIcons.user,
                          label: 'Full Name',
                          value: user.fullName,
                        ),
                        const SizedBox(height: 16),
                        _AccountDetailRow(
                          icon: LucideIcons.mail,
                          label: 'Work Email',
                          value: user.email,
                        ),
                        const SizedBox(height: 16),
                        _AccountDetailRow(
                          icon: LucideIcons.shieldCheck,
                          label: 'Role',
                          value: roleBadge,
                        ),
                        if (managerDisplayName != null) ...[
                          const SizedBox(height: 16),
                          _AccountDetailRow(
                            icon: LucideIcons.users,
                            label: 'Reporting Manager',
                            value: managerDisplayName,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.terracotta,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () =>
                          showLogoutConfirmationDialog(context, ref),
                      icon: const Icon(LucideIcons.logOut, size: 18),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AccountDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.alabasterCanvas,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 19, color: AppTheme.inkDark),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.inkDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
