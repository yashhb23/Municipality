import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'config/app_config.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'services/location_service.dart';
import 'services/supabase_service.dart';
import 'providers/app_state_provider.dart';
import 'providers/theme_provider.dart';
import 'services/reports_service.dart';

void main() async {
  // Wrap entire initialization in try-catch to prevent crashes
  try {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock app to portrait mode only
    try {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
    } catch (e) {
      print('⚠️ Screen orientation lock failed: $e');
      // Continue without orientation lock
    }
  
    // Initialize Supabase with error handling (optional - don't block app start)
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      ).timeout(const Duration(seconds: 10));
      print('✅ Supabase initialized successfully');
  } catch (e) {
      print('⚠️ Supabase initialization error: $e');
      print('📱 App will continue without Supabase connectivity');
      // Continue without Supabase - app should work offline
  }
  
  // Set system UI overlay style
    try {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
    } catch (e) {
      print('⚠️ System UI style failed: $e');
    }
  
    // Preload critical assets (optional - don't block app start)
    try {
      await _preloadAssets().timeout(const Duration(seconds: 5));
    } catch (e) {
      print('⚠️ Asset preloading failed: $e');
      // Continue without preloaded assets - they'll load on demand
    }
  
    // Initialize reports service with sample data (optional)
    try {
      await ReportsService().initializeSampleData().timeout(const Duration(seconds: 3));
    } catch (e) {
      print('⚠️ Sample data initialization failed: $e');
      // Continue without sample data
    }
    
    // Initialize theme provider BEFORE creating app (CRITICAL FIX)
    final themeProvider = ThemeProvider();
    try {
      await themeProvider.initializeTheme().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print('⚠️ Theme initialization timeout, using default light theme');
        },
      );
    } catch (e) {
      print('⚠️ Theme initialization error: $e');
      // Continue with default theme
    }
    
    print('🚀 Starting FixMo app...');
    runApp(FixMoApp(themeProvider: themeProvider));
    
  } catch (e, stackTrace) {
    // Critical error - log and try to start with minimal app
    print('❌ CRITICAL ERROR in main(): $e');
    print('Stack trace: $stackTrace');
    
    // Try to start app anyway with minimal initialization
    try {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(FixMoApp(themeProvider: ThemeProvider()));
    } catch (finalError) {
      print('❌ FATAL: Cannot start app: $finalError');
      // App will crash here, but at least we logged the error
    }
  }
}

/// Preload critical assets to ensure they're available when needed
Future<void> _preloadAssets() async {
  try {
    print('📦 Preloading critical assets...');
    
    // Preload municipalities data
    final municipalitiesData = await rootBundle.loadString('assets/data/mauritius_municipalities.json');
    final json = jsonDecode(municipalitiesData);
    print('📦 Preloaded municipalities: ${json['municipalities']?.length ?? 0}');
    
    print('📦 Asset preloading completed successfully');
  } catch (e) {
    print('⚠️ Asset preloading failed: $e');
    // Continue anyway - app will handle missing assets gracefully
  }
}

class FixMoApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  
  const FixMoApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider.value(value: themeProvider), // Use .value to pass pre-initialized provider
        Provider(create: (_) => LocationService()),
        Provider(create: (_) => SupabaseService()),
        Provider<ReportsService>(create: (_) => ReportsService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            initialRoute: '/splash',
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/home': (context) => const HomeScreen(),
              '/report': (context) => const ReportScreen(),
              '/history': (context) => const HistoryScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}
