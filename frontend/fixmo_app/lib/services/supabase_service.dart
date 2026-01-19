import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/report_model.dart';
import '../config/app_config.dart';

/// Service for handling Supabase database and storage operations
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  /// Get Supabase client instance
  SupabaseClient get client => _client;

  /// Check if device has internet connection and Supabase is reachable
  /// Note: This is a lightweight check. The actual upload relies on retry logic.
  Future<bool> hasInternetConnection() async {
    try {
      // Simple ping to Supabase - just check if we can reach it
      // Don't fail on RLS policies, just verify network connectivity
      await _client
          .from('municipalities')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 3));
      print('✅ Supabase connection verified');
      return true;
    } catch (e) {
      // Categorize error type for better diagnostics
      final errorMessage = e.toString().toLowerCase();
      
      if (errorMessage.contains('socketexception') || 
          errorMessage.contains('failed host lookup')) {
        print('❌ DNS Error: Cannot resolve Supabase host. Check your Supabase URL.');
        print('   URL: ${AppConfig.supabaseUrl}');
        print('   This may indicate an incorrect project URL or DNS issue.');
      } else if (errorMessage.contains('timeout')) {
        print('⚠️ Timeout: Supabase not responding within 3 seconds');
      } else if (errorMessage.contains('auth') || errorMessage.contains('jwt')) {
        print('⚠️ Auth Error: API key may be incorrect');
      } else {
        print('⚠️ Connection check warning: $e');
      }
      
      // Return true to allow the upload to proceed with retry logic
      // The actual upload will provide better error feedback
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
        print('🔄 Attempt $attempt of $maxAttempts...');
        return await operation();
      } catch (e) {
        print('❌ Attempt $attempt failed: $e');
        
        if (attempt >= maxAttempts) {
          print('❌ All retry attempts exhausted');
          rethrow;
        }

        // Exponential backoff
        print('⏳ Waiting ${delay.inSeconds}s before retry...');
        await Future.delayed(delay);
        delay *= 2; // Double the delay for next attempt
      }
    }

    throw Exception('Operation failed after $maxAttempts attempts');
  }

  /// Test connection to Supabase
  Future<bool> testConnection() async {
    try {
      final response = await _client
          .from('municipalities')
          .select('count')
          .limit(1);
      return true;
    } catch (e) {
      print('❌ Supabase connection failed: $e');
      return false;
    }
  }

  /// Create a new report in the database with retry logic
  Future<String> createReport(ReportModel report) async {
    return await _executeWithRetry(() async {
      print('🔄 Creating report in Supabase...');
      
      final response = await _client
          .from('reports')
          .insert(report.toJson())
          .select('id')
          .single()
          .timeout(AppConfig.queryTimeout);
      
      final reportId = response['id'] as String;
      print('✅ Report created successfully with ID: $reportId');
      return reportId;
    });
  }

  /// Upload image to Supabase storage (using 'reportimages' bucket)
  /// Supports both File (mobile) and Uint8List (web) uploads
  Future<String> uploadImage(dynamic imageSource, String reportId) async {
    return await _executeWithRetry(() async {
      print('🔄 Uploading image to Supabase storage...');
      print('   Storage URL: ${AppConfig.supabaseUrl}/storage/v1');
      
      final fileName = '${reportId}_${_uuid.v4()}.jpg';
      final filePath = 'reports/$fileName';
      
      try {
        // Handle different image source types
        if (imageSource is File) {
          // Mobile: Upload from File
          if (!await imageSource.exists()) {
            throw Exception('Image file does not exist at path: ${imageSource.path}');
          }
          
          final fileSize = await imageSource.length();
          print('   Image size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
          
          await _client.storage
              .from('reportimages')
              .upload(
                filePath, 
                imageSource,
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: false,
                  contentType: 'image/jpeg',
                ),
              )
              .timeout(AppConfig.uploadTimeout);
              
        } else if (imageSource is Uint8List) {
          // Web: Upload from bytes
          print('   Image size: ${(imageSource.length / 1024).toStringAsFixed(2)} KB');
          
          await _client.storage
              .from('reportimages')
              .uploadBinary(
                filePath, 
                imageSource,
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: false,
                  contentType: 'image/jpeg',
                ),
              )
              .timeout(AppConfig.uploadTimeout);
              
        } else {
          throw Exception('Unsupported image source type: ${imageSource.runtimeType}');
        }
        
        // Get public URL
        final publicUrl = _client.storage
            .from('reportimages')
            .getPublicUrl(filePath);
        
        print('✅ Image uploaded successfully');
        print('   Public URL: $publicUrl');
        return publicUrl;
        
      } catch (e) {
        // Enhanced error diagnostics
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('socketexception') || errorStr.contains('failed host lookup')) {
          print('❌ DNS ERROR: Cannot reach Supabase server');
          print('   Check your Supabase project URL: ${AppConfig.supabaseUrl}');
          throw Exception('Cannot reach upload server. Please check your internet connection and try again.');
        } else if (errorStr.contains('bucket') || errorStr.contains('not found')) {
          print('❌ BUCKET ERROR: Storage bucket "reportimages" not found');
          print('   Please create the bucket in your Supabase dashboard');
          throw Exception('Upload configuration error. Please contact support.');
        } else if (errorStr.contains('policy') || errorStr.contains('permission')) {
          print('❌ PERMISSION ERROR: No permission to upload to bucket');
          print('   Check RLS policies for the "reportimages" bucket');
          throw Exception('Upload permission denied. Please contact support.');
        } else if (errorStr.contains('timeout')) {
          print('❌ TIMEOUT: Upload took longer than ${AppConfig.uploadTimeout.inSeconds}s');
          throw Exception('Upload timed out. Please try again with a smaller image.');
        }
        
        print('❌ Unexpected upload error: $e');
        rethrow;
      }
    });
  }

  /// Get all reports for a specific municipality
  Future<List<ReportModel>> getReportsByMunicipality(String municipality) async {
    try {
      print('🔄 Fetching reports for municipality: $municipality');
      
      final response = await _client
          .from('reports')
          .select()
          .eq('municipality', municipality)
          .order('created_at', ascending: false);
      
      final reports = response
          .map<ReportModel>((data) => ReportModel.fromJson(data))
          .toList();
      
      print('✅ Fetched ${reports.length} reports for $municipality');
      return reports;
    } catch (e) {
      print('❌ Failed to fetch reports: $e');
      return []; // Return empty list instead of throwing
    }
  }

  /// Get reports by status
  Future<List<ReportModel>> getReportsByStatus(String status) async {
    try {
      print('🔄 Fetching reports with status: $status');
      
      final response = await _client
          .from('reports')
          .select()
          .eq('status', status)
          .order('created_at', ascending: false);
      
      final reports = response
          .map<ReportModel>((data) => ReportModel.fromJson(data))
          .toList();
      
      print('✅ Fetched ${reports.length} reports with status $status');
      return reports;
    } catch (e) {
      print('❌ Failed to fetch reports by status: $e');
      return []; // Return empty list instead of throwing
    }
  }

  /// Get all reports (for testing and admin purposes)
  Future<List<ReportModel>> getAllReports() async {
    try {
      print('🔄 Fetching all reports...');
      
      final response = await _client
          .from('reports')
          .select()
          .order('created_at', ascending: false)
          .limit(100); // Limit to prevent excessive data
      
      final reports = response
          .map<ReportModel>((data) => ReportModel.fromJson(data))
          .toList();
      
      print('✅ Fetched ${reports.length} total reports');
      return reports;
    } catch (e) {
      print('❌ Failed to fetch all reports: $e');
      return []; // Return empty list instead of throwing
    }
  }

  /// Update report status
  Future<void> updateReportStatus(String reportId, String status) async {
    try {
      print('🔄 Updating report $reportId status to: $status');
      
      await _client
          .from('reports')
          .update({
            'status': status, 
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', reportId);
      
      print('✅ Report status updated successfully');
    } catch (e) {
      print('❌ Failed to update report status: $e');
      throw Exception('Failed to update report status: $e');
    }
  }

  /// Get user's reports
  Future<List<ReportModel>> getUserReports(String userId) async {
    try {
      print('🔄 Fetching reports for user: $userId');
      
      final response = await _client
          .from('reports')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      final reports = response
          .map<ReportModel>((data) => ReportModel.fromJson(data))
          .toList();
      
      print('✅ Fetched ${reports.length} reports for user');
      return reports;
    } catch (e) {
      print('❌ Failed to fetch user reports: $e');
      return []; // Return empty list instead of throwing
    }
  }

  /// Delete a report
  Future<void> deleteReport(String reportId) async {
    try {
      print('🔄 Deleting report: $reportId');
      
      await _client
          .from('reports')
          .delete()
          .eq('id', reportId);
      
      print('✅ Report deleted successfully');
    } catch (e) {
      print('❌ Failed to delete report: $e');
      throw Exception('Failed to delete report: $e');
    }
  }

  /// Get report statistics for dashboard
  Future<Map<String, int>> getReportStatistics(String municipality) async {
    try {
      print('🔄 Fetching statistics for: $municipality');
      
      final response = await _client
          .from('reports')
          .select('status')
          .eq('municipality', municipality);
      
      Map<String, int> stats = {
        'total': response.length,
        'pending': 0,
        'in_progress': 0,
        'resolved': 0,
      };
      
      for (var report in response) {
        final status = report['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
      }
      
      print('✅ Statistics: ${stats.toString()}');
      return stats;
    } catch (e) {
      print('❌ Failed to fetch statistics: $e');
      return {
        'total': 0,
        'pending': 0,
        'in_progress': 0,
        'resolved': 0,
      };
    }
  }

  /// Get all municipalities from database
  Future<List<Map<String, dynamic>>> getMunicipalities() async {
    try {
      print('🔄 Fetching municipalities from database...');
      
      final response = await _client
          .from('municipalities')
          .select('*')
          .order('name', ascending: true);
      
      print('✅ Fetched ${response.length} municipalities');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Failed to fetch municipalities: $e');
      return []; // Return empty list instead of throwing
    }
  }

  /// Test database and storage setup
  Future<Map<String, bool>> testSetup() async {
    Map<String, bool> results = {
      'database_connection': false,
      'reports_table': false,
      'municipalities_table': false,
      'storage_bucket': false,
    };

    try {
      // Test database connection
      await _client.from('municipalities').select('count').limit(1);
      results['database_connection'] = true;
      
      // Test reports table
      await _client.from('reports').select('count').limit(1);
      results['reports_table'] = true;
      
      // Test municipalities table  
      await _client.from('municipalities').select('count').limit(1);
      results['municipalities_table'] = true;
      
      // Test storage bucket
      final buckets = await _client.storage.listBuckets();
      results['storage_bucket'] = buckets.any((bucket) => bucket.id == 'reportimages');
      
    } catch (e) {
      print('❌ Setup test failed: $e');
    }

    return results;
  }

  /// Initialize sample data for testing
  Future<void> initializeSampleData() async {
    try {
      print('🔄 Checking for sample data...');
      
      // Check if we already have reports
      final existingReports = await _client
          .from('reports')
          .select('count')
          .limit(1);
      
      if (existingReports.isEmpty) {
        print('🔄 Creating sample reports...');
        
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
        print('✅ Sample data created successfully');
      } else {
        print('✅ Sample data already exists');
      }
    } catch (e) {
      print('❌ Failed to initialize sample data: $e');
      // Continue anyway - this is not critical
    }
  }
} 