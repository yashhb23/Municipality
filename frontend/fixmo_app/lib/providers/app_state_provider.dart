import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Global app state provider managing current location, municipality, and user preferences
class AppStateProvider extends ChangeNotifier {
  Position? _currentPosition;
  String? _selectedMunicipality;
  String _selectedLanguage = 'en';
  bool _isLocationPermissionGranted = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  Position? get currentPosition => _currentPosition;
  String? get selectedMunicipality => _selectedMunicipality;
  String get selectedLanguage => _selectedLanguage;
  bool get isLocationPermissionGranted => _isLocationPermissionGranted;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  /// Update current position
  void updatePosition(Position position) {
    _currentPosition = position;
    notifyListeners();
  }
  
  /// Set selected municipality
  void setMunicipality(String municipality) {
    _selectedMunicipality = municipality;
    notifyListeners();
  }
  
  /// Change app language
  void setLanguage(String languageCode) {
    _selectedLanguage = languageCode;
    notifyListeners();
  }
  
  /// Update location permission status
  void setLocationPermission(bool granted) {
    _isLocationPermissionGranted = granted;
    notifyListeners();
  }
  
  /// Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  /// Set error message
  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }
  
  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Check if user has selected municipality and granted location permission
  bool get isSetupComplete {
    return _isLocationPermissionGranted && _selectedMunicipality != null;
  }
} 