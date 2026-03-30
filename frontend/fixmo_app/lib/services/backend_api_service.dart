import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// HTTP client for the FixMo backend API.
///
/// All report writes are routed through this service instead of
/// inserting directly into Supabase from the client.
class BackendApiService {
  final String _baseUrl = AppConfig.backendUrl;

  /// Create a new report via the backend.
  ///
  /// [accessToken] is the Supabase JWT, used as the Bearer token.
  /// Returns the created report as a Map on success.
  Future<Map<String, dynamic>> createReport({
    required String title,
    required String description,
    required String category,
    String? subcategory,
    required String municipality,
    required double latitude,
    required double longitude,
    String? address,
    String? imageUrl,
    String? accessToken,
  }) async {
    final body = {
      'title': title,
      'description': description,
      'category': category,
      if (subcategory != null) 'subcategory': subcategory,
      'municipality': municipality,
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
      if (imageUrl != null) 'image_url': imageUrl,
    };

    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/reports'),
          headers: _headers(accessToken),
          body: jsonEncode(body),
        )
        .timeout(AppConfig.backendTimeout);

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201 && json['ok'] == true) {
      return json['data'] as Map<String, dynamic>;
    }

    final errorMsg = json['error']?['message'] ?? 'Unknown error';
    throw Exception('Report creation failed: $errorMsg');
  }

  /// Fetch categories from the backend.
  Future<List<dynamic>> getCategories() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/categories'),
      headers: _headers(null),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['ok'] == true) {
      return json['data'] as List<dynamic>;
    }
    throw Exception('Failed to fetch categories');
  }

  /// Fetch municipalities from the backend.
  Future<List<dynamic>> getMunicipalities() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/municipalities'),
      headers: _headers(null),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['ok'] == true) {
      return json['data'] as List<dynamic>;
    }
    throw Exception('Failed to fetch municipalities');
  }

  /// Fetch alerts, optionally filtered by municipality.
  Future<List<dynamic>> getAlerts({String? municipality}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/alerts').replace(
      queryParameters: municipality != null ? {'municipality': municipality} : null,
    );

    final response = await http.get(uri, headers: _headers(null));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['ok'] == true) {
      return json['data'] as List<dynamic>;
    }
    return [];
  }

  /// Health check.
  Future<bool> isHealthy() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['ok'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Backend health check failed: $e');
      return false;
    }
  }

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
