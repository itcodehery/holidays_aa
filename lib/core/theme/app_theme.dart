import 'package:flutter/material.dart';

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

/// Application Material 3 design system inspired by warm editorial minimalism:
/// - Deep obsidian header surfaces (`#16171B`)
/// - Warm alabaster/sand sheet canvas (`#EFECE4`) & crisp ivory cards (`#FAF8F3`)
/// - Burnt terracotta primary accent (`#D95D39`) & sage emerald (`#2E9E5B`)
/// - Centralized accessible status colors (amber, blue, green, red, grey)
class AppTheme {
  const AppTheme._();

  // Core design system tokens
  static const String brandFontFamily = 'DM Serif Display';
  static const Color obsidian = Color(0xFF16171B);
  static const Color obsidianElevated = Color(0xFF202228);
  static const Color terracotta = Color(0xFFD95D39);
  static const Color terracottaSoft = Color(0xFFF9E5DE);
  static const Color alabasterCanvas = Color(0xFFEFECE4);
  static const Color ivoryCard = Color(0xFFFAF8F3);
  static const Color warmTaupe = Color(0xFFE6E2D8);
  static const Color sandBorder = Color(0xFFE2DDD2);
  static const Color sageGreen = Color(0xFF2E9E5B);

  /// Typography style for the "Holiday" brand name using Google Fonts' DM Serif Display.
  static TextStyle brandTitleStyle({
    double fontSize = 26,
    Color? color,
    double letterSpacing = 0.2,
  }) {
    return TextStyle(
      fontFamily: brandFontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      letterSpacing: letterSpacing,
      color: color,
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
      onSecondaryContainer: const Color(0xFF262420),
      tertiary: const Color(0xFF1E40AF),
      tertiaryContainer: const Color(0xFFDBEAFE),
      onTertiaryContainer: const Color(0xFF1E3A8A),
      surface: ivoryCard,
      onSurface: const Color(0xFF19191B),
      onSurfaceVariant: const Color(0xFF656159),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: ivoryCard,
      surfaceContainer: alabasterCanvas,
      surfaceContainerHighest: warmTaupe,
      outline: const Color(0xFF969084),
      outlineVariant: sandBorder,
    );
    return _buildTheme(scheme, scaffoldBg: alabasterCanvas);
  }

  static ThemeData get dark {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: terracotta,
      brightness: Brightness.dark,
    );
    final scheme = baseScheme.copyWith(
      primary: const Color(0xFFE67350),
      onPrimary: const Color(0xFF2B0B02),
      primaryContainer: const Color(0xFF5C2210),
      onPrimaryContainer: const Color(0xFFFFDBD0),
      secondaryContainer: const Color(0xFF2A2B32),
      onSecondaryContainer: const Color(0xFFE8E4DC),
      surface: obsidianElevated,
      onSurface: const Color(0xFFF4F1EA),
      onSurfaceVariant: const Color(0xFFA6A29A),
      surfaceContainerLowest: obsidian,
      surfaceContainerHighest: const Color(0xFF2C2E36),
      outlineVariant: const Color(0xFF32343D),
    );
    return _buildTheme(scheme, scaffoldBg: obsidian);
  }

  static ThemeData _buildTheme(
    ColorScheme scheme, {
    required Color scaffoldBg,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: obsidian,
        foregroundColor: const Color(0xFFF4F1EA),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  /// Centralized status styling:
  /// - Amber: `pendingManager`
  /// - Blue: `pendingHr`
  /// - Green: `approved`
  /// - Red: `rejected`
  /// - Grey: `cancelled`
  static StatusStyle statusStyle(
    LeaveStatus status, {
    Brightness brightness = Brightness.light,
  }) {
    final isDark = brightness == Brightness.dark;
    switch (status) {
      case LeaveStatus.pendingManager:
        return StatusStyle(
          foreground: isDark ? const Color(0xFFFCD34D) : const Color(0xFF9A3412),
          background: isDark ? const Color(0xFF451A03) : const Color(0xFFFFEDD5),
          border: isDark ? const Color(0xFFB45309) : const Color(0xFFF59E0B),
          icon: Icons.hourglass_top_rounded,
        );
      case LeaveStatus.pendingHr:
        return StatusStyle(
          foreground: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
          background: isDark ? const Color(0xFF172554) : const Color(0xFFDBEAFE),
          border: isDark ? const Color(0xFF2563EB) : const Color(0xFF3B82F6),
          icon: Icons.policy_outlined,
        );
      case LeaveStatus.approved:
        return StatusStyle(
          foreground: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
          background: isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7),
          border: isDark ? const Color(0xFF16A34A) : const Color(0xFF22C55E),
          icon: Icons.check_circle_outline_rounded,
        );
      case LeaveStatus.rejected:
        return StatusStyle(
          foreground: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
          background: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
          border: isDark ? const Color(0xFFDC2626) : const Color(0xFFEF4444),
          icon: Icons.cancel_outlined,
        );
      case LeaveStatus.cancelled:
        return StatusStyle(
          foreground: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
          background: isDark ? const Color(0xFF1F2937) : const Color(0xFFE6E2D8),
          border: isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
          icon: Icons.remove_circle_outline_rounded,
        );
    }
  }
}
