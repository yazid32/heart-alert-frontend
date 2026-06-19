import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// HEART ALERT – THEME PROVIDER
// Usage: wrap MaterialApp with ChangeNotifierProvider<ThemeProvider>
// ─────────────────────────────────────────────

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
