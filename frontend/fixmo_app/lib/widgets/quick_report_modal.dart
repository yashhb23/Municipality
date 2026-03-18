import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../config/app_config.dart';
import '../models/report_model.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../providers/app_state_provider.dart';
import 'category_chips.dart';
import 'upload_progress_overlay.dart';

/// Quick report bottom sheet: camera, category grid, description, submit.
/// Dark theme, blur. "More options" opens full report screen.
class QuickReportModal extends StatefulWidget {
  const QuickReportModal({super.key});

  /// Shows the modal and returns when it is closed.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuickReportModal(),
    );
  }

  @override
  State<QuickReportModal> createState() => _QuickReportModalState();
}

class _QuickReportModalState extends State<QuickReportModal> {
  final TextEditingController _descriptionController = TextEditingController();
  File? _capturedImage;
  Uint8List? _capturedImageBytes;
  String? _selectedCategory;
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;
  String _uploadStage = '';
  bool _showSuccess = false;

  static const Color _primary = Color(0xFF00D9A3);
  static const Color _surface = Color(0xFF1A1A1A);
  static const List<String> _categories = CategoryChips.defaultCategories;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (photo == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera access denied. You can enable it in Settings.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    if (kIsWeb) {
      final bytes = await photo.readAsBytes();
      setState(() => _capturedImageBytes = bytes);
    } else {
      setState(() => _capturedImage = File(photo.path));
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final supabaseService = context.read<SupabaseService>();
    final hasConnection = await supabaseService.hasInternetConnection();
    if (!hasConnection && mounted) {
      _showSnack('No internet connection.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
      _uploadStage = 'Preparing...';
      _showSuccess = false;
    });

    try {
      setState(() {
        _uploadProgress = 0.1;
        _uploadStage = 'Getting location...';
      });
      Position position;
      try {
        final locationService = context.read<LocationService>();
        final pos = await locationService.getCurrentLocation();
        if (pos != null) {
          position = pos;
        } else {
          throw Exception('No position');
        }
      } catch (_) {
        final appState = context.read<AppStateProvider>();
        if (appState.currentPosition != null) {
          position = appState.currentPosition!;
        } else {
          position = Position(
            latitude: AppConfig.mauritiusLatitude,
            longitude: AppConfig.mauritiusLongitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        }
      }

      String? imageUrl;
      if (_capturedImage != null || _capturedImageBytes != null) {
        setState(() {
          _uploadProgress = 0.15;
          _uploadStage = 'Optimizing image...';
        });
        dynamic compressed;
        if (kIsWeb && _capturedImageBytes != null) {
          compressed = await FlutterImageCompress.compressWithList(
            _capturedImageBytes!,
            quality: 85,
            minWidth: 1920,
            minHeight: 1080,
            format: CompressFormat.jpeg,
          );
        } else if (!kIsWeb && _capturedImage != null) {
          final path = _capturedImage!.absolute.path;
          final lastIndex = path.lastIndexOf('.');
          final outPath = '${path.substring(0, lastIndex)}_compressed.jpg';
          final result = await FlutterImageCompress.compressAndGetFile(
            path,
            outPath,
            quality: 85,
            minWidth: 1920,
            minHeight: 1080,
            format: CompressFormat.jpeg,
          );
          compressed = result != null ? File(result.path) : _capturedImage;
        }
        if (compressed != null && mounted) {
          setState(() {
            _uploadProgress = 0.3;
            _uploadStage = 'Uploading image...';
          });
          final tempId = DateTime.now().millisecondsSinceEpoch.toString();
          imageUrl = await supabaseService.uploadImage(compressed, tempId);
        }
        if (mounted) setState(() => _uploadProgress = 0.6);
      }

      final appState = context.read<AppStateProvider>();
      final municipality = appState.selectedMunicipality ?? 'Unknown';

      setState(() {
        _uploadProgress = 0.7;
        _uploadStage = 'Saving report...';
      });

      final report = ReportModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _selectedCategory ?? 'Quick Report',
        description: _descriptionController.text.trim().isEmpty
            ? 'No additional details'
            : _descriptionController.text.trim(),
        category: _selectedCategory ?? 'General',
        subcategory: 'Other',
        status: 'pending',
        createdAt: DateTime.now(),
        location: position,
        municipality: municipality,
        imageUrls: imageUrl != null ? [imageUrl] : [],
        reporterName: 'Anonymous User',
        isCurrentUser: true,
        priority: 1,
        address: '$municipality, Mauritius',
      );

      await supabaseService.createReport(report);

      if (mounted) {
        setState(() {
          _uploadProgress = 1.0;
          _uploadStage = 'Success!';
          _showSuccess = true;
        });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to submit: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  void _openFullReport() {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed('/report');
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final sheetHeight = height * 0.65;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: const Color(0xE61A1A1A),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Quick Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildCameraButton(),
                      const SizedBox(height: 20),
                      const Text(
                        'Category',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildCategoryGrid(),
                      const SizedBox(height: 20),
                      const Text(
                        'Description (optional)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add details...',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_selectedCategory != null || _capturedImage != null || _capturedImageBytes != null) && !_isSubmitting
                              ? _submit
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade800,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Submit'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isSubmitting ? null : _openFullReport,
                        child: Text(
                          'More options → Full report form',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isSubmitting)
            Positioned.fill(
              child: UploadProgressOverlay(
                progress: _uploadProgress,
                stage: _uploadStage,
                showSuccess: _showSuccess,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraButton() {
    final hasImage = _capturedImage != null || _capturedImageBytes != null;
    return GestureDetector(
      onTap: _isSubmitting ? null : _pickImage,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: kIsWeb && _capturedImageBytes != null
                        ? Image.memory(_capturedImageBytes!, fit: BoxFit.cover)
                        : _capturedImage != null
                            ? Image.file(_capturedImage!, fit: BoxFit.cover)
                            : const SizedBox(),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() {
                        _capturedImage = null;
                        _capturedImageBytes = null;
                      }),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to take photo',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((cat) {
        final selected = _selectedCategory == cat;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = selected ? null : cat),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _primary : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              cat,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
