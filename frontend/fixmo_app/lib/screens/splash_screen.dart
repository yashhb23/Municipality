import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../config/app_config.dart';
import '../providers/app_state_provider.dart';
import '../services/location_service.dart';
import '../utils/app_logger.dart';

/// Splash screen: solid dark background, minimal fade-in, green accent.
/// Keeps full initialization logic unchanged.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeOpacity;

  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _primary = Color(0xFF00D9A3);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Initialize app and check setup status (unchanged from original).
  Future<void> _initializeApp() async {
    if (!mounted) return;

    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final locationService = Provider.of<LocationService>(context, listen: false);

    try {
      appState.setLoading(true);
      appState.clearError();

      await Future.delayed(const Duration(milliseconds: 1500));

      try {
        final hasPermission = await locationService.requestLocationPermission()
            .timeout(const Duration(seconds: 10));

        if (mounted) {
          appState.setLocationPermission(hasPermission);
        }

        if (hasPermission) {
          try {
            final position = await locationService.getCurrentLocation()
                .timeout(const Duration(seconds: 15));

            if (mounted) {
              appState.updatePosition(position);

              final municipality = await locationService.detectMunicipality(
                position.latitude,
                position.longitude,
              ).timeout(const Duration(seconds: 10));

              if (mounted && municipality != null) {
                appState.setMunicipality(municipality);
                AppLogger.debug('Municipality detected: $municipality');
              } else if (mounted) {
                AppLogger.warn('Municipality detection returned null');
                appState.setMunicipality('Port Louis');
              }
            }
          } catch (locationError) {
            AppLogger.error('Failed to get current location', locationError);
            if (mounted) {
              appState.setMunicipality('Port Louis');
              AppLogger.debug('Set default municipality: Port Louis');
            }
          }
        } else if (mounted) {
          AppLogger.warn('Location permission denied, setting default municipality');
          appState.setMunicipality('Port Louis');
        }
      } catch (permissionError) {
        AppLogger.error('Location permission request failed', permissionError);
        if (mounted) {
          appState.setLocationPermission(false);
          appState.setMunicipality('Port Louis');
          AppLogger.debug('Set default municipality due to permission error');
        }
      }

      if (mounted) {
        appState.setLoading(false);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      AppLogger.error('App initialization error', e);
      if (mounted) {
        appState.setError('Failed to initialize app: $e');
        appState.setLoading(false);
        appState.setMunicipality('Port Louis');
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          return SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _fadeController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeOpacity.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // FixMo: white text + green accent dot
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    AppConfig.appName,
                                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                      color: Colors.white,
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: _primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppConfig.appSubtitle,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (appState.isLoading) ...[
                        SpinKitThreeBounce(color: _primary, size: 30.0),
                        const SizedBox(height: 16),
                        Text(
                          'Setting up...',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ] else if (appState.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.4)),
                          ),
                          child: Text(
                            appState.errorMessage ?? 'Unknown error occurred',
                            style: TextStyle(color: Colors.red.shade300, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _initializeApp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.black87,
                          ),
                          child: const Text('Retry'),
                        ),
                      ] else ...[
                        Icon(Icons.check_circle_outline, color: _primary, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Ready to go!',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Version ${AppConfig.appVersion}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
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
