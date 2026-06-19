import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// HEART ALERT – THEME
// ─────────────────────────────────────────────

class AppColors {
  // Brand / accent — unchanged in both modes
  static const Color sageGreen = Color(0xFF7A9E7E);
  static const Color sageLight = Color(0xFFA8C5A0);
  static const Color sageDark  = Color(0xFF4E7252);

  // Light-mode surfaces
  static const Color cream = Color(0xFFF5F0E8);
  static const Color white = Color(0xFFFFFFFF);

  // Light-mode text
  static const Color black = Color(0xFF1A1A1A);

  // Dark-mode surfaces
  static const Color darkBg      = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard    = Color(0xFF252525);

  // Dark-mode text
  static const Color darkText        = Color(0xFFF0EDE8);
  static const Color darkTextMuted   = Color(0xFF9E9E9E);
}

// ─────────────────────────────────────────────
// Semantic helpers — use these in widgets
// instead of raw AppColors.black / AppColors.cream
// so they automatically flip with the theme.
//
//   final t = AppThemeTokens.of(context);
//   color: t.textPrimary
// ─────────────────────────────────────────────

class AppThemeTokens {
  final Color bg;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textMuted;
  final Color border;
  final bool  isDark;

  const AppThemeTokens({
    required this.bg,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.isDark,
  });

  factory AppThemeTokens.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? AppThemeTokens._dark() : AppThemeTokens._light();
  }

  factory AppThemeTokens._light() => const AppThemeTokens(
    bg:          AppColors.cream,
    surface:     AppColors.white,
    card:        AppColors.white,
    textPrimary: AppColors.black,
    textMuted:   Color(0x73000000), // black @ 45 %
    border:      Color(0x0F000000), // black @ 6 %
    isDark:      false,
  );

  factory AppThemeTokens._dark() => const AppThemeTokens(
    bg:          AppColors.darkBg,
    surface:     AppColors.darkSurface,
    card:        AppColors.darkCard,
    textPrimary: AppColors.darkText,
    textMuted:   AppColors.darkTextMuted,
    border:      Color(0x29FFFFFF), // white @ 16 %
    isDark:      true,
  );
}

// ─────────────────────────────────────────────
// Text styles (kept for backward-compat;
// prefer Theme.of(context).textTheme in new widgets)
// ─────────────────────────────────────────────

class AppTextStyles {
  static const TextStyle appTitle = TextStyle(
    color: AppColors.cream,
    fontSize: 22,
    fontWeight: FontWeight.w300,
    letterSpacing: 6,
  );

  static const TextStyle heading = TextStyle(
    color: AppColors.black,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.black,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
}

// ─────────────────────────────────────────────
// Theme data
// ─────────────────────────────────────────────

class AppTheme {
  // ── Light ──────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.cream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.sageGreen,
      brightness: Brightness.light,
      background: AppColors.cream,
      surface: AppColors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.black,
      elevation: 0,
    ),
    cardColor: AppColors.white,
    dividerColor: Color(0x1A000000),
    textTheme: const TextTheme(
      bodyLarge:  TextStyle(color: AppColors.black),
      bodyMedium: TextStyle(color: AppColors.black),
    ),
    useMaterial3: true,
  );

  // ── Dark ───────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.sageGreen,
      brightness: Brightness.dark,
      background: AppColors.darkBg,
      surface: AppColors.darkSurface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.darkText,
      elevation: 0,
    ),
    cardColor: AppColors.darkCard,
    dividerColor: Color(0x29FFFFFF),
    textTheme: const TextTheme(
      bodyLarge:  TextStyle(color: AppColors.darkText),
      bodyMedium: TextStyle(color: AppColors.darkText),
    ),
    useMaterial3: true,
  );

  // kept for backward compatibility
  static ThemeData get theme => lightTheme;
}