/// FixMo Application Configuration
/// Contains all API keys, URLs, and app constants
class AppConfig {
  // Supabase Configuration
  static const String supabaseUrl = 'https://iexhralidwrmfrggxtrh.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlleHhyYWxpZHdybWZyZ2d4dHJoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY4NTk5MTYsImV4cCI6MjA2MjQzNTkxNn0.ira3b5nui4LDhbKRsQ4iRgQKQm7hKXB-CmqFPVSdPaI';
  
  // Network Configuration
  static const Duration uploadTimeout = Duration(seconds: 30);
  static const Duration queryTimeout = Duration(seconds: 10);
  static const int maxRetryAttempts = 3;
  static const int retryDelaySeconds = 2; // Base delay for exponential backoff
  
  // Google Maps Configuration
  static const String googleMapsApiKey = 'AIzaSyCNdvXwGAHaNdTsMcSeSlNy9cTB7YlrWP4';
  
  // App Information
  static const String appName = 'FixMo';
  static const String appSubtitle = 'Civic Reporting for Mauritius';
  static const String appVersion = '1.0.1';
  static const String appOrganization = 'com.fixmo.mauritius';
  
  // Default Location (Mauritius Center)
  static const double mauritiusLatitude = -20.348404;
  static const double mauritiusLongitude = 57.552152;
  
  // Report Categories
  static const List<String> reportCategories = [
    'Potholes',
    'Broken Street Lights',
    'Garbage/Waste',
    'Drainage Issues',
    'Road Damage',
    'Graffiti',
    'Broken Infrastructure',
    'Other'
  ];
  
  // Supported Languages
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'mfe', 'name': 'Kreol Morisien', 'flag': '🇲🇺'},
  ];
  
  // Maximum file sizes
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int maxReportDescriptionLength = 500;
  
  // Modern App Colors - Elderly-friendly with good contrast
  static const int primaryColorValue = 0xFF6C63FF;    // Primary Purple
  static const int secondaryColorValue = 0xFF4ECDC4;  // Teal
  static const int accentColorValue = 0xFFFF6B6B;     // Coral Red
  
  // Semantic Colors for Modern UI (WCAG AAA compliant)
  static const int successColorValue = 0xFF10B981;    // Green
  static const int warningColorValue = 0xFFF59E0B;    // Amber
  static const int errorColorValue = 0xFFEF4444;      // Red
  static const int infoColorValue = 0xFF3B82F6;       // Blue
  
  // Dark Mode Colors
  static const int darkBackgroundValue = 0xFF1A1A2E;  // Dark Navy
  static const int darkSurfaceValue = 0xFF16213E;     // Slightly lighter
  static const int darkCardValue = 0xFF0F1424;        // Card background
  
  // Light Mode Colors
  static const int lightBackgroundValue = 0xFFF8FAFC; // Off-white
  static const int lightSurfaceValue = 0xFFFFFFFF;    // Pure white
  static const int lightCardValue = 0xFFFFFFFF;       // White cards
  
  // Text Colors
  static const int darkTextPrimaryValue = 0xFFE2E8F0;   // Light gray for dark mode
  static const int darkTextSecondaryValue = 0xFF94A3B8; // Muted for dark mode
  static const int lightTextPrimaryValue = 0xFF1E293B;  // Dark gray for light mode
  static const int lightTextSecondaryValue = 0xFF64748B;// Muted for light mode
  
  // Environment check
  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');
  static bool get isDevelopment => !isProduction;
} 