import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Theme provider for managing app themes with smooth transitions
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';
  
  AppTheme _currentTheme = AppTheme.light;
  bool _isDarkMode = false;
  
  AppTheme get currentTheme => _currentTheme;
  bool get isDarkMode => _isDarkMode;
  
  ThemeData get themeData => _getThemeData(_currentTheme);
  
  /// Initialize theme from saved preferences
  Future<void> initializeTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme != null) {
      _currentTheme = AppTheme.values.firstWhere(
        (theme) => theme.name == savedTheme,
        orElse: () => AppTheme.light,
      );
        _isDarkMode = (_currentTheme == AppTheme.dark);
      notifyListeners();
      }
    } catch (e) {
      print('⚠️ Theme initialization failed, using default: $e');
      // Continue with default light theme
    }
  }
  
  /// Change theme and save to preferences
  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    _isDarkMode = (theme == AppTheme.dark);
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.name);
  }
  
  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    if (_isDarkMode) {
      await setTheme(AppTheme.light);
    } else {
      await setTheme(AppTheme.dark);
    }
  }
  
  /// Get theme data for specific theme
  ThemeData _getThemeData(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return _lightTheme();
      case AppTheme.dark:
        return _darkTheme();
      case AppTheme.ocean:
        return _oceanTheme();
      case AppTheme.forest:
        return _forestTheme();
      case AppTheme.sunset:
        return _sunsetTheme();
      case AppTheme.purple:
        return _purpleTheme();
    }
  }
  
  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: _createMaterialColor(const Color(AppConfig.primaryColorValue)),
      primaryColor: const Color(AppConfig.primaryColorValue),
      scaffoldBackgroundColor: const Color(AppConfig.lightBackgroundValue),
      colorScheme: const ColorScheme.light(
        primary: Color(AppConfig.primaryColorValue),
        secondary: Color(AppConfig.secondaryColorValue),
        error: Color(AppConfig.errorColorValue),
        surface: Color(AppConfig.lightSurfaceValue),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(AppConfig.lightTextPrimaryValue),
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(AppConfig.lightTextPrimaryValue),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(AppConfig.primaryColorValue)),
      ),
      cardTheme: CardThemeData(
        color: const Color(AppConfig.lightCardValue),
        elevation: 2,
        shadowColor: const Color(AppConfig.primaryColorValue).withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(AppConfig.primaryColorValue),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(AppConfig.primaryColorValue).withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Color(AppConfig.lightTextPrimaryValue), fontWeight: FontWeight.w700, fontSize: 32, letterSpacing: 0.5, height: 1.5),
        displayMedium: TextStyle(color: Color(AppConfig.lightTextPrimaryValue), fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: 0.5, height: 1.5),
        displaySmall: TextStyle(color: Color(AppConfig.lightTextPrimaryValue), fontWeight: FontWeight.w700, fontSize: 24, letterSpacing: 0.5, height: 1.5),
        headlineLarge: TextStyle(color: Color(AppConfig.lightTextPrimaryValue), fontWeight: FontWeight.w600, fontSize: 22, height: 1.5),
        headlineMedium: TextStyle(color: Color(AppConfig.lightTextPrimaryValue), fontWeight: FontWeight.w600, fontSize: 20, height: 1.5),
        headlineSmall: TextStyle(color: Color(AppConfig.lightTextPrimaryValue), fontWeight: FontWeight.w600, fontSize: 18, height: 1.5),
        bodyLarge: TextStyle(color: Color(AppConfig.lightTextPrimaryValue), fontWeight: FontWeight.w400, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(color: Color(AppConfig.lightTextPrimaryValue), fontWeight: FontWeight.w400, fontSize: 14, height: 1.5),
        bodySmall: TextStyle(color: Color(AppConfig.lightTextSecondaryValue), fontWeight: FontWeight.w400, fontSize: 12, height: 1.5),
        labelLarge: TextStyle(color: Color(AppConfig.lightTextPrimaryValue), fontWeight: FontWeight.w600, fontSize: 14, height: 1.5),
        labelMedium: TextStyle(color: Color(AppConfig.lightTextSecondaryValue), fontWeight: FontWeight.w500, fontSize: 12, height: 1.5),
        labelSmall: TextStyle(color: Color(AppConfig.lightTextSecondaryValue), fontWeight: FontWeight.w300, fontSize: 10, height: 1.5),
      ),
    );
  }
  
  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: _createMaterialColor(const Color(0xFF8B7CF6)),
      primaryColor: const Color(0xFF8B7CF6),
      scaffoldBackgroundColor: const Color(AppConfig.darkBackgroundValue),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF8B7CF6), // Brighter purple for dark mode
        secondary: Color(0xFF5FE3CF), // Brighter teal for dark mode
        error: Color(AppConfig.errorColorValue),
        surface: Color(AppConfig.darkSurfaceValue),
        onPrimary: Colors.white,
        onSecondary: Color(AppConfig.darkBackgroundValue),
        onSurface: Color(AppConfig.darkTextPrimaryValue),
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(AppConfig.darkSurfaceValue),
        foregroundColor: Color(AppConfig.darkTextPrimaryValue),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF8B7CF6)),
      ),
      cardTheme: CardThemeData(
        color: const Color(AppConfig.darkCardValue),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B7CF6),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0xFF8B7CF6).withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Color(AppConfig.darkTextPrimaryValue), fontWeight: FontWeight.w700, fontSize: 32, letterSpacing: 0.5, height: 1.5),
        displayMedium: TextStyle(color: Color(AppConfig.darkTextPrimaryValue), fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: 0.5, height: 1.5),
        displaySmall: TextStyle(color: Color(AppConfig.darkTextPrimaryValue), fontWeight: FontWeight.w700, fontSize: 24, letterSpacing: 0.5, height: 1.5),
        headlineLarge: TextStyle(color: Color(AppConfig.darkTextPrimaryValue), fontWeight: FontWeight.w600, fontSize: 22, height: 1.5),
        headlineMedium: TextStyle(color: Color(AppConfig.darkTextPrimaryValue), fontWeight: FontWeight.w600, fontSize: 20, height: 1.5),
        headlineSmall: TextStyle(color: Color(AppConfig.darkTextPrimaryValue), fontWeight: FontWeight.w600, fontSize: 18, height: 1.5),
        bodyLarge: TextStyle(color: Color(AppConfig.darkTextPrimaryValue), fontWeight: FontWeight.w400, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(color: Color(AppConfig.darkTextPrimaryValue), fontWeight: FontWeight.w400, fontSize: 14, height: 1.5),
        bodySmall: TextStyle(color: Color(AppConfig.darkTextSecondaryValue), fontWeight: FontWeight.w400, fontSize: 12, height: 1.5),
        labelLarge: TextStyle(color: Color(AppConfig.darkTextPrimaryValue), fontWeight: FontWeight.w600, fontSize: 14, height: 1.5),
        labelMedium: TextStyle(color: Color(AppConfig.darkTextSecondaryValue), fontWeight: FontWeight.w500, fontSize: 12, height: 1.5),
        labelSmall: TextStyle(color: Color(AppConfig.darkTextSecondaryValue), fontWeight: FontWeight.w300, fontSize: 10, height: 1.5),
      ),
    );
  }
  
  ThemeData _oceanTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: _createMaterialColor(const Color(0xFF0891B2)),
      primaryColor: const Color(0xFF0891B2),
      scaffoldBackgroundColor: const Color(0xFFF0F9FF),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0891B2),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0891B2),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF0F172A)),
        bodyMedium: TextStyle(color: Color(0xFF0F172A)),
        bodySmall: TextStyle(color: Color(0xFF475569)),
        titleLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
      ),
    );
  }
  
  ThemeData _forestTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: _createMaterialColor(const Color(0xFF059669)),
      primaryColor: const Color(0xFF059669),
      scaffoldBackgroundColor: const Color(0xFFF0FDF4),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF14532D)),
        bodyMedium: TextStyle(color: Color(0xFF14532D)),
        bodySmall: TextStyle(color: Color(0xFF4ADE80)),
        titleLarge: TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.w600),
      ),
    );
  }
  
  ThemeData _sunsetTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: _createMaterialColor(const Color(0xFFEA580C)),
      primaryColor: const Color(0xFFEA580C),
      scaffoldBackgroundColor: const Color(0xFFFFF7ED),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFEA580C),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEA580C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF9A3412)),
        bodyMedium: TextStyle(color: Color(0xFF9A3412)),
        bodySmall: TextStyle(color: Color(0xFFC2410C)),
        titleLarge: TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w600),
      ),
    );
  }
  
  ThemeData _purpleTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: _createMaterialColor(const Color(0xFF7C3AED)),
      primaryColor: const Color(0xFF7C3AED),
      scaffoldBackgroundColor: const Color(0xFFFAF5FF),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF581C87)),
        bodyMedium: TextStyle(color: Color(0xFF581C87)),
        bodySmall: TextStyle(color: Color(0xFF7C3AED)),
        titleLarge: TextStyle(color: Color(0xFF581C87), fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: Color(0xFF581C87), fontWeight: FontWeight.w600),
      ),
    );
  }
  
  MaterialColor _createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }
}

/// Available app themes
enum AppTheme {
  light('Light', Icons.light_mode, Color(0xFF6C63FF)),
  dark('Dark', Icons.dark_mode, Color(0xFF8B7CF6)),
  ocean('Ocean', Icons.waves, Color(0xFF0891B2)),
  forest('Forest', Icons.forest, Color(0xFF059669)),
  sunset('Sunset', Icons.wb_sunny, Color(0xFFEA580C)),
  purple('Purple', Icons.palette, Color(0xFF7C3AED));

  const AppTheme(this.displayName, this.icon, this.primaryColor);
  
  final String displayName;
  final IconData icon;
  final Color primaryColor;
} 