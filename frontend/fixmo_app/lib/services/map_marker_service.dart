import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service for creating custom map markers with standard icons
class MapMarkerService {
  static final Map<String, BitmapDescriptor> _cachedMarkers = {};

  /// Get user location marker (red pin with person icon)
  static Future<BitmapDescriptor> getUserLocationMarker() async {
    const key = 'user_location';
    if (_cachedMarkers.containsKey(key)) {
      return _cachedMarkers[key]!;
    }

    final marker = await _createCustomMarker(
      backgroundColor: Colors.red,
      icon: Icons.person_pin_circle,
      iconColor: Colors.white,
      size: 60,
      borderColor: Colors.white,
      borderWidth: 3,
    );

    _cachedMarkers[key] = marker;
    return marker;
  }

  /// Get municipality marker (blue pin with building icon)
  static Future<BitmapDescriptor> getMunicipalityMarker() async {
    const key = 'municipality';
    if (_cachedMarkers.containsKey(key)) {
      return _cachedMarkers[key]!;
    }

    final marker = await _createCustomMarker(
      backgroundColor: const Color(0xFF2196F3), // Blue
      icon: Icons.location_city,
      iconColor: Colors.white,
      size: 50,
      borderColor: Colors.white,
      borderWidth: 2,
    );

    _cachedMarkers[key] = marker;
    return marker;
  }

  /// Get report marker based on category and status
  static Future<BitmapDescriptor> getReportMarker({
    required String category,
    required String status,
    bool isCurrentUser = false,
  }) async {
    final key = '${category}_${status}_${isCurrentUser}';
    if (_cachedMarkers.containsKey(key)) {
      return _cachedMarkers[key]!;
    }

    Color backgroundColor;
    IconData iconData;

    // Color based on status
    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange;
        break;
      case 'in_progress':
        backgroundColor = Colors.blue;
        break;
      case 'resolved':
        backgroundColor = Colors.green;
        break;
      default:
        backgroundColor = Colors.grey;
    }

    // Icon based on category
    switch (category.toLowerCase()) {
      case 'roads & transport':
        iconData = Icons.directions_car;
        break;
      case 'water & drainage':
        iconData = Icons.water_drop;
        break;
      case 'waste management':
        iconData = Icons.delete;
        break;
      case 'public facilities':
        iconData = Icons.business;
        break;
      case 'street lighting':
        iconData = Icons.lightbulb;
        break;
      case 'environment':
        iconData = Icons.eco;
        break;
      default:
        iconData = Icons.report_problem;
    }

    final marker = await _createCustomMarker(
      backgroundColor: backgroundColor,
      icon: iconData,
      iconColor: Colors.white,
      size: isCurrentUser ? 55 : 45,
      borderColor: isCurrentUser ? Colors.yellow : Colors.white,
      borderWidth: isCurrentUser ? 3 : 2,
    );

    _cachedMarkers[key] = marker;
    return marker;
  }

  /// Get a marker that looks like a photo thumbnail
  /// Currently uses a placeholder pattern until image downloading is implemented
  static Future<BitmapDescriptor> getThumbnailMarker({
    required String category,
    bool isCurrentUser = false,
  }) async {
    final key = 'thumb_${category}_$isCurrentUser';
    if (_cachedMarkers.containsKey(key)) {
      return _cachedMarkers[key]!;
    }

    final marker = await _createThumbnailMarker(
      category: category,
      isCurrentUser: isCurrentUser,
    );
    
    _cachedMarkers[key] = marker;
    return marker;
  }

  static Future<BitmapDescriptor> _createThumbnailMarker({
    required String category,
    required bool isCurrentUser,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 90; // Larger for thumbnail visibility
    const double borderWidth = 3;
    final double radius = size / 2;

    // 1. Draw Shadow/Glow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(radius, radius + 2), radius, shadowPaint);

    // 2. Draw Border (White Frame)
    final Paint borderPaint = Paint()
      ..color = isCurrentUser ? Colors.blue : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);

    // 3. Draw "Image" Placeholder (Gray background)
    final Paint bgPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(radius, radius), width: size - 10, height: size - 10),
      bgPaint,
    );

    // 4. Draw Simple "Mountains/Sun" Icon to represent an image
    // Sun
    canvas.drawCircle(Offset(radius + 15, radius - 15), 6, Paint()..color = Colors.orangeAccent);
    
    // Mountains
    final Path mountainPath = Path();
    mountainPath.moveTo(radius - 25, radius + 25);
    mountainPath.lineTo(radius - 10, radius - 10);
    mountainPath.lineTo(radius + 10, radius + 10);
    mountainPath.lineTo(radius + 25, radius - 5);
    mountainPath.lineTo(radius + 35, radius + 25);
    mountainPath.close();
    canvas.drawPath(mountainPath, Paint()..color = Colors.green.shade600);

    // 5. Draw Category Icon overlay (Small badge)
    final double badgeSize = 24;
    final Paint badgeBg = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(size - 12, size - 12),
      badgeSize / 2 + 1,
      badgeBg,
    );
    
    IconData iconData;
    switch (category.toLowerCase()) {
      case 'roads & transport': iconData = Icons.directions_car; break;
      case 'water & drainage': iconData = Icons.water_drop; break;
      case 'waste management': iconData = Icons.delete; break;
      case 'street lighting': iconData = Icons.lightbulb; break;
      case 'environment': iconData = Icons.eco; break;
      default: iconData = Icons.report_problem;
    }

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 16,
        fontFamily: iconData.fontFamily,
        color: const Color(0xFF6C63FF),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size - 12 - textPainter.width / 2, size - 12 - textPainter.height / 2),
    );

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(pngBytes);
  }

  /// Create a custom circular marker with icon
  static Future<BitmapDescriptor> _createCustomMarker({
    required Color backgroundColor,
    required IconData icon,
    required Color iconColor,
    required double size,
    Color borderColor = Colors.white,
    double borderWidth = 2,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double radius = size / 2;

    // Draw border circle
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);

    // Draw background circle
    final Paint backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(radius, radius),
      radius - borderWidth,
      backgroundPaint,
    );

    // Draw icon
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: icon.fontFamily,
        color: iconColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        radius - textPainter.width / 2,
        radius - textPainter.height / 2,
      ),
    );

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(pngBytes);
  }

  /// Clear cached markers (useful for memory management)
  static void clearCache() {
    _cachedMarkers.clear();
  }

  /// Get cluster marker for multiple reports at same location
  static Future<BitmapDescriptor> getClusterMarker(int count) async {
    final key = 'cluster_$count';
    if (_cachedMarkers.containsKey(key)) {
      return _cachedMarkers[key]!;
    }

    final marker = await _createClusterMarker(count);
    _cachedMarkers[key] = marker;
    return marker;
  }

  /// Create a cluster marker showing number of reports
  static Future<BitmapDescriptor> _createClusterMarker(int count) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 60;
    const double radius = size / 2;

    // Draw border circle
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);

    // Draw background circle with gradient effect
    final Paint backgroundPaint = Paint()
      ..color = count > 10 ? Colors.red : count > 5 ? Colors.orange : Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(radius, radius),
      radius - 3,
      backgroundPaint,
    );

    // Draw count text
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: count > 99 ? '99+' : count.toString(),
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        radius - textPainter.width / 2,
        radius - textPainter.height / 2,
      ),
    );

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(pngBytes);
  }
} 