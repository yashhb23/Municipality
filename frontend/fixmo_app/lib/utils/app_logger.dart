import 'package:flutter/foundation.dart';

/// Release-safe logger. All output is suppressed in release builds.
/// In debug builds, messages are prefixed with [FixMo] for easy filtering.
class AppLogger {
  AppLogger._();

  /// General debug message -- only printed in debug builds.
  static void debug(String message) {
    if (kDebugMode) debugPrint('[FixMo] $message');
  }

  /// Error with optional exception and stack trace -- only printed in debug builds.
  /// In production, this is where you would send to Sentry / Crashlytics.
  static void error(String message, [Object? error, StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('[FixMo ERROR] $message');
      if (error != null) debugPrint('  Exception: $error');
      if (stack != null) debugPrint('  Stack: $stack');
    }
  }

  /// Warning -- non-fatal issues worth noting in debug.
  static void warn(String message) {
    if (kDebugMode) debugPrint('[FixMo WARN] $message');
  }
}
