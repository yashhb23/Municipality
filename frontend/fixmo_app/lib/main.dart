import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

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
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/reports_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Crash immediately if required build-time secrets are missing.
  // This catches misconfigured CI/CD or missing --dart-define flags
  // before the app reaches a confusing runtime state.
  AppConfig.validate();

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('Screen orientation lock failed: $e');
  }

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    ).timeout(const Duration(seconds: 10));
    debugPrint('Supabase initialized');
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  } catch (e) {
    debugPrint('System UI style failed: $e');
  }

  try {
    await _preloadAssets().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Asset preloading failed: $e');
  }

  // Initialize auth — signs in anonymously if no session exists
  final authProvider = AuthProvider();
  try {
    await authProvider.initialize().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Auth initialization error: $e');
  }

  final themeProvider = ThemeProvider();
  try {
    await themeProvider.initializeTheme().timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        debugPrint('Theme initialization timeout, using default light theme');
      },
    );
  } catch (e) {
    debugPrint('Theme initialization error: $e');
  }

  debugPrint('Starting FixMo app...');
  runApp(FixMoApp(themeProvider: themeProvider, authProvider: authProvider));
}

Future<void> _preloadAssets() async {
  final municipalitiesData = await rootBundle.loadString('assets/data/mauritius_municipalities.json');
  final json = jsonDecode(municipalitiesData);
  debugPrint('Preloaded municipalities: ${json['municipalities']?.length ?? 0}');
}

class FixMoApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final AuthProvider authProvider;

  const FixMoApp({
    super.key,
    required this.themeProvider,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),
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
