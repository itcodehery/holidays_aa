import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';

/// Editorial onboarding-style login screen inspired by Peloton's hero + bottom
/// action sheet layout while retaining Interlude's warm alabaster, ivory,
/// terracotta, and obsidian palette.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  int _currentSlide = 0;
  bool _obscurePassword = true;

  static const List<_HeroSlide> _slides = [
    _HeroSlide(
      headline: 'Plan your time off,\ncrush burnout',
      subtitle: 'Workspace leave & multi-stage approvals in one place.',
      icon: LucideIcons.treePalm,
    ),
    _HeroSlide(
      headline: 'Track approvals,\nin real time',
      subtitle: 'Instant visibility from Manager review to HR sign-off.',
      icon: LucideIcons.calendarCheck,
    ),
    _HeroSlide(
      headline: 'Attach documents,\nin a single tap',
      subtitle: 'Upload medical or travel proof without email threads.',
      icon: LucideIcons.fileCheck2,
    ),
    _HeroSlide(
      headline: 'Step away cleanly,\nrecharge fully',
      subtitle: 'Clear handoffs and transparent working-day calculations.',
      icon: LucideIcons.sunMedium,
    ),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pageController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.alabasterCanvas,
      body: Stack(
        children: [
          // Top Hero Visual Backdrop with smooth fade into Alabaster Canvas
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 440,
            child: _WarmEditorialHeroBackdrop(activeSlide: _currentSlide),
          ),

          // Main Scrollable Foreground (handles keyboard insets gracefully)
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final topHeroGap = ((constraints.maxHeight - 640) * 0.45)
                    .clamp(16.0, 120.0);
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),

                              // Top-Centered Brand Wordmark (Peloton-style header)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        LucideIcons.treePalm,
                                        color: AppTheme.inkDark,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'INTERLUDE',
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTheme.brandTitleStyle(
                                            fontSize: 28,
                                            color: AppTheme.inkDark,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.terracotta,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'for Akasa Air',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.inkMuted,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: topHeroGap),

                              // Center Hero Focal Emblem + Swipeable 2-Line Headline
                              SizedBox(
                                height: 220,
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: _slides.length,
                                  onPageChanged: (index) {
                                    setState(() => _currentSlide = index);
                                  },
                                  itemBuilder: (context, index) {
                                    final slide = _slides[index];
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          width: 76,
                                          height: 76,
                                          decoration: BoxDecoration(
                                            color: AppTheme.ivoryCard
                                                .withValues(alpha: 0.88),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppTheme.sandBorder,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.terracotta
                                                    .withValues(alpha: 0.14),
                                                blurRadius: 28,
                                                offset: const Offset(0, 12),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            slide.icon,
                                            size: 32,
                                            color: AppTheme.terracotta,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          slide.headline,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.inkDark,
                                            height: 1.14,
                                            letterSpacing: -0.8,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 18),

                              // 4 Horizontal Pill Carousel Indicators
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_slides.length, (i) {
                                  final isSelected = i == _currentSlide;
                                  return GestureDetector(
                                    onTap: () =>
                                        _pageController.animateToPage(
                                          i,
                                          duration: const Duration(
                                            milliseconds: 260,
                                          ),
                                          curve: Curves.easeOutCubic,
                                        ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      width: 28,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.terracotta
                                            : AppTheme.sandBorder,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),

                              const SizedBox(height: 16),

                              // Muted Subtitle Line
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  _slides[_currentSlide].subtitle,
                                  key: ValueKey(_currentSlide),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.inkMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Bottom Controls Stack
                              // Work Email Pill Input
                              TextFormField(
                                controller: _emailController,
                                enabled: !isLoading,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                scrollPadding: const EdgeInsets.only(
                                  bottom: 180,
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.inkDark,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppTheme.ivoryCard,
                                  hintText: 'Work email (you@company.com)',
                                  hintStyle: const TextStyle(
                                    color: AppTheme.inkMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  prefixIcon: const Icon(
                                    LucideIcons.mail,
                                    size: 18,
                                    color: AppTheme.inkMuted,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: AppTheme.sandBorder,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: AppTheme.sandBorder,
                                    ),
                                  ),
                                ),
                                validator: (val) =>
                                    (val == null || val.trim().isEmpty)
                                    ? 'Enter your work email'
                                    : null,
                              ),

                              const SizedBox(height: 10),

                              // Password Pill Input
                              TextFormField(
                                controller: _passwordController,
                                enabled: !isLoading,
                                obscureText: _obscurePassword,
                                onFieldSubmitted: (_) => _submitEmailLogin(),
                                scrollPadding: const EdgeInsets.only(
                                  bottom: 140,
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.inkDark,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppTheme.ivoryCard,
                                  hintText: 'Password',
                                  hintStyle: const TextStyle(
                                    color: AppTheme.inkMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  prefixIcon: const Icon(
                                    LucideIcons.lock,
                                    size: 18,
                                    color: AppTheme.inkMuted,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? LucideIcons.eyeOff
                                          : LucideIcons.eye,
                                      size: 18,
                                      color: AppTheme.inkMuted,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: AppTheme.sandBorder,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: AppTheme.sandBorder,
                                    ),
                                  ),
                                ),
                                validator: (val) =>
                                    (val == null || val.isEmpty)
                                    ? 'Enter your password'
                                    : null,
                              ),

                              const SizedBox(height: 12),

                              // Full-Width Primary Action Bar ("Sign In")
                              SizedBox(
                                height: 52,
                                child: FilledButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : _submitEmailLogin,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.obsidian,
                                    foregroundColor: const Color(0xFFF5F2EB),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFF5F2EB),
                                          ),
                                        )
                                      : const Icon(
                                          LucideIcons.logIn,
                                          size: 18,
                                        ),
                                  label: const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Terms & Policy Caption
                              RichText(
                                textAlign: TextAlign.center,
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.45,
                                    color: AppTheme.inkMuted,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          'By signing in, you accept Interlude\'s ',
                                    ),
                                    TextSpan(
                                      text: 'Workspace Terms',
                                      style: TextStyle(
                                        color: AppTheme.inkDark,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Leave Policy',
                                      style: TextStyle(
                                        color: AppTheme.inkDark,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ', and acknowledge the ',
                                    ),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                        color: AppTheme.inkDark,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(text: '.'),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Bottom Underlined Support Action
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Use your organization email and password issued by HR Admin.',
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Need an account? Contact HR Admin',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.inkDark,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppTheme.inkDark,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSlide {
  final String headline;
  final String subtitle;
  final IconData icon;

  const _HeroSlide({
    required this.headline,
    required this.subtitle,
    required this.icon,
  });
}

/// Warm sunlit editorial backdrop that occupies the upper half of the screen
/// and fades seamlessly into `AppTheme.alabasterCanvas`.
class _WarmEditorialHeroBackdrop extends StatelessWidget {
  final int activeSlide;

  const _WarmEditorialHeroBackdrop({required this.activeSlide});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base warm terracotta-sand wash
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFEAD8C8),
                Color(0xFFEDE4D8),
                AppTheme.alabasterCanvas,
              ],
              stops: [0.0, 0.62, 1.0],
            ),
          ),
        ),
        // Soft architectural sun-arch & radial glow
        Positioned(
          top: -60,
          left: -40,
          right: -40,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(
                  (activeSlide - 1.5) * 0.25,
                  -0.1,
                ),
                radius: 0.85,
                colors: [
                  AppTheme.terracotta.withValues(alpha: 0.22),
                  AppTheme.terracottaSoft.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        // Subtle editorial arch silhouette in the upper center
        Align(
          alignment: const Alignment(0, -0.25),
          child: Container(
            width: 220,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(120),
                bottom: Radius.circular(24),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.ivoryCard.withValues(alpha: 0.65),
                  AppTheme.terracottaSoft.withValues(alpha: 0.25),
                  AppTheme.alabasterCanvas.withValues(alpha: 0.0),
                ],
              ),
              border: Border.all(
                color: AppTheme.ivoryCard.withValues(alpha: 0.7),
                width: 1.5,
              ),
            ),
          ),
        ),
        // Bottom gradient vignette that blends smoothly into Alabaster Canvas
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 150,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.alabasterCanvas.withValues(alpha: 0.0),
                  AppTheme.alabasterCanvas.withValues(alpha: 0.85),
                  AppTheme.alabasterCanvas,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
