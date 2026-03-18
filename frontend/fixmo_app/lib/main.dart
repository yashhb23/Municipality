import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'config/app_config.dart';
import 'utils/app_logger.dart';
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
      AppLogger.warn('Screen orientation lock failed: $e');
    }
  
    // Initialize Supabase with error handling (optional - don't block app start)
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      ).timeout(const Duration(seconds: 10));
      AppLogger.debug('Supabase initialized');
  } catch (e) {
      AppLogger.warn('Supabase initialization error: $e');
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
      AppLogger.warn('System UI style failed: $e');
    }
  
    // Preload critical assets (optional - don't block app start)
    try {
      await _preloadAssets().timeout(const Duration(seconds: 5));
    } catch (e) {
      AppLogger.warn('Asset preloading failed: $e');
    }
  
    // Initialize reports service with sample data (optional)
    try {
      await ReportsService().initializeSampleData().timeout(const Duration(seconds: 3));
    } catch (e) {
      AppLogger.warn('Sample data initialization failed: $e');
    }
    
    // Initialize theme provider BEFORE creating app (CRITICAL FIX)
    final themeProvider = ThemeProvider();
    try {
      await themeProvider.initializeTheme().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          AppLogger.warn('Theme initialization timeout, using default dark theme');
        },
      );
    } catch (e) {
      AppLogger.warn('Theme initialization error: $e');
    }
    
    AppLogger.debug('Starting FixMo app...');
    runApp(FixMoApp(themeProvider: themeProvider));
    
  } catch (e, stackTrace) {
    AppLogger.error('CRITICAL ERROR in main()', e, stackTrace);
    
    // Try to start app anyway with minimal initialization
    try {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(FixMoApp(themeProvider: ThemeProvider()));
    } catch (finalError) {
      AppLogger.error('FATAL: Cannot start app', finalError);
    }
  }
}

/// Preload critical assets to ensure they're available when needed
Future<void> _preloadAssets() async {
  try {
    AppLogger.debug('Preloading critical assets...');
    final municipalitiesData = await rootBundle.loadString('assets/data/mauritius_municipalities.json');
    final json = jsonDecode(municipalitiesData);
    AppLogger.debug('Preloaded municipalities: ${json['municipalities']?.length ?? 0}');
  } catch (e) {
    AppLogger.warn('Asset preloading failed: $e');
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
            theme: themeProvider.themeData.copyWith(
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                },
              ),
            ),
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
