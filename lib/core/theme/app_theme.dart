import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/leave/domain/leave_status.dart';

/// Visual styling token for a [LeaveStatus] (paired color, background, and icon
/// so status is never communicated by color alone).
class StatusStyle {
  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;

  const StatusStyle({
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
  });
}

/// Two-tone editorial design system for **Interlude**:
/// - Default body/UI font: **Plus Jakarta Sans**
/// - Brand wordmark font: **BBH Sans Bogle** (`INTERLUDE`, `letterSpacing: -0.5`)
/// - Top header zone: Deep Obsidian (`#18191D`)
/// - Lower sheet zone: Warm Alabaster/Stone (`#EAE6DD`)
/// - Cards & controls: Borderless Warm Ivory (`#F7F5F0`) with squircle icon
///   containers (`#F5DDD4` terracotta blush & `#E1DDD3` warm taupe)
/// - Accent: Burnt Terracotta (`#D95D39`) and Sage Green (`#2E9E5B`)
class AppTheme {
  const AppTheme._();

  static const String bodyFontFamily = 'Plus Jakarta Sans';
  static const String brandFontFamily = 'BBH Sans Bogle';

  // Two-tone palette tokens
  static const Color obsidian = Color(0xFF18191D);
  static const Color obsidianElevated = Color(0xFF23252B);
  static const Color obsidianPill = Color(0xFF141519);
  static const Color obsidianPillActive = Color(0xFF2A2C34);
  static const Color obsidianPillRim = Color(0xFF2C2E37);

  static const Color terracotta = Color(0xFFD95D39);
  static const Color terracottaHighlight = Color(0xFFE26B47);
  static const Color terracottaSoft = Color(0xFFF4DDD4);

  static const Color alabasterCanvas = Color(0xFFEAE6DD);
  static const Color ivoryCard = Color(0xFFF7F5F0);
  static const Color warmTaupe = Color(0xFFE0DCD2);
  static const Color sandBorder = Color(0xFFDDD8CC);
  static const Color sageGreen = Color(0xFF32A862);
  static const Color inkDark = Color(0xFF18181A);
  static const Color inkMuted = Color(0xFF6B675E);

  /// Typography style for the all-caps "INTERLUDE" brand name using BBH Bogle.
  static TextStyle brandTitleStyle({
    double fontSize = 26,
    Color? color,
    double letterSpacing = -0.5,
  }) {
    return TextStyle(
      fontFamily: brandFontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      letterSpacing: letterSpacing,
      color: color ?? const Color(0xFFF5F2EB),
    );
  }

  static ThemeData get light {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: terracotta,
      brightness: Brightness.light,
    );
    final scheme = baseScheme.copyWith(
      primary: terracotta,
      onPrimary: Colors.white,
      primaryContainer: terracottaSoft,
      onPrimaryContainer: const Color(0xFF5C1E0B),
      secondary: const Color(0xFF524E46),
      onSecondary: Colors.white,
      secondaryContainer: warmTaupe,
      onSecondaryContainer: inkDark,
      tertiary: const Color(0xFF1E40AF),
      tertiaryContainer: const Color(0xFFDBEAFE),
      onTertiaryContainer: const Color(0xFF1E3A8A),
      surface: ivoryCard,
      onSurface: inkDark,
      onSurfaceVariant: inkMuted,
      surfaceContainerLowest: ivoryCard,
      surfaceContainerLow: ivoryCard,
      surfaceContainer: alabasterCanvas,
      surfaceContainerHighest: warmTaupe,
      outline: const Color(0xFF9E988C),
      outlineVariant: sandBorder,
    );
    return _buildTheme(scheme, scaffoldBg: alabasterCanvas);
  }

  static ThemeData get dark => light;

  static ThemeData _buildTheme(
    ColorScheme scheme, {
    required Color scaffoldBg,
  }) {
    final baseText = Typography.material2021().black.apply(
      fontFamily: bodyFontFamily,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: bodyFontFamily,
      textTheme: baseText,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 0,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: obsidian,
        foregroundColor: Color(0xFFF5F2EB),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: ivoryCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ivoryCard,
        selectedColor: terracottaSoft,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide.none,
        ),
        labelStyle: const TextStyle(
          fontFamily: bodyFontFamily,
          fontWeight: FontWeight.w600,
          color: inkDark,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: bodyFontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          backgroundColor: ivoryCard,
          foregroundColor: inkDark,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: bodyFontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ivoryCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
    );
  }

  /// Centralized status styling with Lucide icons:
  /// - Terracotta/Amber: `pendingManager`
  /// - Soft Blue: `pendingHr`
  /// - Soft Sage Green: `approved`
  /// - Soft Coral Red: `rejected`
  /// - Warm Taupe Grey: `cancelled`
  static StatusStyle statusStyle(
    LeaveStatus status, {
    Brightness brightness = Brightness.light,
  }) {
    switch (status) {
      case LeaveStatus.pendingManager:
        return const StatusStyle(
          foreground: Color(0xFFB84724),
          background: Color(0xFFF5DDD4),
          border: Colors.transparent,
          icon: LucideIcons.hourglass,
        );
      case LeaveStatus.pendingHr:
        return const StatusStyle(
          foreground: Color(0xFF1D4ED8),
          background: Color(0xFFDCE8FD),
          border: Colors.transparent,
          icon: LucideIcons.shieldCheck,
        );
      case LeaveStatus.approved:
        return const StatusStyle(
          foreground: Color(0xFF18794E),
          background: Color(0xFFD9F0E3),
          border: Colors.transparent,
          icon: LucideIcons.circleCheck,
        );
      case LeaveStatus.rejected:
        return const StatusStyle(
          foreground: Color(0xFFB42318),
          background: Color(0xFFFADCD9),
          border: Colors.transparent,
          icon: LucideIcons.circleX,
        );
      case LeaveStatus.cancelled:
        return const StatusStyle(
          foreground: Color(0xFF57534E),
          background: Color(0xFFE2DFD7),
          border: Colors.transparent,
          icon: LucideIcons.circleMinus,
        );
    }
  }
}
