import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/report_model.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';

/// JPEG, PNG, and WebP magic byte signatures for client-side validation.
const _jpegSignature = [0xFF, 0xD8, 0xFF];
const _pngSignature = [0x89, 0x50, 0x4E, 0x47];
const _webpSignature = [0x52, 0x49, 0x46, 0x46]; // "RIFF"

/// Service for handling Supabase database and storage operations
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  SupabaseClient get client => _client;

  /// Check if device has internet connection and Supabase is reachable.
  Future<bool> hasInternetConnection() async {
    try {
      await _client
          .from('municipalities')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (e) {
      debugPrint('Connection check failed: $e');
      return false;
    }
  }

  /// Validate image bytes: check magic bytes and enforce size limit.
  /// Returns null if valid, or an error message if invalid.
  static String? validateImageBytes(Uint8List bytes) {
    if (bytes.isEmpty) return 'Image data is empty';
    if (bytes.length > AppConfig.maxImageSizeBytes) {
      final maxMb = AppConfig.maxImageSizeBytes / (1024 * 1024);
      return 'Image exceeds ${maxMb.toStringAsFixed(0)} MB limit';
    }

    bool matchesSignature(List<int> sig) =>
        bytes.length >= sig.length &&
        sig.asMap().entries.every((e) => bytes[e.key] == e.value);

    if (matchesSignature(_jpegSignature)) return null;
    if (matchesSignature(_pngSignature)) return null;
    if (matchesSignature(_webpSignature)) return null;

    return 'Unsupported image format. Allowed: JPEG, PNG, WebP';
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
        debugPrint('🔄 Attempt $attempt of $maxAttempts...');
        return await operation();
      } catch (e) {
        debugPrint('❌ Attempt $attempt failed: $e');
        
        if (attempt >= maxAttempts) {
          debugPrint('❌ All retry attempts exhausted');
          rethrow;
        }

        // Exponential backoff
        debugPrint('⏳ Waiting ${delay.inSeconds}s before retry...');
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
      debugPrint('❌ Supabase connection failed: $e');
      return false;
    }
  }

  /// Upload image to Supabase storage (using 'reportimages' bucket).
  /// Validates magic bytes and file size before uploading.
  Future<String> uploadImage(dynamic imageSource, String reportId) async {
    return await _executeWithRetry(() async {
      debugPrint('Uploading image to Supabase storage...');

      final fileName = '${reportId}_${_uuid.v4()}.jpg';
      final filePath = 'reports/$fileName';

      try {
        if (imageSource is File) {
          if (!await imageSource.exists()) {
            throw Exception('Image file does not exist');
          }

          final fileBytes = await imageSource.readAsBytes();
          final validationError = validateImageBytes(fileBytes);
          if (validationError != null) throw Exception(validationError);

          debugPrint('Image size: ${(fileBytes.length / 1024).toStringAsFixed(0)} KB');
          
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
          final validationError = validateImageBytes(imageSource);
          if (validationError != null) throw Exception(validationError);

          debugPrint('Image size: ${(imageSource.length / 1024).toStringAsFixed(0)} KB');
          
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
        
        // Get public URL
        final publicUrl = _client.storage
            .from('reportimages')
            .getPublicUrl(filePath);
        
        debugPrint('✅ Image uploaded successfully');
        debugPrint('   Public URL: $publicUrl');
        return publicUrl;
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('socketexception') || errorStr.contains('failed host lookup')) {
          debugPrint('❌ DNS ERROR: Cannot reach Supabase server');
          debugPrint('   Check your Supabase project URL: ${AppConfig.supabaseUrl}');
          throw Exception('Cannot reach upload server. Please check your internet connection and try again.');
        } else if (errorStr.contains('bucket') || errorStr.contains('not found')) {
          debugPrint('❌ BUCKET ERROR: Storage bucket "reportimages" not found');
          debugPrint('   Please create the bucket in your Supabase dashboard');
          throw Exception('Upload configuration error. Please contact support.');
        } else if (errorStr.contains('policy') || errorStr.contains('permission')) {
          debugPrint('❌ PERMISSION ERROR: No permission to upload to bucket');
          debugPrint('   Check RLS policies for the "reportimages" bucket');
          throw Exception('Upload permission denied. Please contact support.');
        } else if (errorStr.contains('timeout')) {
          debugPrint('❌ TIMEOUT: Upload took longer than ${AppConfig.uploadTimeout.inSeconds}s');
          throw Exception('Upload timed out. Please try again with a smaller image.');
        }
        
        debugPrint('❌ Unexpected upload error: $e');
        rethrow;
      }
    });
  }

  /// Insert a report directly into Supabase when the backend is unreachable.
  /// Used as a fallback so users can always submit reports.
  Future<Map<String, dynamic>> createReportDirect({
    required String title,
    required String description,
    required String category,
    String? subcategory,
    required String municipality,
    required double latitude,
    required double longitude,
    String? address,
    String? imageUrl,
    String? userId,
  }) async {
    final row = {
      'title': title,
      'description': description,
      'category': category,
      if (subcategory != null) 'subcategory': subcategory,
      'municipality': municipality,
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
      if (imageUrl != null) 'image_url': imageUrl,
      if (userId != null) 'user_id': userId,
      'status': 'pending',
    };

    final response = await _client
        .from('reports')
        .insert(row)
        .select()
        .single()
        .timeout(AppConfig.queryTimeout);

    debugPrint('Report inserted directly into Supabase: ${response['id']}');
    return response;
  }

  /// Get all reports for a specific municipality
  Future<List<ReportModel>> getReportsByMunicipality(String municipality) async {
    try {
      debugPrint('🔄 Fetching reports for municipality: $municipality');
      
      final response = await _client
          .from('reports')
          .select()
          .eq('municipality', municipality)
          .order('created_at', ascending: false);
      
      final reports = response
          .map<ReportModel>((data) => ReportModel.fromJson(data))
          .toList();
      
      debugPrint('✅ Fetched ${reports.length} reports for $municipality');
      return reports;
    } catch (e) {
      debugPrint('❌ Failed to fetch reports: $e');
      return []; // Return empty list instead of throwing
    }
  }

  Future<List<ReportModel>> getReportsByStatus(String status) async {
    try {
      debugPrint('🔄 Fetching reports with status: $status');
      
      final response = await _client
          .from('reports')
          .select()
          .eq('status', status)
          .order('created_at', ascending: false);
      
      final reports = response
          .map<ReportModel>((data) => ReportModel.fromJson(data))
          .toList();
      
      debugPrint('✅ Fetched ${reports.length} reports with status $status');
      return reports;
    } catch (e) {
      debugPrint('❌ Failed to fetch reports by status: $e');
      return []; // Return empty list instead of throwing
    }
  }

  Future<List<ReportModel>> getAllReports() async {
    try {
      debugPrint('🔄 Fetching all reports...');
      
      final response = await _client
          .from('reports')
          .select()
          .order('created_at', ascending: false)
          .limit(100); // Limit to prevent excessive data
      
      final reports = response
          .map<ReportModel>((data) => ReportModel.fromJson(data))
          .toList();
      
      debugPrint('✅ Fetched ${reports.length} total reports');
      return reports;
    } catch (e) {
      debugPrint('❌ Failed to fetch all reports: $e');
      return []; // Return empty list instead of throwing
    }
  }

  /// Get user's reports
  Future<List<ReportModel>> getUserReports(String userId) async {
    try {
      debugPrint('🔄 Fetching reports for user: $userId');
      
      final response = await _client
          .from('reports')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      final reports = response
          .map<ReportModel>((data) => ReportModel.fromJson(data))
          .toList();
      
      debugPrint('✅ Fetched ${reports.length} reports for user');
      return reports;
    } catch (e) {
      debugPrint('❌ Failed to fetch user reports: $e');
      return []; // Return empty list instead of throwing
    }
  }

  /// Get report statistics for dashboard
  Future<Map<String, int>> getReportStatistics(String municipality) async {
    try {
      debugPrint('🔄 Fetching statistics for: $municipality');
      
      final response = await _client
          .from('reports')
          .select('status')
          .eq('municipality', municipality);
      Map<String, int> stats = {'total': response.length, 'pending': 0, 'in_progress': 0, 'resolved': 0};
      for (var report in response) {
        final status = report['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
      }
      
      debugPrint('✅ Statistics: ${stats.toString()}');
      return stats;
    } catch (e) {
      debugPrint('❌ Failed to fetch statistics: $e');
      return {
        'total': 0,
        'pending': 0,
        'in_progress': 0,
        'resolved': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getMunicipalities() async {
    try {
      debugPrint('🔄 Fetching municipalities from database...');
      
      final response = await _client
          .from('municipalities')
          .select('*')
          .order('name', ascending: true);
      
      debugPrint('✅ Fetched ${response.length} municipalities');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Failed to fetch municipalities: $e');
      return []; // Return empty list instead of throwing
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
      debugPrint('❌ Setup test failed: $e');
    }
    return results;
  }

} 