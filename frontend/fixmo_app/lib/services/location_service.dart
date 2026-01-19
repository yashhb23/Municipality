import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Service for handling location-related operations
class LocationService {
  
  /// Check and request location permissions
  Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable location services.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied, we cannot request permissions.');
    }

    return true;
  }

  /// Get current location with timeout and error handling
  Future<Position> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // For testing on virtual devices, return mock location
        if (kDebugMode) {
          print('Location services disabled - using mock location for testing');
          return Position(
            latitude: AppConfig.mauritiusLatitude,
            longitude: AppConfig.mauritiusLongitude,
            timestamp: DateTime.now(),
            accuracy: 100.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        }
        throw LocationServiceDisabledException();
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // For testing, return mock location
          if (kDebugMode) {
            print('Location permission denied - using mock location for testing');
            return Position(
              latitude: AppConfig.mauritiusLatitude,
              longitude: AppConfig.mauritiusLongitude,
              timestamp: DateTime.now(),
              accuracy: 100.0,
              altitude: 0.0,
              heading: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
              altitudeAccuracy: 0.0,
              headingAccuracy: 0.0,
            );
          }
          throw PermissionDeniedException('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // For testing, return mock location
        if (kDebugMode) {
          print('Location permission denied forever - using mock location for testing');
          return Position(
            latitude: AppConfig.mauritiusLatitude,
            longitude: AppConfig.mauritiusLongitude,
            timestamp: DateTime.now(),
            accuracy: 100.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        }
        throw PermissionDeniedException('Location permissions are permanently denied, we cannot request permissions.');
      }

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          // Return mock location for testing if timeout
          if (kDebugMode) {
            print('Location timeout - using mock location for testing');
            return Position(
              latitude: AppConfig.mauritiusLatitude,
              longitude: AppConfig.mauritiusLongitude,
              timestamp: DateTime.now(),
              accuracy: 100.0,
              altitude: 0.0,
              heading: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
              altitudeAccuracy: 0.0,
              headingAccuracy: 0.0,
            );
          }
          throw TimeoutException('Location request timed out', const Duration(seconds: 20));
        },
      );

      return position;
    } catch (e) {
      // For any error in debug mode, return mock location
      if (kDebugMode) {
        print('Location error: $e - using mock location for testing');
        return Position(
          latitude: AppConfig.mauritiusLatitude,
          longitude: AppConfig.mauritiusLongitude,
          timestamp: DateTime.now(),
          accuracy: 100.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
      }
      rethrow;
    }
  }

  /// Convert coordinates to address using geocoding
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.country}';
      }
      
      return 'Unknown location';
    } catch (e) {
      return 'Unable to get address';
    }
  }

  /// Detect municipality based on coordinates using local data
  Future<String?> detectMunicipality(double latitude, double longitude) async {
    try {
      print('🌍 Detecting municipality for coordinates: $latitude, $longitude');
      
      // Load municipalities data from assets
      final String response = await rootBundle.loadString('assets/data/mauritius_municipalities.json');
      final Map<String, dynamic> data = json.decode(response);
      final List<dynamic> municipalities = data['municipalities'];
      
      print('📍 Loaded ${municipalities.length} municipalities for detection');
      
      // Find municipality by checking boundaries
      for (var municipality in municipalities) {
        final boundaries = municipality['boundaries'];
        
        if (latitude <= boundaries['north'] &&
            latitude >= boundaries['south'] &&
            longitude <= boundaries['east'] &&
            longitude >= boundaries['west']) {
          print('✅ Found exact municipality match: ${municipality['name']}');
          return municipality['name'];
        }
      }
      
      // If no exact boundary match, find closest municipality
      String? closestMunicipality;
      double minDistance = double.infinity;
      
      for (var municipality in municipalities) {
        final coords = municipality['coordinates'];
        final distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          coords['latitude'],
          coords['longitude'],
        );
        
        if (distance < minDistance) {
          minDistance = distance;
          closestMunicipality = municipality['name'];
        }
      }
      
      print('📍 Closest municipality: $closestMunicipality (distance: ${minDistance.toStringAsFixed(2)}m)');
      return closestMunicipality;
    } catch (e) {
      print('❌ Error detecting municipality: $e');
      // Fallback to default municipality for testing
      if (kDebugMode) {
        print('⚠️ Using fallback municipality: Port Louis');
        return 'Port Louis';
      }
      return null;
    }
  }

  /// Get list of all municipalities
  Future<List<Map<String, dynamic>>> getAllMunicipalities() async {
    try {
      final String response = await rootBundle.loadString('assets/data/mauritius_municipalities.json');
      final Map<String, dynamic> data = json.decode(response);
      return List<Map<String, dynamic>>.from(data['municipalities']);
    } catch (e) {
      print('Error loading municipalities: $e');
      return [];
    }
  }

  /// Calculate distance between two points
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Check if coordinates are within Mauritius bounds
  bool isWithinMauritius(double latitude, double longitude) {
    // Mauritius approximate bounds
    const double northBound = -19.9;
    const double southBound = -20.6;
    const double eastBound = 57.8;
    const double westBound = 57.3;
    
    return latitude >= southBound &&
           latitude <= northBound &&
           longitude >= westBound &&
           longitude <= eastBound;
  }
} 