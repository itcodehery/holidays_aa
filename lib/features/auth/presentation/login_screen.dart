import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';
import 'auth_controller.dart';

/// Email/password login screen with one-tap "Quick Demo Login" buttons for the
/// three seeded personas (`Employee`, `Manager`, `HR / Admin`).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: DemoUsers.employee.email);
  final _passwordController = TextEditingController(text: 'demo1234');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signIn(_emailController.text, _passwordController.text);
    if (!ok && mounted) {
      final err = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err?.toString() ?? 'Login failed.')),
      );
    }
  }

  Future<void> _quickLogin(AppUser demoUser) async {
    _emailController.text = demoUser.email;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signInAsDemo(demoUser.role);
    if (!ok && mounted) {
      final err = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err?.toString() ?? 'Quick login failed.')),
      );
    }
  }

  Future<void> _showSupabaseConfigDialog() async {
    final urlCtrl = TextEditingController(text: AppConfig.supabaseUrl);
    final keyCtrl = TextEditingController(
      text: AppConfig.supabasePublishableKey,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_outlined),
            SizedBox(width: 8),
            Expanded(child: Text('Supabase Backend Configuration')),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter your Supabase project URL and publishable/anon key (or pass via --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...).',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Supabase Project URL',
                  hintText: 'https://<project-ref>.supabase.co',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Publishable / Anon Key',
                  hintText: 'sb_publishable_... or eyJ...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Connect Supabase'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      if (urlCtrl.text.trim().isEmpty || keyCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Both URL and Key are required.')),
        );
        return;
      }
      try {
        await AppConfig.configureSupabase(
          url: urlCtrl.text,
          key: keyCtrl.text,
        );
        ref.read(supabaseBackendModeProvider.notifier).markConnected();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connected to Supabase backend!'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to initialize Supabase: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isSupabaseConnected = ref.watch(supabaseBackendModeProvider);
    final isLoading = authState.isLoading;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.event_available_rounded,
                              color: scheme.onPrimaryContainer,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Holiday',
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.brandTitleStyle(
                                          fontSize: 30,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.terracotta,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Employee Leave Management System',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ActionChip(
                          avatar: Icon(
                            isSupabaseConnected
                                ? Icons.cloud_done_rounded
                                : Icons.cloud_upload_outlined,
                            size: 16,
                            color: isSupabaseConnected
                                ? AppTheme.sageGreen
                                : scheme.primary,
                          ),
                          label: Text(
                            isSupabaseConnected
                                ? 'Supabase Live'
                                : 'Connect Supabase',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _showSupabaseConfigDialog,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              enabled: !isLoading,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Work Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                  ? 'Enter your work email'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !isLoading,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                              validator: (val) => (val == null || val.isEmpty)
                                  ? 'Enter your password'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: isLoading ? null : _submitEmailLogin,
                                icon: isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.login_rounded),
                                label: const Text('Sign In'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Quick Demo Accounts',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _DemoAccountButton(
                        user: DemoUsers.employee,
                        subtitle:
                            'Submit requests, attach proof, view approval timeline',
                        icon: Icons.person_outline_rounded,
                        enabled: !isLoading,
                        onTap: () => _quickLogin(DemoUsers.employee),
                      ),
                      const SizedBox(height: 8),
                      _DemoAccountButton(
                        user: DemoUsers.manager,
                        subtitle:
                            'Approve or reject direct reports (Stage 1 queue)',
                        icon: Icons.supervisor_account_outlined,
                        enabled: !isLoading,
                        onTap: () => _quickLogin(DemoUsers.manager),
                      ),
                      const SizedBox(height: 8),
                      _DemoAccountButton(
                        user: DemoUsers.hr,
                        subtitle:
                            'Stage 2 approval for > 3 working days & full history',
                        icon: Icons.admin_panel_settings_outlined,
                        enabled: !isLoading,
                        onTap: () => _quickLogin(DemoUsers.hr),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoAccountButton extends StatelessWidget {
  final AppUser user;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _DemoAccountButton({
    required this.user,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.fullName} (${user.role.label})',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
