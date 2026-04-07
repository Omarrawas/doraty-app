import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

enum AppThemeMode {
  light,
  dark,
  system,
}

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.dark;
  bool _useSystemTheme = false;

  AppThemeMode get appThemeMode => _themeMode;
  bool get useSystemTheme => _useSystemTheme;

  ThemeMode get materialThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  bool get isDarkMode {
    if (_useSystemTheme) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == AppThemeMode.dark;
  }

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    
    _useSystemTheme = prefs.getBool('use_system_theme') ?? false;
    final savedTheme = prefs.getString('theme_mode') ?? 'dark';

    if (!_useSystemTheme) {
      switch (savedTheme) {
        case 'light':
          _themeMode = AppThemeMode.light;
          break;
        case 'dark':
          _themeMode = AppThemeMode.dark;
          break;
        case 'system':
          _themeMode = AppThemeMode.system;
          _useSystemTheme = true;
          break;
        default: // Fallback to dark
          _themeMode = AppThemeMode.dark;
      }
    } else {
      _themeMode = AppThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    _useSystemTheme = mode == AppThemeMode.system;

    final prefs = await SharedPreferences.getInstance();
    String themeString;
    switch (mode) {
      case AppThemeMode.light:
        themeString = 'light';
        break;
      case AppThemeMode.dark:
        themeString = 'dark';
        break;
      case AppThemeMode.system:
        themeString = 'system';
        break;
    }
    await prefs.setString('theme_mode', themeString);
    await prefs.setBool('use_system_theme', _useSystemTheme);

    notifyListeners();
  }

  Future<void> toggleTheme() async {
    if (_themeMode == AppThemeMode.light) {
      await setThemeMode(AppThemeMode.dark);
    } else {
      await setThemeMode(AppThemeMode.light);
    }
  }

  /// Get the appropriate background gradient based on current theme
  Gradient getBackgroundGradient(BuildContext context) {
    return AppColors.getBackgroundGradient(context);
  }
}
