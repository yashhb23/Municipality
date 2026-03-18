import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../utils/app_logger.dart';

/// Service for handling location-related operations.
/// Returns a Mauritius-center fallback position when permission is denied
/// or location services are unavailable (in all build modes).
class LocationService {
  /// Whether the last location fetch used the fallback position.
  bool isUsingFallbackLocation = false;

  /// Mauritius-center fallback used when real location is unavailable.
  static Position get _fallbackPosition => Position(
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

  /// Check and request location permissions
  Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

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

  /// Get current location with timeout and error handling.
  /// Returns a fallback Mauritius-center position on any failure.
  Future<Position> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warn('Location services disabled -- using fallback position');
        isUsingFallbackLocation = true;
        return _fallbackPosition;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warn('Location permission denied -- using fallback');
          isUsingFallbackLocation = true;
          return _fallbackPosition;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.warn('Location permission permanently denied -- using fallback');
        isUsingFallbackLocation = true;
        return _fallbackPosition;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          AppLogger.warn('Location timeout -- using fallback');
          isUsingFallbackLocation = true;
          return _fallbackPosition;
        },
      );

      isUsingFallbackLocation = false;
      return position;
    } catch (e) {
      AppLogger.error('Location error -- using fallback', e);
      isUsingFallbackLocation = true;
      return _fallbackPosition;
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
      AppLogger.debug('Detecting municipality for coordinates');
      final String response = await rootBundle.loadString('assets/data/mauritius_municipalities.json');
      final Map<String, dynamic> data = json.decode(response);
      final List<dynamic> municipalities = data['municipalities'];

      AppLogger.debug('Loaded ${municipalities.length} municipalities for detection');

      for (var municipality in municipalities) {
        final boundaries = municipality['boundaries'];
        if (latitude <= boundaries['north'] &&
            latitude >= boundaries['south'] &&
            longitude <= boundaries['east'] &&
            longitude >= boundaries['west']) {
          AppLogger.debug('Found exact municipality match: ${municipality['name']}');
          return municipality['name'];
        }
      }

      String? closestMunicipality;
      double minDistance = double.infinity;
      for (var municipality in municipalities) {
        final coords = municipality['coordinates'];
        final distance = Geolocator.distanceBetween(
          latitude, longitude, coords['latitude'], coords['longitude'],
        );
        if (distance < minDistance) {
          minDistance = distance;
          closestMunicipality = municipality['name'];
        }
      }

      AppLogger.debug('Closest municipality: $closestMunicipality (${minDistance.toStringAsFixed(0)}m)');
      return closestMunicipality;
    } catch (e) {
      AppLogger.error('Error detecting municipality', e);
      if (kDebugMode) {
        AppLogger.warn('Using fallback municipality: Port Louis');
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
      AppLogger.error('Error loading municipalities', e);
      return [];
    }
  }

  /// Calculate distance between two points
  double calculateDistance(
    double startLatitude, double startLongitude,
    double endLatitude, double endLongitude,
  ) {
    return Geolocator.distanceBetween(startLatitude, startLongitude, endLatitude, endLongitude);
  }

  /// Check if coordinates are within Mauritius bounds
  bool isWithinMauritius(double latitude, double longitude) {
    const double northBound = -19.9;
    const double southBound = -20.6;
    const double eastBound = 57.8;
    const double westBound = 57.3;
    return latitude >= southBound && latitude <= northBound &&
           longitude >= westBound && longitude <= eastBound;
  }
}
