import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../models/report_model.dart';
import '../utils/app_logger.dart';

/// Service for managing civic reports data
class ReportsService {
  static final ReportsService _instance = ReportsService._internal();
  factory ReportsService() => _instance;
  ReportsService._internal();

  final List<ReportModel> _reports = [];
  final StreamController<List<ReportModel>> _reportsController = StreamController<List<ReportModel>>.broadcast();

  /// Stream of reports
  Stream<List<ReportModel>> get reportsStream => _reportsController.stream;

  /// Get all reports
  List<ReportModel> get allReports => _reports;

  /// Initialize with sample data
  Future<void> initializeSampleData() async {
    if (_reports.isNotEmpty) return; // Already initialized

    AppLogger.debug('Initializing sample reports data...');

    // Sample report data with various municipalities in Mauritius
    final sampleReports = [
      // Goodlands reports
      {
        'id': 'rpt_001',
        'title': 'Pothole on Arsenal Road',
        'description': 'Large pothole causing traffic issues near the bus stop. Water accumulates during rain.',
        'category': 'Infrastructure',
        'subcategory': 'Road Damage',
        'status': 'pending',
        'latitude': -20.0420,
        'longitude': 57.6045,
        'municipality': 'Goodlands',
        'address': 'Arsenal Road, Goodlands',
        'reporterName': 'Raj Patel',
        'isCurrentUser': true, // This is the user's own report
        'priority': 3,
        'imageUrls': [
          'https://images.unsplash.com/photo-1581833971358-2c8b550f87b3?w=400&h=300&fit=crop',
        ],
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)),
      },
      {
        'id': 'rpt_002', 
        'title': 'Broken Street Light',
        'description': 'Street light not working for the past week. Area becomes very dark at night.',
        'category': 'Utilities',
        'subcategory': 'Street Lighting',
        'status': 'in_progress',
        'latitude': -20.0450,
        'longitude': 57.6020,
        'municipality': 'Goodlands',
        'address': 'Main Street, Goodlands',
        'reporterName': 'Priya Sharma',
        'isCurrentUser': false,
        'priority': 2,
        'imageUrls': [
          'https://images.unsplash.com/photo-1558618047-3c8c76ca7c09?w=400&h=300&fit=crop',
        ],
        'createdAt': DateTime.now().subtract(const Duration(days: 1)),
      },
      {
        'id': 'rpt_003',
        'title': 'Garbage Collection Issue',
        'description': 'Garbage not collected for 3 days. Bins overflowing and attracting insects.',
        'category': 'Sanitation',
        'subcategory': 'Waste Collection',
        'status': 'pending',
        'latitude': -20.0380,
        'longitude': 57.6080,
        'municipality': 'Goodlands',
        'address': 'Calodyne Road, Goodlands',
        'reporterName': 'Ahmed Hassan',
        'isCurrentUser': false,
        'priority': 2,
        'imageUrls': [
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
        ],
        'createdAt': DateTime.now().subtract(const Duration(hours: 6)),
      },

      // Port Louis reports
      {
        'id': 'rpt_004',
        'title': 'Water Pipe Burst',
        'description': 'Major water pipe burst flooding the street. Urgent repair needed.',
        'category': 'Utilities',
        'subcategory': 'Water Supply',
        'status': 'in_progress',
        'latitude': -20.1620,
        'longitude': 57.5080,
        'municipality': 'Port Louis',
        'address': 'Royal Street, Port Louis',
        'reporterName': 'Marie Dubois',
        'isCurrentUser': false,
        'priority': 3,
        'imageUrls': [
          'https://images.unsplash.com/photo-1581833971358-2c8b550f87b3?w=400&h=300&fit=crop',
        ],
        'createdAt': DateTime.now().subtract(const Duration(hours: 4)),
      },
      {
        'id': 'rpt_005',
        'title': 'Bus Stop Damage',
        'description': 'Bus stop shelter damaged by strong winds. Glass panels broken.',
        'category': 'Transport',
        'subcategory': 'Public Transport',
        'status': 'resolved',
        'latitude': -20.1580,
        'longitude': 57.5020,
        'municipality': 'Port Louis',
        'address': 'Immigration Square, Port Louis',
        'reporterName': 'David Chen',
        'isCurrentUser': false,
        'priority': 1,
        'imageUrls': [
          'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=400&h=300&fit=crop',
        ],
        'createdAt': DateTime.now().subtract(const Duration(days: 3)),
      },

      // Quatre Bornes reports
      {
        'id': 'rpt_006',
        'title': 'Park Maintenance Needed',
        'description': 'Playground equipment needs repair. Some swings are broken and unsafe.',
        'category': 'Environment',
        'subcategory': 'Parks & Recreation',
        'status': 'pending',
        'latitude': -20.2650,
        'longitude': 57.4800,
        'municipality': 'Quatre Bornes',
        'address': 'Municipal Park, Quatre Bornes',
        'reporterName': 'Anita Ramesh',
        'isCurrentUser': false,
        'priority': 2,
        'imageUrls': [
          'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=400&h=300&fit=crop',
        ],
        'createdAt': DateTime.now().subtract(const Duration(hours: 8)),
      },

      // Curepipe reports
      {
        'id': 'rpt_007',
        'title': 'Drain Blockage',
        'description': 'Storm drain blocked causing flooding during rain. Needs immediate attention.',
        'category': 'Infrastructure',
        'subcategory': 'Drainage',
        'status': 'in_progress',
        'latitude': -20.3180,
        'longitude': 57.5180,
        'municipality': 'Curepipe',
        'address': 'Royal Road, Curepipe',
        'reporterName': 'Sunita Jowaheer',
        'isCurrentUser': false,
        'priority': 3,
        'imageUrls': [
          'https://images.unsplash.com/photo-1574180566232-aaad1b5b8450?w=400&h=300&fit=crop',
        ],
        'createdAt': DateTime.now().subtract(const Duration(hours: 12)),
      },

      // Mahébourg reports
      {
        'id': 'rpt_008',
        'title': 'Beach Cleanup Required',
        'description': 'Plastic waste accumulating on the beach. Environmental concern for marine life.',
        'category': 'Environment',
        'subcategory': 'Waste Management',
        'status': 'pending',
        'latitude': -20.4080,
        'longitude': 57.7020,
        'municipality': 'Mahébourg',
        'address': 'Blue Bay Beach, Mahébourg',
        'reporterName': 'Ocean Lover',
        'isCurrentUser': false,
        'priority': 2,
        'imageUrls': [
          'https://images.unsplash.com/photo-1583212292454-1fe6229603b7?w=400&h=300&fit=crop',
        ],
        'createdAt': DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      },
    ];

    // Convert sample data to ReportModel objects
    for (final reportData in sampleReports) {
      final report = ReportModel(
        id: reportData['id'] as String,
        title: reportData['title'] as String,
        description: reportData['description'] as String,
        category: reportData['category'] as String,
        subcategory: reportData['subcategory'] as String,
        status: reportData['status'] as String,
        createdAt: reportData['createdAt'] as DateTime,
        location: Position(
          latitude: reportData['latitude'] as double,
          longitude: reportData['longitude'] as double,
          timestamp: DateTime.now(),
          accuracy: 1.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
        municipality: reportData['municipality'] as String,
        address: reportData['address'] as String,
        reporterName: reportData['reporterName'] as String,
        isCurrentUser: reportData['isCurrentUser'] as bool,
        priority: reportData['priority'] as int,
        imageUrls: List<String>.from(reportData['imageUrls'] as List),
      );
      
      _reports.add(report);
    }

    AppLogger.debug('Loaded ${_reports.length} sample reports');
    _reportsController.add(_reports);
  }

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
    AppLogger.debug('Added new report: ${report.title}');
  }

  /// Update an existing report
  Future<void> updateReport(ReportModel updatedReport) async {
    final index = _reports.indexWhere((report) => report.id == updatedReport.id);
    if (index != -1) {
      _reports[index] = updatedReport;
      _reportsController.add(_reports);
      AppLogger.debug('Updated report: ${updatedReport.title}');
    }
  }

  /// Delete a report
  Future<void> deleteReport(String reportId) async {
    _reports.removeWhere((report) => report.id == reportId);
    _reportsController.add(_reports);
    AppLogger.debug('Deleted report: $reportId');
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
    AppLogger.debug('Refreshing reports...');
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    _reportsController.add(_reports);
  }

  /// Dispose resources
  void dispose() {
    _reportsController.close();
  }
} 