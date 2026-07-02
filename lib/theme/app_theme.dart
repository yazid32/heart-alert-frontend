import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// HEART ALERT – THEME
// ─────────────────────────────────────────────

class AppColors {
  // ── Brand / accent ──────────────────────────
  static const Color sageGreen      = Color(0xFF7A9E7E);
  static const Color sageLight      = Color(0xFFA8C5A0);
  static const Color sageDark       = Color(0xFF4E7252);
  // Slightly lighter/more luminous for dark-mode surfaces
  static const Color sageGreenDark  = Color(0xFF8FB593);

  // ── Semantic / risk states ───────────────────
  static const Color danger         = Color(0xFFD64045); // high cardiac risk
  static const Color dangerLight    = Color(0xFFFFEDEE); // danger background tint
  static const Color dangerDark     = Color(0xFFFF6B6B); // danger on dark surfaces
  static const Color warning        = Color(0xFFE8A838); // moderate risk
  static const Color warningLight   = Color(0xFFFFF8EC);
  static const Color warningDark    = Color(0xFFFFBF4D);
  static const Color success        = Color(0xFF4CAF79); // low risk / all-clear
  static const Color successLight   = Color(0xFFEDF7F1);
  static const Color successDark    = Color(0xFF6FCF97);

  // ── Light-mode surfaces ──────────────────────
  static const Color cream          = Color(0xFFF5F0E8);
  static const Color white          = Color(0xFFFFFFFF);

  // ── Light-mode text ──────────────────────────
  static const Color black          = Color(0xFF1A1A1A);

  // ── Dark-mode surfaces (warm-tinted, not pure neutral) ─
  static const Color darkBg         = Color(0xFF13110F); // warm near-black
  static const Color darkSurface    = Color(0xFF1E1C1A); // warm dark surface
  static const Color darkCard       = Color(0xFF262320); // warm card

  // ── Dark-mode text ───────────────────────────
  static const Color darkText       = Color(0xFFF0EDE8);
  static const Color darkTextMuted  = Color(0xFF9A9490);
}

// ─────────────────────────────────────────────
// Semantic tokens — use these in widgets so
// colours, shadows, gradients, and dividers
// automatically flip with the theme.
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
  final Color divider;
  final Color danger;
  final Color dangerBg;
  final Color warning;
  final Color warningBg;
  final Color success;
  final Color successBg;
  final Color accent;          // contextual sageGreen variant
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> modalShadow;
  final LinearGradient primaryGradient;   // hero banners, headers
  final LinearGradient subtleGradient;    // card tints, backgrounds
  final bool isDark;

  const AppThemeTokens({
    required this.bg,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.danger,
    required this.dangerBg,
    required this.warning,
    required this.warningBg,
    required this.success,
    required this.successBg,
    required this.accent,
    required this.cardShadow,
    required this.modalShadow,
    required this.primaryGradient,
    required this.subtleGradient,
    required this.isDark,
  });

  factory AppThemeTokens.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? AppThemeTokens._dark() : AppThemeTokens._light();
  }

  factory AppThemeTokens._light() => AppThemeTokens(
    bg:             AppColors.cream,
    surface:        AppColors.white,
    card:           AppColors.white,
    textPrimary:    AppColors.black,
    textMuted:      const Color(0x73000000), // black @ 45 %
    border:         const Color(0x0F000000), // black @ 6 %
    divider:        const Color(0x1A000000), // black @ 10 %
    danger:         AppColors.danger,
    dangerBg:       AppColors.dangerLight,
    warning:        AppColors.warning,
    warningBg:      AppColors.warningLight,
    success:        AppColors.success,
    successBg:      AppColors.successLight,
    accent:         AppColors.sageGreen,
    cardShadow: const [
      BoxShadow(
        color: Color(0x0D000000),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
      BoxShadow(
        color: Color(0x07000000),
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
    ],
    modalShadow: const [
      BoxShadow(
        color: Color(0x26000000),
        blurRadius: 32,
        offset: Offset(0, 12),
      ),
    ],
    primaryGradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.sageDark, AppColors.sageGreen, AppColors.sageLight],
      stops: [0.0, 0.55, 1.0],
    ),
    subtleGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.white, AppColors.cream],
    ),
    isDark: false,
  );

  factory AppThemeTokens._dark() => AppThemeTokens(
    bg:             AppColors.darkBg,
    surface:        AppColors.darkSurface,
    card:           AppColors.darkCard,
    textPrimary:    AppColors.darkText,
    textMuted:      AppColors.darkTextMuted,
    border:         const Color(0x29FFFFFF), // white @ 16 %
    divider:        const Color(0x1FFFFFFF), // white @ 12 %
    danger:         AppColors.dangerDark,
    dangerBg:       const Color(0x26D64045), // danger @ 15 %
    warning:        AppColors.warningDark,
    warningBg:      const Color(0x26E8A838), // warning @ 15 %
    success:        AppColors.successDark,
    successBg:      const Color(0x264CAF79), // success @ 15 %
    accent:         AppColors.sageGreenDark,
    cardShadow: const [
      // Dark mode: subtle inner glow instead of drop shadow
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ],
    modalShadow: const [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 40,
        offset: Offset(0, 16),
      ),
    ],
    primaryGradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.sageDark, AppColors.sageGreenDark],
      stops: [0.0, 1.0],
    ),
    subtleGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.darkSurface, AppColors.darkBg],
    ),
    isDark: true,
  );
}

// ─────────────────────────────────────────────
// Text styles
// NOTE: These use theme-aware colours via
// DefaultTextStyle — prefer Theme.of(context).textTheme
// in new widgets. These are kept for backward compat.
// ─────────────────────────────────────────────

class AppTextStyles {
  // App bar title — always on a dark/coloured surface
  static const TextStyle appTitle = TextStyle(
    color: AppColors.cream,
    fontSize: 22,
    fontWeight: FontWeight.w300,
    letterSpacing: 6,
  );

  // Use these with AppThemeTokens.of(context).textPrimary
  // to get dark-mode-safe colours at the call site.
  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    // colour intentionally omitted — set via DefaultTextStyle or explicit color
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    // colour intentionally omitted — set via DefaultTextStyle or explicit color
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
      surface: AppColors.white,
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.black,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    dividerColor: Color(0x1A000000),
    textTheme: const TextTheme(
      displayLarge:  TextStyle(color: AppColors.black, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: AppColors.black, fontWeight: FontWeight.w600),
      titleLarge:    TextStyle(color: AppColors.black, fontWeight: FontWeight.w600, fontSize: 20),
      titleMedium:   TextStyle(color: AppColors.black, fontWeight: FontWeight.w500, fontSize: 16),
      titleSmall:    TextStyle(color: AppColors.black, fontWeight: FontWeight.w500, fontSize: 14),
      bodyLarge:     TextStyle(color: AppColors.black, fontSize: 16, height: 1.5),
      bodyMedium:    TextStyle(color: AppColors.black, fontSize: 14, height: 1.5),
      bodySmall:     TextStyle(color: Color(0x73000000), fontSize: 12, height: 1.4),
      labelLarge:    TextStyle(color: AppColors.black, fontWeight: FontWeight.w500, fontSize: 14),
      labelMedium:   TextStyle(color: Color(0x73000000), fontWeight: FontWeight.w500, fontSize: 12),
      labelSmall:    TextStyle(color: Color(0x73000000), fontWeight: FontWeight.w400, fontSize: 11),
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
      surface: AppColors.darkSurface,
      error: AppColors.dangerDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.darkText,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    dividerColor: Color(0x29FFFFFF),
    textTheme: const TextTheme(
      displayLarge:  TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w600),
      titleLarge:    TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w600, fontSize: 20),
      titleMedium:   TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w500, fontSize: 16),
      titleSmall:    TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w500, fontSize: 14),
      bodyLarge:     TextStyle(color: AppColors.darkText, fontSize: 16, height: 1.5),
      bodyMedium:    TextStyle(color: AppColors.darkText, fontSize: 14, height: 1.5),
      bodySmall:     TextStyle(color: AppColors.darkTextMuted, fontSize: 12, height: 1.4),
      labelLarge:    TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w500, fontSize: 14),
      labelMedium:   TextStyle(color: AppColors.darkTextMuted, fontWeight: FontWeight.w500, fontSize: 12),
      labelSmall:    TextStyle(color: AppColors.darkTextMuted, fontWeight: FontWeight.w400, fontSize: 11),
    ),
    useMaterial3: true,
  );

  // kept for backward compatibility
  static ThemeData get theme => lightTheme;
}