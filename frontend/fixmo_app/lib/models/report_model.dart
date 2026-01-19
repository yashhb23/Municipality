import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

/// Model representing a civic issue report
class ReportModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String subcategory;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Position location;
  final String municipality;
  final List<String> imageUrls;
  final String reporterName;
  final String? reporterAvatar;
  final bool isCurrentUser;
  final int priority;
  final String address;

  ReportModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.subcategory,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    required this.location,
    required this.municipality,
    required this.imageUrls,
    required this.reporterName,
    this.reporterAvatar,
    this.isCurrentUser = false,
    this.priority = 1,
    required this.address,
  });

  /// Create from JSON
  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      subcategory: json['subcategory'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      location: Position(
        latitude: json['latitude']?.toDouble() ?? 0.0,
        longitude: json['longitude']?.toDouble() ?? 0.0,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ),
      municipality: json['municipality'] ?? '',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      reporterName: json['reporterName'] ?? 'Anonymous',
      reporterAvatar: json['reporterAvatar'],
      isCurrentUser: json['isCurrentUser'] ?? false,
      priority: json['priority'] ?? 1,
      address: json['address'] ?? '',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'subcategory': subcategory,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'latitude': location.latitude,
      'longitude': location.longitude,
      'municipality': municipality,
      'imageUrls': imageUrls,
      'reporterName': reporterName,
      'reporterAvatar': reporterAvatar,
      'isCurrentUser': isCurrentUser,
      'priority': priority,
      'address': address,
    };
  }

  /// Get status color
  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFA726); // Orange
      case 'in_progress':
        return const Color(0xFF42A5F5); // Blue
      case 'resolved':
        return const Color(0xFF66BB6A); // Green
      case 'rejected':
        return const Color(0xFFEF5350); // Red
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  /// Get category icon
  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'infrastructure':
        return Icons.construction;
      case 'sanitation':
        return Icons.cleaning_services;
      case 'transport':
        return Icons.directions_bus;
      case 'environment':
        return Icons.eco;
      case 'public_safety':
        return Icons.security;
      case 'utilities':
        return Icons.electrical_services;
      default:
        return Icons.report_problem;
    }
  }

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Copy with method for updating report
  ReportModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? subcategory,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Position? location,
    String? municipality,
    List<String>? imageUrls,
    String? reporterName,
    String? reporterAvatar,
    bool? isCurrentUser,
    int? priority,
    String? address,
  }) {
    return ReportModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      location: location ?? this.location,
      municipality: municipality ?? this.municipality,
      imageUrls: imageUrls ?? this.imageUrls,
      reporterName: reporterName ?? this.reporterName,
      reporterAvatar: reporterAvatar ?? this.reporterAvatar,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      priority: priority ?? this.priority,
      address: address ?? this.address,
    );
  }

  /// Get formatted date string for display
  String get formattedDate {
    if (createdAt == null) return 'Unknown date';
    
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Get status display text
  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  @override
  String toString() {
    return 'ReportModel(id: $id, title: $title, category: $category, municipality: $municipality, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReportModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 