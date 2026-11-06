import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';
import 'auth_controller.dart';

/// Clean, centered login form with email/password fields, a Sign In button,
/// and one-tap Quick Demo Account buttons for evaluation.
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
        backgroundColor: AppTheme.ivoryCard,
        title: const Row(
          children: [
            Icon(LucideIcons.cloud, size: 20),
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
                  fillColor: AppTheme.alabasterCanvas,
                  labelText: 'Supabase Project URL',
                  hintText: 'https://<project-ref>.supabase.co',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(
                  fillColor: AppTheme.alabasterCanvas,
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

    return Scaffold(
      backgroundColor: AppTheme.alabasterCanvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppTheme.ivoryCard,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.obsidian,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              LucideIcons.sparkles,
                              color: Color(0xFFF5F2EB),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'HOLIDAY',
                            style: AppTheme.brandTitleStyle(
                              fontSize: 34,
                              color: AppTheme.inkDark,
                            ),
                          ),
                          const SizedBox(width: 6),
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
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to manage your leave requests and approvals',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.inkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          fillColor: AppTheme.alabasterCanvas,
                          labelText: 'Work Email',
                          prefixIcon: Icon(LucideIcons.mail, size: 18),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Enter your work email'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        enabled: !isLoading,
                        obscureText: true,
                        decoration: const InputDecoration(
                          fillColor: AppTheme.alabasterCanvas,
                          labelText: 'Password',
                          prefixIcon: Icon(LucideIcons.lock, size: 18),
                        ),
                        validator: (val) => (val == null || val.isEmpty)
                            ? 'Enter your password'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      // Sign In Button
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: isLoading ? null : _submitEmailLogin,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(LucideIcons.logIn, size: 18),
                          label: const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Quick Demo Accounts',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.inkMuted,
                              ),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _QuickRoleTile(
                        user: DemoUsers.employee,
                        roleTag: 'Employee',
                        icon: LucideIcons.user,
                        enabled: !isLoading,
                        onTap: () => _quickLogin(DemoUsers.employee),
                      ),
                      const SizedBox(height: 8),
                      _QuickRoleTile(
                        user: DemoUsers.manager,
                        roleTag: 'Manager • Stage 1',
                        icon: LucideIcons.users,
                        enabled: !isLoading,
                        onTap: () => _quickLogin(DemoUsers.manager),
                      ),
                      const SizedBox(height: 8),
                      _QuickRoleTile(
                        user: DemoUsers.hr,
                        roleTag: 'HR • Stage 2',
                        icon: LucideIcons.shieldCheck,
                        enabled: !isLoading,
                        onTap: () => _quickLogin(DemoUsers.hr),
                      ),
                      const SizedBox(height: 16),
                      // Subtle Supabase Backend toggle
                      Center(
                        child: TextButton.icon(
                          onPressed: isLoading
                              ? null
                              : _showSupabaseConfigDialog,
                          icon: Icon(
                            isSupabaseConnected
                                ? LucideIcons.cloudCheck
                                : LucideIcons.cloud,
                            size: 15,
                            color: isSupabaseConnected
                                ? AppTheme.sageGreen
                                : AppTheme.inkMuted,
                          ),
                          label: Text(
                            isSupabaseConnected
                                ? 'Supabase Backend Connected'
                                : 'Configure Supabase Backend',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.inkMuted,
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }
}

class _QuickRoleTile extends StatelessWidget {
  final AppUser user;
  final String roleTag;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _QuickRoleTile({
    required this.user,
    required this.roleTag,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.alabasterCanvas,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 17, color: AppTheme.inkDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.inkDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.ivoryCard,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  roleTag,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.terracotta,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: AppTheme.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
