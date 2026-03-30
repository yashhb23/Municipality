import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Theme provider: light/dark only, ThemeMode.system with manual toggle.
/// Uses Poppins font and AppConfig colors (#00D9A3 primary, dark #0A0A0A/#1A1A1A).
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';

  AppTheme _currentTheme = AppTheme.dark;
  bool _isDarkMode = true;

  AppTheme get currentTheme => _currentTheme;
  bool get isDarkMode => _isDarkMode;
  ThemeData get themeData => _getThemeData(_currentTheme);

  Future<void> initializeTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      final savedTheme = prefs.getString(_themeKey);
      if (savedTheme != null) {
        for (final t in AppTheme.values) {
          if (t.name == savedTheme) {
            _currentTheme = t;
            _isDarkMode = (t == AppTheme.dark);
            notifyListeners();
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Theme initialization failed, using default: $e');
      // Continue with default light theme
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    _isDarkMode = (theme == AppTheme.dark);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.name);
  }

  Future<void> toggleTheme() async {
    if (_isDarkMode) {
      await setTheme(AppTheme.light);
    } else {
      await setTheme(AppTheme.dark);
    }
  }

  ThemeData _getThemeData(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return _lightTheme();
      case AppTheme.dark:
        return _darkTheme();
    }
  }

  static TextTheme _poppinsTextTheme(Color primary, Color onSurface, Color secondary) {
    return TextTheme(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: onSurface,
        height: 1.2,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: onSurface,
        height: 1.2,
      ),
      displaySmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: onSurface,
        height: 1.3,
      ),
      headlineLarge: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.3,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.3,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.4,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.4,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.4,
      ),
      titleSmall: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.4,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: onSurface,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurface,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.5,
      ),
      labelLarge: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.4,
      ),
      labelMedium: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondary,
        height: 1.4,
      ),
      labelSmall: GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: secondary,
        height: 1.4,
      ),
    );
  }

  ThemeData _lightTheme() {
    const primary = Color(AppConfig.primaryLightValue);
    const surface = Color(AppConfig.lightSurfaceValue);
    const background = Color(AppConfig.lightBackgroundValue);
    const onPrimary = Colors.white;
    const onSurface = Color(AppConfig.lightTextPrimaryValue);
    const onSurfaceSecondary = Color(AppConfig.lightTextSecondaryValue);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        surface: surface,
        onSurface: onSurface,
        error: Color(AppConfig.errorColorValue),
        onError: Colors.white,
      ),
      textTheme: _poppinsTextTheme(primary, onSurface, onSurfaceSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: primary),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }

  ThemeData _darkTheme() {
    const primary = Color(AppConfig.primaryColorValue);
    const surface = Color(AppConfig.darkSurfaceValue);
    const background = Color(AppConfig.darkBackgroundValue);
    const onPrimary = Colors.white;
    const onSurface = Color(AppConfig.darkTextPrimaryValue);
    const onSurfaceSecondary = Color(AppConfig.darkTextSecondaryValue);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        surface: surface,
        onSurface: onSurface,
        error: Color(AppConfig.errorColorValue),
        onError: Colors.white,
      ),
      textTheme: _poppinsTextTheme(primary, onSurface, onSurfaceSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: primary),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }
}

/// Light and dark themes only (redesign).
enum AppTheme {
  light('Light', Icons.light_mode, Color(AppConfig.primaryLightValue)),
  dark('Dark', Icons.dark_mode, Color(AppConfig.primaryColorValue));

  const AppTheme(this.displayName, this.icon, this.primaryColor);

  final String displayName;
  final IconData icon;
  final Color primaryColor;
}
