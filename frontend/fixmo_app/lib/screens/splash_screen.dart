import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/app_state_provider.dart';
import '../services/location_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;

  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;

  late Animation<double> _subtitleOpacity;

  late Animation<double> _loaderOpacity;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // 0.00 – 0.30 : logo fades in + slides up 24px
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.30, curve: Curves.easeOut)),
    );
    _logoSlide = Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.30, curve: Curves.easeOutCubic)),
    );

    // 0.15 – 0.50 : title text fades in + slides up 16px
    _titleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.50, curve: Curves.easeOut)),
    );
    _titleSlide = Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.50, curve: Curves.easeOutCubic)),
    );

    // 0.35 – 0.60 : subtitle fades in
    _subtitleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.35, 0.60, curve: Curves.easeOut)),
    );

    // 0.55 – 0.75 : loading indicator fades in
    _loaderOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.55, 0.75, curve: Curves.easeOut)),
    );

    _ctrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final locationService = Provider.of<LocationService>(context, listen: false);

    try {
      appState.setLoading(true);
      appState.clearError();

      await Future.delayed(const Duration(milliseconds: 1800));

      try {
        final hasPermission = await locationService
            .requestLocationPermission()
            .timeout(const Duration(seconds: 10));

        if (mounted) appState.setLocationPermission(hasPermission);

        if (hasPermission) {
          try {
            final position = await locationService
                .getCurrentLocation()
                .timeout(const Duration(seconds: 15));

            if (mounted) {
              appState.updatePosition(position);

              final municipality = await locationService
                  .detectMunicipality(position.latitude, position.longitude)
                  .timeout(const Duration(seconds: 10));

              if (mounted) {
                appState.setMunicipality(municipality ?? 'Port Louis');
              }
            }
          } catch (locationError) {
            debugPrint('Failed to get current location: $locationError');
            if (mounted) appState.setMunicipality('Port Louis');
          }
        } else if (mounted) {
          appState.setMunicipality('Port Louis');
        }
      } catch (permissionError) {
        debugPrint('Location permission request failed: $permissionError');
        if (mounted) {
          appState.setLocationPermission(false);
          appState.setMunicipality('Port Louis');
        }
      }

      if (mounted) {
        appState.setLoading(false);
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) _navigateToHome();
      }
    } catch (e) {
      debugPrint('App initialization error: $e');
      if (mounted) {
        appState.setError('Failed to initialize app: $e');
        appState.setLoading(false);
        appState.setMunicipality('Port Louis');
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _navigateToHome();
        });
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: const RouteSettings(name: '/home'),
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(AppConfig.primaryColorValue);

    return Scaffold(
      backgroundColor: primary,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo ──────────────────────────────────────────
                SlideTransition(
                  position: _logoSlide,
                  child: Opacity(
                    opacity: _logoOpacity.value,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.location_city_rounded,
                        size: 48,
                        color: primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── App Name ──────────────────────────────────────
                SlideTransition(
                  position: _titleSlide,
                  child: Opacity(
                    opacity: _titleOpacity.value,
                    child: Text(
                      AppConfig.appName,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.2,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Subtitle ──────────────────────────────────────
                Opacity(
                  opacity: _subtitleOpacity.value,
                  child: Text(
                    AppConfig.appSubtitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // ── Loader ────────────────────────────────────────
                Opacity(
                  opacity: _loaderOpacity.value,
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
