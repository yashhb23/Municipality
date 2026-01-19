import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../config/app_config.dart';
import '../providers/app_state_provider.dart';
import '../services/location_service.dart';

/// Splash screen that initializes the app and checks setup status
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _flagController;
  late Animation<double> _logoScale;
  late Animation<double> _textScale;
  late Animation<double> _flagScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _flagOpacity;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _textController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _flagController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Create scale animations with bounce effect
    _logoScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    ));

    _textScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutBack,
    ));

    _flagScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flagController,
      curve: Curves.bounceOut,
    ));

    // Create opacity animations
    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    ));

    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));

    _flagOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flagController,
      curve: Curves.easeIn,
    ));

    // Start animations in sequence
    _startAnimations();
    
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  void _startAnimations() async {
    print('🎬 Starting splash animations...');
    
    // Start logo animation
    print('🎬 Starting logo animation');
    _logoController.forward();
    
    // Wait a bit then start text animation
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      print('🎬 Starting text animation');
      _textController.forward();
    }
    
    // Wait a bit then start flag animation
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      print('🎬 Starting flag animation');
      _flagController.forward();
    }
    
    print('🎬 All animations started');
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _flagController.dispose();
    super.dispose();
  }

  /// Initialize app and check setup status
  Future<void> _initializeApp() async {
    if (!mounted) return; // Ensure widget is still mounted

    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final locationService = Provider.of<LocationService>(context, listen: false);

    try {
      appState.setLoading(true);
      appState.clearError();

      // Reduced initialization delay to see animations better
      await Future.delayed(const Duration(milliseconds: 1500));

      // Attempt location setup with timeout
      try {
        // Add timeout to location permission request
        final hasPermission = await locationService.requestLocationPermission()
            .timeout(const Duration(seconds: 10));
        
        if (mounted) {
          appState.setLocationPermission(hasPermission);
        }

        if (hasPermission) {
          try {
            // Add timeout to location fetching
            final position = await locationService.getCurrentLocation()
                .timeout(const Duration(seconds: 15));
            
            if (mounted) {
              appState.updatePosition(position);

              // Add timeout to municipality detection
              final municipality = await locationService.detectMunicipality(
                position.latitude,
                position.longitude,
              ).timeout(const Duration(seconds: 10));

              if (mounted && municipality != null) {
                appState.setMunicipality(municipality);
                print('Municipality detected: $municipality');
              } else if (mounted) {
                print('Municipality detection failed or returned null.');
                // Set a default municipality based on location
                appState.setMunicipality('Port Louis');
              }
            }
          } catch (locationError) {
            print('Failed to get current location: $locationError');
            if (mounted) {
              // Set default municipality when location fails
              appState.setMunicipality('Port Louis');
              print('Set default municipality: Port Louis');
            }
          }
        } else if (mounted) {
          print('Location permission denied, setting default municipality');
          // Set default municipality when permission denied
          appState.setMunicipality('Port Louis');
        }
      } catch (permissionError) {
        print('Location permission request failed: $permissionError');
        if (mounted) {
          appState.setLocationPermission(false);
          // Set default municipality when permission fails
          appState.setMunicipality('Port Louis');
          print('Set default municipality due to permission error');
        }
      }
      
      // Always navigate to home screen after a reasonable delay
      if (mounted) {
        appState.setLoading(false);
        // Small delay to show success state
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }

    } catch (e) {
      print('App initialization error: $e');
      if (mounted) {
        appState.setError('Failed to initialize app: $e');
        appState.setLoading(false);
        // Set default municipality even on error
        appState.setMunicipality('Port Louis');
        // Auto-retry after 3 seconds
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
      backgroundColor: const Color(AppConfig.primaryColorValue),
      body: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          return SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo Area
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo (placeholder for now)
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScale.value,
                            child: Opacity(
                              opacity: _logoOpacity.value,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_city,
                                  size: 60,
                                  color: Color(AppConfig.primaryColorValue),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // App Name
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _textScale.value,
                            child: Opacity(
                              opacity: _textOpacity.value,
                              child: Text(
                                AppConfig.appName,
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // App Subtitle
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _textScale.value,
                            child: Opacity(
                              opacity: _textOpacity.value,
                              child: Text(
                                AppConfig.appSubtitle,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white70,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Mauritius Flag Emoji
                      AnimatedBuilder(
                        animation: _flagController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _flagScale.value,
                            child: Opacity(
                              opacity: _flagOpacity.value,
                              child: const Text(
                                '🇲🇺',
                                style: TextStyle(fontSize: 32),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                // Loading/Error Area
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (appState.isLoading) ...[
                        const SpinKitThreeBounce(
                          color: Colors.white,
                          size: 30.0,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Setting up FixMo...',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ] else if (appState.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Text(
                            appState.errorMessage ?? 'Unknown error occurred',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _initializeApp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(AppConfig.primaryColorValue),
                          ),
                          child: const Text('Retry'),
                        ),
                      ] else ...[
                        // Success state - will navigate automatically
                        const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ready to go!',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Version Info
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Version ${AppConfig.appVersion}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
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