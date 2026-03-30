import 'package:flutter/foundation.dart';

/// Simple logger for app-wide use. No-op in release mode for debug/error.
class AppLogger {
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('[FixMo DEBUG] $message');
    }
  }

  static void warn(String message) {
    if (kDebugMode) {
      debugPrint('[FixMo WARN] $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[FixMo ERROR] $message');
      if (error != null) debugPrint(error.toString());
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
  }
}
