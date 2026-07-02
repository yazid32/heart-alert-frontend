// lib/theme/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
// ─────────────────────────────────────────────
// HEART ALERT – THEME PROVIDER
// Usage: wrap MaterialApp with ChangeNotifierProvider<ThemeProvider>
// ─────────────────────────────────────────────

class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  bool _initialized = false;

  ThemeProvider() {
    _loadThemePreference();
  }

  // ─── Getters ──────────────────────────────────────────

  ThemeMode get themeMode => _themeMode;

  bool get isDark {
    if (_themeMode == ThemeMode.system) {
      // Get system brightness from the platform
      final brightness = WidgetsBinding.instance.window.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  bool get isLight => !isDark;

  bool get isSystemTheme => _themeMode == ThemeMode.system;

  bool get initialized => _initialized;

  // ─── Theme Mode Setters ──────────────────────────────

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _saveThemePreference();
    notifyListeners();
  }

  void toggleTheme() {
    // Cycle: Light → Dark → System → Light
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }
    _saveThemePreference();
    notifyListeners();
  }

  void setLightMode() {
    if (_themeMode == ThemeMode.light) return;
    _themeMode = ThemeMode.light;
    _saveThemePreference();
    notifyListeners();
  }

  void setDarkMode() {
    if (_themeMode == ThemeMode.dark) return;
    _themeMode = ThemeMode.dark;
    _saveThemePreference();
    notifyListeners();
  }

  void setSystemMode() {
    if (_themeMode == ThemeMode.system) return;
    _themeMode = ThemeMode.system;
    _saveThemePreference();
    notifyListeners();
  }

  // ─── Persistence ──────────────────────────────────────

  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = _themeMode.index;
      await prefs.setInt(_themePrefKey, value);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getInt(_themePrefKey);
      if (value != null && value >= 0 && value <= 2) {
        _themeMode = ThemeMode.values[value];
      }
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  // ─── System Theme Change Listener ─────────────────────

  void onSystemThemeChanged() {
    // Only notify if we're in system mode
    if (_themeMode == ThemeMode.system) {
      notifyListeners();
    }
  }

  // ─── Utility Methods ──────────────────────────────────

  /// Returns the current theme mode as a readable string
  String getThemeModeLabel() {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  /// Returns an icon for the current theme mode
  IconData getThemeModeIcon() {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.settings_rounded;
    }
  }

  /// Check if we should use dark mode for a given context
  bool shouldUseDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  /// Get the current theme brightness
  Brightness get currentBrightness {
    return isDark ? Brightness.dark : Brightness.light;
  }

  /// Get the current theme color scheme
  ColorScheme getColorScheme(BuildContext context) {
    final brightness = currentBrightness;
    final isDarkMode = brightness == Brightness.dark;
    
    return ColorScheme(
      brightness: brightness,
      primary: isDarkMode ? AppColors.sageGreenDark : AppColors.sageGreen,
      onPrimary: Colors.white,
      secondary: isDarkMode ? AppColors.sageGreenDark : AppColors.sageGreen,
      onSecondary: Colors.white,
      error: isDarkMode ? AppColors.dangerDark : AppColors.danger,
      onError: Colors.white,
      surface: isDarkMode ? AppColors.darkSurface : AppColors.white,
      onSurface: isDarkMode ? AppColors.darkText : AppColors.black,
      surfaceTint: isDarkMode ? AppColors.darkCard : Colors.white,
      shadow: Colors.black,
      outline: isDarkMode 
          ? const Color(0x29FFFFFF) 
          : const Color(0x0F000000),
      inverseSurface: isDarkMode ? AppColors.white : AppColors.darkBg,
      onInverseSurface: isDarkMode ? AppColors.black : AppColors.darkText,
      primaryContainer: isDarkMode ? AppColors.darkCard : AppColors.cream,
      onPrimaryContainer: isDarkMode ? AppColors.darkText : AppColors.black,
      secondaryContainer: isDarkMode ? AppColors.darkSurface : AppColors.cream,
      onSecondaryContainer: isDarkMode ? AppColors.darkText : AppColors.black,
      tertiary: isDarkMode ? AppColors.sageGreenDark : AppColors.sageGreen,
      onTertiary: Colors.white,
      tertiaryContainer: isDarkMode 
          ? AppColors.sageGreen.withOpacity(0.15) 
          : AppColors.sageGreen.withOpacity(0.1),
      onTertiaryContainer: isDarkMode ? AppColors.darkText : AppColors.black,
    );
  }
}
