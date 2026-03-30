import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/app_logger.dart';

/// A platform-aware image widget that handles File images on mobile and Uint8List on web
class PlatformImage extends StatelessWidget {
  final File? file;
  final Uint8List? bytes;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const PlatformImage({
    super.key,
    this.file,
    this.bytes,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (kIsWeb) {
      // On web, use bytes or show placeholder
      if (bytes != null) {
        imageWidget = Image.memory(
          bytes!,
          fit: fit,
          width: width,
          height: height,
        );
      } else {
        imageWidget = _buildPlaceholder();
      }
    } else {
      // On mobile, use file or show placeholder
      if (file != null && file!.existsSync()) {
        imageWidget = Image.file(
          file!,
          fit: fit,
          width: width,
          height: height,
        );
      } else {
        imageWidget = _buildPlaceholder();
      }
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 48,
        ),
      ),
    );
  }
}

/// Helper extension to convert File to Uint8List for web compatibility
extension FileExtension on File {
  Future<Uint8List?> readAsBytesAsync() async {
    try {
      if (kIsWeb) {
        // On web, we can't read files directly
        return null;
      } else {
        return await readAsBytes();
      }
    } catch (e) {
      debugPrint('Error reading file as bytes: $e');
      return null;
    }
  }
} 