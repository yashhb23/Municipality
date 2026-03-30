import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences] for all Settings screen keys.
///
/// Call [load] once (typically in `initState`) to hydrate all fields,
/// then use the typed setters which persist immediately.
class SettingsPreferences {
  late SharedPreferences _prefs;

  // ── Keys ────────────────────────────────────────────────────────────

  static const _kLanguage = 'settings_language';
  static const _kAutoDetect = 'settings_auto_detect_location';
  static const _kShowLocation = 'settings_show_location_on_map';
  static const _kDefaultMunicipality = 'settings_default_municipality';
  static const _kReportNotifications = 'settings_report_notifications';
  static const _kCommunityUpdates = 'settings_community_updates';
  static const _kPushNotifications = 'settings_push_notifications';
  static const _kNotificationSound = 'settings_notification_sound';
  static const _kNearbyRadius = 'settings_nearby_radius';
  static const _kImageQuality = 'settings_image_quality';
  static const _kWifiOnlyImages = 'settings_wifi_only_images';
  static const _kWifiOnlySync = 'settings_wifi_only_sync';
  static const _kLargeText = 'settings_large_text';
  static const _kHighContrast = 'settings_high_contrast';
  static const _kReduceAnimations = 'settings_reduce_animations';
  static const _kScreenReaderHints = 'settings_screen_reader_hints';

  // ── Values (populated by [load]) ────────────────────────────────────

  String language = 'en';
  bool autoDetectLocation = true;
  bool showLocationOnMap = true;
  String? defaultMunicipality;
  bool reportNotifications = true;
  bool communityUpdates = true;
  bool pushNotifications = true;
  bool notificationSound = true;
  double nearbyRadius = 10;
  String imageQuality = 'high'; // high | medium | low
  bool wifiOnlyImages = false;
  bool wifiOnlySync = false;
  bool largeText = false;
  bool highContrast = false;
  bool reduceAnimations = false;
  bool screenReaderHints = false;

  // ── Lifecycle ───────────────────────────────────────────────────────

  /// Hydrate all values from disk. Call once before using any getter.
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    language = _prefs.getString(_kLanguage) ?? 'en';
    autoDetectLocation = _prefs.getBool(_kAutoDetect) ?? true;
    showLocationOnMap = _prefs.getBool(_kShowLocation) ?? true;
    defaultMunicipality = _prefs.getString(_kDefaultMunicipality);
    reportNotifications = _prefs.getBool(_kReportNotifications) ?? true;
    communityUpdates = _prefs.getBool(_kCommunityUpdates) ?? true;
    pushNotifications = _prefs.getBool(_kPushNotifications) ?? true;
    notificationSound = _prefs.getBool(_kNotificationSound) ?? true;
    nearbyRadius = _prefs.getDouble(_kNearbyRadius) ?? 10;
    imageQuality = _prefs.getString(_kImageQuality) ?? 'high';
    wifiOnlyImages = _prefs.getBool(_kWifiOnlyImages) ?? false;
    wifiOnlySync = _prefs.getBool(_kWifiOnlySync) ?? false;
    largeText = _prefs.getBool(_kLargeText) ?? false;
    highContrast = _prefs.getBool(_kHighContrast) ?? false;
    reduceAnimations = _prefs.getBool(_kReduceAnimations) ?? false;
    screenReaderHints = _prefs.getBool(_kScreenReaderHints) ?? false;
  }

  // ── Typed setters (persist immediately) ────────────────────────────

  Future<void> setLanguage(String v) async {
    language = v;
    await _prefs.setString(_kLanguage, v);
  }

  Future<void> setAutoDetectLocation(bool v) async {
    autoDetectLocation = v;
    await _prefs.setBool(_kAutoDetect, v);
  }

  Future<void> setShowLocationOnMap(bool v) async {
    showLocationOnMap = v;
    await _prefs.setBool(_kShowLocation, v);
  }

  Future<void> setDefaultMunicipality(String? v) async {
    defaultMunicipality = v;
    if (v == null) {
      await _prefs.remove(_kDefaultMunicipality);
    } else {
      await _prefs.setString(_kDefaultMunicipality, v);
    }
  }

  Future<void> setReportNotifications(bool v) async {
    reportNotifications = v;
    await _prefs.setBool(_kReportNotifications, v);
  }

  Future<void> setCommunityUpdates(bool v) async {
    communityUpdates = v;
    await _prefs.setBool(_kCommunityUpdates, v);
  }

  Future<void> setPushNotifications(bool v) async {
    pushNotifications = v;
    await _prefs.setBool(_kPushNotifications, v);
  }

  Future<void> setNotificationSound(bool v) async {
    notificationSound = v;
    await _prefs.setBool(_kNotificationSound, v);
  }

  Future<void> setNearbyRadius(double v) async {
    nearbyRadius = v;
    await _prefs.setDouble(_kNearbyRadius, v);
  }

  Future<void> setImageQuality(String v) async {
    imageQuality = v;
    await _prefs.setString(_kImageQuality, v);
  }

  Future<void> setWifiOnlyImages(bool v) async {
    wifiOnlyImages = v;
    await _prefs.setBool(_kWifiOnlyImages, v);
  }

  Future<void> setWifiOnlySync(bool v) async {
    wifiOnlySync = v;
    await _prefs.setBool(_kWifiOnlySync, v);
  }

  Future<void> setLargeText(bool v) async {
    largeText = v;
    await _prefs.setBool(_kLargeText, v);
  }

  Future<void> setHighContrast(bool v) async {
    highContrast = v;
    await _prefs.setBool(_kHighContrast, v);
  }

  Future<void> setReduceAnimations(bool v) async {
    reduceAnimations = v;
    await _prefs.setBool(_kReduceAnimations, v);
  }

  Future<void> setScreenReaderHints(bool v) async {
    screenReaderHints = v;
    await _prefs.setBool(_kScreenReaderHints, v);
  }

  /// Clears all settings keys (used by "Clear Local Data" action).
  Future<void> clearAll() async {
    final keys = [
      _kLanguage, _kAutoDetect, _kShowLocation, _kDefaultMunicipality,
      _kReportNotifications, _kCommunityUpdates, _kPushNotifications,
      _kNotificationSound, _kNearbyRadius, _kImageQuality,
      _kWifiOnlyImages, _kWifiOnlySync, _kLargeText, _kHighContrast,
      _kReduceAnimations, _kScreenReaderHints,
    ];
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
