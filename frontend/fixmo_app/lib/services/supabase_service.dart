import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/report_model.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';

/// Service for handling Supabase database and storage operations
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  SupabaseClient get client => _client;

  /// Check if device has internet connection and Supabase is reachable
  Future<bool> hasInternetConnection() async {
    try {
      await _client
          .from('municipalities')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 3));
      AppLogger.debug('Supabase connection verified');
      return true;
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('socketexception') ||
          errorMessage.contains('failed host lookup')) {
        AppLogger.warn('DNS error: cannot resolve Supabase host');
      } else if (errorMessage.contains('timeout')) {
        AppLogger.warn('Supabase not responding within 3s');
      } else if (errorMessage.contains('auth') || errorMessage.contains('jwt')) {
        AppLogger.warn('Auth error: API key may be incorrect');
      } else {
        AppLogger.warn('Connection check warning: $e');
      }
      return true;
    }
  }

  /// Execute operation with retry logic and exponential backoff
  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxAttempts = AppConfig.maxRetryAttempts,
  }) async {
    int attempt = 0;
    Duration delay = Duration(seconds: AppConfig.retryDelaySeconds);

    while (attempt < maxAttempts) {
      try {
        attempt++;
        AppLogger.debug('Attempt $attempt of $maxAttempts...');
        return await operation();
      } catch (e) {
        AppLogger.error('Attempt $attempt failed', e);
        if (attempt >= maxAttempts) {
          AppLogger.error('All retry attempts exhausted');
          rethrow;
        }
        AppLogger.debug('Waiting ${delay.inSeconds}s before retry...');
        await Future.delayed(delay);
        delay *= 2;
      }
    }

    throw Exception('Operation failed after $maxAttempts attempts');
  }

  /// Test connection to Supabase
  Future<bool> testConnection() async {
    try {
      await _client.from('municipalities').select('count').limit(1);
      return true;
    } catch (e) {
      AppLogger.error('Supabase connection failed', e);
      return false;
    }
  }

  /// Create a new report in the database with retry logic
  Future<String> createReport(ReportModel report) async {
    return await _executeWithRetry(() async {
      AppLogger.debug('Creating report in Supabase...');
      final response = await _client
          .from('reports')
          .insert(report.toJson())
          .select('id')
          .single()
          .timeout(AppConfig.queryTimeout);
      final reportId = response['id'] as String;
      AppLogger.debug('Report created with ID: $reportId');
      return reportId;
    });
  }

  /// Upload image to Supabase storage (using 'reportimages' bucket).
  /// Supports both File (mobile) and Uint8List (web) uploads.
  Future<String> uploadImage(dynamic imageSource, String reportId) async {
    return await _executeWithRetry(() async {
      AppLogger.debug('Uploading image to Supabase storage...');
      final fileName = '${reportId}_${_uuid.v4()}.jpg';
      final filePath = 'reports/$fileName';

      try {
        if (imageSource is File) {
          if (!await imageSource.exists()) {
            throw Exception('Image file does not exist');
          }
          final fileSize = await imageSource.length();
          AppLogger.debug('Image size: ${(fileSize / 1024).toStringAsFixed(0)} KB');
          await _client.storage
              .from('reportimages')
              .upload(filePath, imageSource,
                  fileOptions: const FileOptions(
                    cacheControl: '3600',
                    upsert: false,
                    contentType: 'image/jpeg',
                  ))
              .timeout(AppConfig.uploadTimeout);
        } else if (imageSource is Uint8List) {
          AppLogger.debug('Image size: ${(imageSource.length / 1024).toStringAsFixed(0)} KB');
          await _client.storage
              .from('reportimages')
              .uploadBinary(filePath, imageSource,
                  fileOptions: const FileOptions(
                    cacheControl: '3600',
                    upsert: false,
                    contentType: 'image/jpeg',
                  ))
              .timeout(AppConfig.uploadTimeout);
        } else {
          throw Exception('Unsupported image source type: ${imageSource.runtimeType}');
        }

        final publicUrl = _client.storage.from('reportimages').getPublicUrl(filePath);
        AppLogger.debug('Image uploaded successfully');
        return publicUrl;
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('socketexception') || errorStr.contains('failed host lookup')) {
          AppLogger.error('DNS error: cannot reach Supabase server');
          throw Exception('Cannot reach upload server. Please check your internet connection and try again.');
        } else if (errorStr.contains('bucket') || errorStr.contains('not found')) {
          AppLogger.error('Storage bucket "reportimages" not found');
          throw Exception('Upload configuration error. Please contact support.');
        } else if (errorStr.contains('policy') || errorStr.contains('permission')) {
          AppLogger.error('No permission to upload to bucket');
          throw Exception('Upload permission denied. Please contact support.');
        } else if (errorStr.contains('timeout')) {
          AppLogger.error('Upload timed out');
          throw Exception('Upload timed out. Please try again with a smaller image.');
        }
        AppLogger.error('Unexpected upload error', e);
        rethrow;
      }
    });
  }

  Future<List<ReportModel>> getReportsByMunicipality(String municipality) async {
    try {
      AppLogger.debug('Fetching reports for municipality: $municipality');
      final response = await _client
          .from('reports')
          .select()
          .eq('municipality', municipality)
          .order('created_at', ascending: false);
      final reports = response.map<ReportModel>((data) => ReportModel.fromJson(data)).toList();
      AppLogger.debug('Fetched ${reports.length} reports for $municipality');
      return reports;
    } catch (e) {
      AppLogger.error('Failed to fetch reports', e);
      return [];
    }
  }

  Future<List<ReportModel>> getReportsByStatus(String status) async {
    try {
      AppLogger.debug('Fetching reports with status: $status');
      final response = await _client
          .from('reports')
          .select()
          .eq('status', status)
          .order('created_at', ascending: false);
      final reports = response.map<ReportModel>((data) => ReportModel.fromJson(data)).toList();
      AppLogger.debug('Fetched ${reports.length} reports with status $status');
      return reports;
    } catch (e) {
      AppLogger.error('Failed to fetch reports by status', e);
      return [];
    }
  }

  Future<List<ReportModel>> getAllReports() async {
    try {
      AppLogger.debug('Fetching all reports...');
      final response = await _client
          .from('reports')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      final reports = response.map<ReportModel>((data) => ReportModel.fromJson(data)).toList();
      AppLogger.debug('Fetched ${reports.length} total reports');
      return reports;
    } catch (e) {
      AppLogger.error('Failed to fetch all reports', e);
      return [];
    }
  }

  Future<void> updateReportStatus(String reportId, String status) async {
    try {
      AppLogger.debug('Updating report status...');
      await _client
          .from('reports')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', reportId);
      AppLogger.debug('Report status updated');
    } catch (e) {
      AppLogger.error('Failed to update report status', e);
      throw Exception('Failed to update report status: $e');
    }
  }

  Future<List<ReportModel>> getUserReports(String userId) async {
    try {
      AppLogger.debug('Fetching user reports...');
      final response = await _client
          .from('reports')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final reports = response.map<ReportModel>((data) => ReportModel.fromJson(data)).toList();
      AppLogger.debug('Fetched ${reports.length} user reports');
      return reports;
    } catch (e) {
      AppLogger.error('Failed to fetch user reports', e);
      return [];
    }
  }

  Future<void> deleteReport(String reportId) async {
    try {
      AppLogger.debug('Deleting report...');
      await _client.from('reports').delete().eq('id', reportId);
      AppLogger.debug('Report deleted');
    } catch (e) {
      AppLogger.error('Failed to delete report', e);
      throw Exception('Failed to delete report: $e');
    }
  }

  Future<Map<String, int>> getReportStatistics(String municipality) async {
    try {
      AppLogger.debug('Fetching statistics...');
      final response = await _client
          .from('reports')
          .select('status')
          .eq('municipality', municipality);
      Map<String, int> stats = {'total': response.length, 'pending': 0, 'in_progress': 0, 'resolved': 0};
      for (var report in response) {
        final status = report['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
      }
      AppLogger.debug('Statistics fetched');
      return stats;
    } catch (e) {
      AppLogger.error('Failed to fetch statistics', e);
      return {'total': 0, 'pending': 0, 'in_progress': 0, 'resolved': 0};
    }
  }

  Future<List<Map<String, dynamic>>> getMunicipalities() async {
    try {
      AppLogger.debug('Fetching municipalities...');
      final response = await _client
          .from('municipalities')
          .select('*')
          .order('name', ascending: true);
      AppLogger.debug('Fetched ${response.length} municipalities');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('Failed to fetch municipalities', e);
      return [];
    }
  }

  Future<Map<String, bool>> testSetup() async {
    Map<String, bool> results = {
      'database_connection': false,
      'reports_table': false,
      'municipalities_table': false,
      'storage_bucket': false,
    };
    try {
      await _client.from('municipalities').select('count').limit(1);
      results['database_connection'] = true;
      await _client.from('reports').select('count').limit(1);
      results['reports_table'] = true;
      await _client.from('municipalities').select('count').limit(1);
      results['municipalities_table'] = true;
      final buckets = await _client.storage.listBuckets();
      results['storage_bucket'] = buckets.any((bucket) => bucket.id == 'reportimages');
    } catch (e) {
      AppLogger.error('Setup test failed', e);
    }
    return results;
  }

  Future<void> initializeSampleData() async {
    try {
      AppLogger.debug('Checking for sample data...');
      final existingReports = await _client.from('reports').select('count').limit(1);
      if (existingReports.isEmpty) {
        AppLogger.debug('Creating sample reports...');
        final sampleReports = [
          {
            'title': 'Sample Pothole Report',
            'description': 'Testing app functionality with sample data',
            'category': 'Potholes',
            'municipality': 'Quatre Bornes',
            'latitude': -20.2658,
            'longitude': 57.4789,
            'address': 'Royal Road, Quatre Bornes',
            'status': 'pending'
          },
          {
            'title': 'Sample Street Light Issue',
            'description': 'Testing street light reporting',
            'category': 'Broken Street Lights',
            'municipality': 'Curepipe',
            'latitude': -20.3167,
            'longitude': 57.5167,
            'address': 'Elizabeth Avenue, Curepipe',
            'status': 'in_progress'
          }
        ];
        await _client.from('reports').insert(sampleReports);
        AppLogger.debug('Sample data created');
      } else {
        AppLogger.debug('Sample data already exists');
      }
    } catch (e) {
      AppLogger.error('Failed to initialize sample data', e);
    }
  }
}
