import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/report_model.dart';
import '../utils/app_logger.dart';

/// Service for managing civic reports data.
///
/// In-memory cache of reports. Real data should be fetched
/// from the backend API via [BackendApiService].
class ReportsService {
  static final ReportsService _instance = ReportsService._internal();
  factory ReportsService() => _instance;
  ReportsService._internal();

  final List<ReportModel> _reports = [];
  final StreamController<List<ReportModel>> _reportsController =
      StreamController<List<ReportModel>>.broadcast();

  Stream<List<ReportModel>> get reportsStream => _reportsController.stream;
  List<ReportModel> get allReports => _reports;

  /// Get reports for a specific municipality
  List<ReportModel> getReportsForMunicipality(String municipality) {
    return _reports.where((report) => 
      report.municipality.toLowerCase() == municipality.toLowerCase()
    ).toList();
  }

  /// Get reports within a radius of a location
  List<ReportModel> getReportsNearLocation(Position center, double radiusKm) {
    return _reports.where((report) {
      final distance = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        report.location.latitude,
        report.location.longitude,
      ) / 1000; // Convert to kilometers
      
      return distance <= radiusKm;
    }).toList();
  }

  /// Get user's own reports
  List<ReportModel> getUserReports() {
    return _reports.where((report) => report.isCurrentUser).toList();
  }

  /// Add a new report
  Future<void> addReport(ReportModel report) async {
    _reports.insert(0, report); // Add to beginning for newest first
    _reportsController.add(_reports);
    debugPrint('📝 Added new report: ${report.title}');
  }

  /// Update an existing report
  Future<void> updateReport(ReportModel updatedReport) async {
    final index = _reports.indexWhere((report) => report.id == updatedReport.id);
    if (index != -1) {
      _reports[index] = updatedReport;
      _reportsController.add(_reports);
      debugPrint('📝 Updated report: ${updatedReport.title}');
    }
  }

  /// Delete a report
  Future<void> deleteReport(String reportId) async {
    _reports.removeWhere((report) => report.id == reportId);
    _reportsController.add(_reports);
    debugPrint('🗑️ Deleted report: $reportId');
  }

  /// Get report by ID
  ReportModel? getReportById(String id) {
    try {
      return _reports.firstWhere((report) => report.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get reports by status
  List<ReportModel> getReportsByStatus(String status) {
    return _reports.where((report) => 
      report.status.toLowerCase() == status.toLowerCase()
    ).toList();
  }

  /// Get reports by category
  List<ReportModel> getReportsByCategory(String category) {
    return _reports.where((report) => 
      report.category.toLowerCase() == category.toLowerCase()
    ).toList();
  }

  /// Refresh reports (simulate API call)
  Future<void> refreshReports() async {
    debugPrint('🔄 Refreshing reports...');
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    _reportsController.add(_reports);
  }

  /// Dispose resources
  void dispose() {
    _reportsController.close();
  }
} 