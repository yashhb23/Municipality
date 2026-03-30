import 'package:flutter/material.dart';

/// Quick report entry point. Shows a modal that navigates to the full report screen.
class QuickReportModal {
  /// Opens the quick report flow. Pushes to ReportScreen.
  static void show(BuildContext context) {
    Navigator.of(context).pushNamed('/report');
  }
}
