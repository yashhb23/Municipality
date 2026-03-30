import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../config/app_config.dart';
import '../services/supabase_service.dart';
import '../services/backend_api_service.dart';
import '../services/location_service.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_provider.dart';
import '../models/report_model.dart';
import '../widgets/platform_image.dart';
import '../widgets/upload_progress_overlay.dart';
import '../utils/app_logger.dart';

/// Screen for creating new reports with camera and form
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedSpecificIssue;
  File? _capturedImage;
  Uint8List? _capturedImageBytes; // For web compatibility
  Position? _reportLocation;
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;
  String _uploadStage = '';
  bool _showSuccessAnimation = false;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Dark theme accent colors
  static const Color accentColor = Color(0xFF00D9A3); // Primary green
  static const Color secondaryAccent = Color(0xFF00B386); // Darker green
  static const Color warningAccent = Color(0xFFFF6B6B); // Coral red
  static const Color successAccent = Color(0xFF00D9A3); // Green

  // Categories: loaded from backend API, with hardcoded fallback.
  // Once the database has specific_issues seeded, the fallback can be removed.
  Map<String, Map<String, List<String>>> _problemCategories = {
    'Roads & Transport': {
      'Road Damage': [
        'Potholes', 
        'Cracks in Road', 
        'Road Surface Damage', 
        'Missing Road Markings',
        'Broken Curbs',
        'Uneven Road Surface'
      ],
      'Traffic Issues': [
        'Broken Traffic Lights', 
        'Missing Road Signs', 
        'Blocked Roads', 
        'Illegal Parking',
        'Damaged Traffic Signs',
        'Poor Road Visibility'
      ],
      'Public Transport': [
        'Bus Stop Damage', 
        'Missing Bus Shelter', 
        'Bus Route Issues', 
        'Taxi Stand Problems',
        'Public Transport Safety',
        'Accessibility Issues'
      ],
    },
    'Water & Drainage': {
      'Water Supply': [
        'No Water Supply', 
        'Low Water Pressure', 
        'Contaminated Water', 
        'Pipe Burst',
        'Water Meter Issues',
        'Public Tap Problems'
      ],
      'Drainage': [
        'Blocked Drains', 
        'Flooding', 
        'Sewage Overflow', 
        'Storm Water Issues',
        'Drain Cover Missing',
        'Poor Drainage System'
      ],
      'Waste Water': [
        'Sewage Problems', 
        'Septic Tank Issues', 
        'Water Pollution', 
        'Sewage Smell',
        'Waste Water Leaks',
        'Treatment Plant Issues'
      ],
    },
    'Waste Management': {
      'Collection': [
        'Missed Collection', 
        'Irregular Schedule', 
        'Overflowing Bins', 
        'Damaged Bins',
        'Collection Truck Issues',
        'Bin Placement Problems'
      ],
      'Illegal Dumping': [
        'Littering', 
        'Bulk Waste Dumping', 
        'Construction Waste', 
        'Hazardous Waste',
        'Roadside Dumping',
        'Private Property Dumping'
      ],
      'Recycling': [
        'No Recycling Bins', 
        'Full Recycling Bins', 
        'Recycling Issues', 
        'Sorting Problems',
        'Collection Schedule',
        'Recycling Education'
      ],
    },
    'Public Facilities': {
      'Parks & Recreation': [
        'Damaged Equipment', 
        'Unsafe Playground', 
        'Poor Maintenance', 
        'Vandalism',
        'Lighting Issues',
        'Security Concerns'
      ],
      'Public Buildings': [
        'Building Damage', 
        'Access Issues', 
        'Safety Concerns', 
        'Maintenance Needed',
        'Cleanliness Issues',
        'Facility Upgrades'
      ],
      'Public Toilets': [
        'Out of Order', 
        'Poor Hygiene', 
        'No Supplies', 
        'Vandalism',
        'Accessibility Issues',
        'Maintenance Required'
      ],
    },
    'Street Lighting': {
      'Lighting Issues': [
        'Street Light Out', 
        'Flickering Light', 
        'Damaged Light Pole', 
        'Insufficient Lighting',
        'Light Timing Issues',
        'Energy Efficiency'
      ],
      'Electrical': [
        'Exposed Wires', 
        'Electrical Hazard', 
        'Power Outage', 
        'Transformer Issues',
        'Cable Damage',
        'Safety Concerns'
      ],
    },
    'Environment': {
      'Pollution': [
        'Air Pollution', 
        'Noise Pollution', 
        'Water Pollution', 
        'Soil Contamination',
        'Industrial Pollution',
        'Vehicle Emissions'
      ],
      'Green Spaces': [
        'Tree Damage', 
        'Overgrown Vegetation', 
        'Dead Trees', 
        'Garden Maintenance',
        'Landscaping Issues',
        'Plant Disease'
      ],
      'Animals': [
        'Stray Animals', 
        'Dead Animals', 
        'Animal Nuisance', 
        'Wildlife Issues',
        'Pet Problems',
        'Animal Safety'
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadCategoriesFromApi();
  }

  /// Attempt to load categories from the backend API.
  /// Falls back silently to the hardcoded map if the API is unreachable.
  Future<void> _loadCategoriesFromApi() async {
    try {
      final api = BackendApiService();
      final categories = await api.getCategories();
      if (categories.isEmpty) return;

      final Map<String, Map<String, List<String>>> fetched = {};
      for (final cat in categories) {
        final catName = cat['name'] as String? ?? '';
        final subs = cat['subcategories'] as List<dynamic>? ?? [];
        final Map<String, List<String>> subMap = {};
        for (final sub in subs) {
          final subName = sub['name'] as String? ?? '';
          // specific_issues not yet seeded in DB — empty list is fine
          subMap[subName] = [];
        }
        if (subMap.isNotEmpty) {
          fetched[catName] = subMap;
        }
      }

      if (fetched.isNotEmpty && mounted) {
        setState(() => _problemCategories = fetched);
        AppLogger.debug('Categories loaded from backend API');
      }
    } catch (e) {
      AppLogger.debug('Backend categories unavailable, using hardcoded fallback');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationService = context.read<LocationService>();
      final position = await locationService.getCurrentLocation();
      setState(() {
        _reportLocation = position;
      });
      
      // Update location controller with approximate address
      if (position != null) {
        final appState = context.read<AppStateProvider>();
        _locationController.text = appState.selectedMunicipality ?? 'Current Location';
      }
    } catch (e) {
      AppLogger.error('Error getting location', e);
      // Use app state location as fallback
      final appState = context.read<AppStateProvider>();
      setState(() {
        _reportLocation = appState.currentPosition;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add Photo Evidence',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildPhotoOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      color: accentColor,
                      onTap: () async {
                        Navigator.pop(context);
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 80,
                        );
                        if (image != null) {
                          await _handleImageSelected(image);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Camera access denied. You can enable it in Settings.'),
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPhotoOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      color: secondaryAccent,
                      onTap: () async {
                        Navigator.pop(context);
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (image != null) {
                          await _handleImageSelected(image);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Gallery access denied. You can enable it in Settings.'),
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  /// Handle image selection for both web and mobile platforms
  Future<void> _handleImageSelected(XFile image) async {
    try {
      if (kIsWeb) {
        // On web, read as bytes
        final bytes = await image.readAsBytes();
        setState(() {
          _capturedImageBytes = bytes;
          _capturedImage = null; // Clear file reference
        });
      } else {
        // On mobile, use file
        setState(() {
          _capturedImage = File(image.path);
          _capturedImageBytes = null; // Clear bytes reference
        });
      }
      AppLogger.debug('Image selected (${kIsWeb ? 'web' : 'mobile'} mode)');
    } catch (e) {
      AppLogger.error('Error handling selected image', e);
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Color _getCategoryColor(int index) {
    final colors = [
      accentColor,
      secondaryAccent,
      warningAccent,
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFF9C27B0), // Purple
    ];
    return colors[index % colors.length];
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Roads & Transport': return Icons.directions_car;
      case 'Water & Drainage': return Icons.water_drop;
      case 'Waste Management': return Icons.delete;
      case 'Public Facilities': return Icons.business;
      case 'Street Lighting': return Icons.lightbulb;
      case 'Environment': return Icons.eco;
      default: return Icons.report_problem;
    }
  }

  IconData _getSubcategoryIcon(String subcategory) {
    switch (subcategory) {
      case 'Road Damage': return Icons.construction;
      case 'Traffic Issues': return Icons.traffic;
      case 'Public Transport': return Icons.directions_bus;
      case 'Water Supply': return Icons.water;
      case 'Drainage': return Icons.water_damage;
      case 'Waste Water': return Icons.waves;
      case 'Collection': return Icons.delete_outline;
      case 'Illegal Dumping': return Icons.warning;
      case 'Recycling': return Icons.recycling;
      case 'Parks & Recreation': return Icons.park;
      case 'Public Buildings': return Icons.apartment;
      case 'Public Toilets': return Icons.wc;
      case 'Lighting Issues': return Icons.light;
      case 'Electrical': return Icons.electrical_services;
      case 'Pollution': return Icons.cloud;
      case 'Green Spaces': return Icons.grass;
      case 'Animals': return Icons.pets;
      default: return Icons.help_outline;
    }
  }

  void _submitReport() async {
    if (_isSubmitting) return;
    
    // Check internet connection first
    final supabaseService = context.read<SupabaseService>();
    final hasConnection = await supabaseService.hasInternetConnection();
    
    if (!hasConnection && mounted) {
      _showRetryDialog('No internet connection. Please check your network and try again.');
      return;
    }
    
    // Add haptic feedback
    HapticFeedback.mediumImpact();
    
    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
      _uploadStage = 'Preparing...';
      _showSuccessAnimation = false;
    });

    try {
      // Get current location if not already available
      setState(() {
        _uploadProgress = 0.1;
        _uploadStage = 'Getting location...';
      });
      
      if (_reportLocation == null) {
        await _getCurrentLocation();
      }

      // Get municipality from app state
      final appState = context.read<AppStateProvider>();
      final municipality = appState.selectedMunicipality ?? 'Unknown';

      // Upload image first if available
      String? imageUrl;
      if (_capturedImage != null || _capturedImageBytes != null) {
        try {
          setState(() {
            _uploadProgress = 0.15;
            _uploadStage = 'Optimizing image...';
          });
          
          // Compress image before upload for faster speeds
          dynamic compressedImage;
          if (kIsWeb && _capturedImageBytes != null) {
            // Web: Compress bytes
            compressedImage = await _compressImageBytes(_capturedImageBytes!);
            AppLogger.debug('Image compressed for web upload');
          } else if (!kIsWeb && _capturedImage != null) {
            // Mobile: Compress file
            compressedImage = await _compressImageFile(_capturedImage!);
            AppLogger.debug('Image compressed for mobile upload');
          }
          
          setState(() {
            _uploadProgress = 0.3;
            _uploadStage = 'Uploading image...';
          });
          
          // Generate temporary report ID for image upload
          final tempReportId = DateTime.now().millisecondsSinceEpoch.toString();
          
          if (kIsWeb && compressedImage is Uint8List) {
            // Web: Upload compressed bytes
            imageUrl = await supabaseService.uploadImage(compressedImage, tempReportId);
            AppLogger.debug('Image uploaded (web)');
          } else if (!kIsWeb && compressedImage is File) {
            imageUrl = await supabaseService.uploadImage(compressedImage, tempReportId);
            AppLogger.debug('Image uploaded (mobile)');
          }
          
          setState(() {
            _uploadProgress = 0.6;
          });
        } catch (e) {
          AppLogger.error('Image upload failed', e);
          if (mounted) {
            _showRetryDialog('Image upload failed: ${e.toString()}');
            return;
          }
        }
      }

      // Submit report via backend API, fall back to direct Supabase insert
      setState(() {
        _uploadProgress = 0.7;
        _uploadStage = 'Saving report...';
      });

      final authProvider = context.read<AuthProvider>();
      final backendApi = BackendApiService();
      final loc = _reportLocation;

      final reportTitle = _selectedSpecificIssue ?? _selectedSubcategory ?? 'Issue Report';
      final reportDesc = _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : 'No additional details provided';
      final reportCategory = _selectedCategory ?? 'General';
      final reportLat = loc?.latitude ?? AppConfig.mauritiusLatitude;
      final reportLng = loc?.longitude ?? AppConfig.mauritiusLongitude;
      final reportAddress = _locationController.text.isNotEmpty
          ? _locationController.text
          : '$municipality, Mauritius';

      Map<String, dynamic> createdReport;
      try {
        createdReport = await backendApi.createReport(
          title: reportTitle,
          description: reportDesc,
          category: reportCategory,
          subcategory: _selectedSubcategory,
          municipality: municipality,
          latitude: reportLat,
          longitude: reportLng,
          address: reportAddress,
          imageUrl: imageUrl,
          accessToken: authProvider.accessToken,
        );
      } on SocketException catch (_) {
        AppLogger.debug('Backend unreachable, falling back to direct Supabase insert');
        if (mounted) setState(() => _uploadStage = 'Saving report (offline)...');
        createdReport = await supabaseService.createReportDirect(
          title: reportTitle,
          description: reportDesc,
          category: reportCategory,
          subcategory: _selectedSubcategory,
          municipality: municipality,
          latitude: reportLat,
          longitude: reportLng,
          address: reportAddress,
          imageUrl: imageUrl,
          userId: authProvider.user?.id,
        );
      } on TimeoutException catch (_) {
        AppLogger.debug('Backend timed out, falling back to direct Supabase insert');
        if (mounted) setState(() => _uploadStage = 'Saving report (offline)...');
        createdReport = await supabaseService.createReportDirect(
          title: reportTitle,
          description: reportDesc,
          category: reportCategory,
          subcategory: _selectedSubcategory,
          municipality: municipality,
          latitude: reportLat,
          longitude: reportLng,
          address: reportAddress,
          imageUrl: imageUrl,
          userId: authProvider.user?.id,
        );
      }

      final reportId = createdReport['id']?.toString() ?? '';
      AppLogger.debug('Report saved with ID: $reportId');

      // Show success animation
      setState(() {
        _uploadProgress = 1.0;
        _uploadStage = 'Success!';
        _showSuccessAnimation = true;
      });
      
      // Success haptic feedback
      HapticFeedback.heavyImpact();
      
      // Wait for animation
      await Future.delayed(const Duration(milliseconds: 1500));

      // Show success screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ReportSuccessScreen(reportId: reportId),
          ),
        );
      }

    } catch (e) {
      AppLogger.error('Error submitting report', e);
      
      // Show retry dialog
      if (mounted) {
        _showRetryDialog('Failed to submit report: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showRetryDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RetryDialog(
        errorMessage: errorMessage,
        onRetry: () {
          Navigator.pop(context);
          _submitReport();
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  int _getPriorityFromCategory(String category) {
    switch (category.toLowerCase()) {
      case 'street lighting':
      case 'water & drainage':
        return 3; // High priority
      case 'roads & transport':
      case 'public facilities':
        return 2; // Medium priority
      default:
        return 1; // Low priority
    }
  }

  /// Compress image file for faster upload (mobile)
  Future<File> _compressImageFile(File file) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf('.');
    final outPath = '${filePath.substring(0, lastIndex)}_compressed.jpg';
    
    final result = await FlutterImageCompress.compressAndGetFile(
      filePath,
      outPath,
      quality: 85, // Good balance between quality and size
      minWidth: 1920,
      minHeight: 1080,
      format: CompressFormat.jpeg,
    );
    
    if (result != null) {
      final originalSize = await file.length();
      final compressedSize = await result.length();
      final savings = ((originalSize - compressedSize) / originalSize * 100).toStringAsFixed(1);
      AppLogger.debug('Image compressed: ${(originalSize / 1024).toStringAsFixed(0)}KB -> ${(compressedSize / 1024).toStringAsFixed(0)}KB ($savings% saved)');
      return File(result.path);
    }
    
    return file; // Return original if compression fails
  }

  /// Compress image bytes for faster upload (web)
  Future<Uint8List> _compressImageBytes(Uint8List bytes) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      quality: 85,
      minWidth: 1920,
      minHeight: 1080,
      format: CompressFormat.jpeg,
    );
    
    final savings = ((bytes.length - result.length) / bytes.length * 100).toStringAsFixed(1);
    AppLogger.debug('Image compressed: ${(bytes.length / 1024).toStringAsFixed(0)}KB -> ${(result.length / 1024).toStringAsFixed(0)}KB ($savings% saved)');
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _selectedCategory != null
        ? _getCategoryColor(_problemCategories.keys.toList().indexOf(_selectedCategory ?? ''))
        : Theme.of(context).colorScheme.primary;

    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: cs.surface,
            elevation: 0,
            title: Text(
              'Create Report',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: cs.onSurface.withOpacity(0.7)),
            ),
          ),
          body: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo Upload Card
                _buildPhotoUploadCard(),
                const SizedBox(height: 20),
                
                // Category Selection
                _buildCategorySelection(),
                const SizedBox(height: 20),
                
                // Subcategory (if category selected)
                if (_selectedCategory != null) ...[
                  _buildSubcategorySelection(),
                  const SizedBox(height: 20),
                ],
                
                // Specific Issue (if subcategory selected)
                if (_selectedSubcategory != null) ...[
                  _buildSpecificIssueSelection(),
                  const SizedBox(height: 20),
                ],
                
                // Description & Location
                if (_selectedSpecificIssue != null) ...[
                  _buildDetailsForm(),
                  const SizedBox(height: 100), // Space for bottom button
                ],
              ],
            ),
          ),
          // Fixed bottom submit button
          bottomNavigationBar: _buildSubmitButton(),
        ),
        // Upload progress overlay
        if (_isSubmitting)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: UploadProgressOverlay(
                progress: _uploadProgress,
                stage: _uploadStage,
                showSuccess: _showSuccessAnimation,
              ),
            ),
          ),
      ],
    );
  }

  bool _canSubmit() {
    return _selectedCategory != null &&
           _selectedSubcategory != null &&
           _selectedSpecificIssue != null;
    // Photo is now optional
  }

  Widget _buildSubmitButton() {
    final canSubmit = _canSubmit() && !_isSubmitting;
    final categoryColor = _selectedCategory != null
        ? _getCategoryColor(_problemCategories.keys.toList().indexOf(_selectedCategory ?? ''))
        : accentColor;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: AnimatedScale(
          scale: canSubmit ? 1.0 : 0.98,
          duration: const Duration(milliseconds: 150),
          child: ElevatedButton(
            onPressed: canSubmit ? () {
              HapticFeedback.mediumImpact();
              _submitReport();
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: categoryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: canSubmit ? 4 : 0,
              shadowColor: categoryColor.withOpacity(0.4),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text(
                    'Submit Report',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoUploadCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.camera_alt, color: accentColor, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Add Photo (Optional)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12, width: 1.5),
              ),
              child: (_capturedImage != null || _capturedImageBytes != null)
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: PlatformImage(
                            file: _capturedImage,
                            bytes: _capturedImageBytes,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                _capturedImage = null;
                                _capturedImageBytes = null;
                              });
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : InkWell(
                      onTap: _takePicture,
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_a_photo,
                              size: 32,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to add photo',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Camera or Gallery',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: accentColor, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Select Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _problemCategories.keys.map((category) {
              final index = _problemCategories.keys.toList().indexOf(category);
              final isSelected = _selectedCategory == category;
              final categoryColor = _getCategoryColor(index);
              
              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedCategory = category;
                    _selectedSubcategory = null;
                    _selectedSpecificIssue = null;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? categoryColor.withOpacity(0.2)
                        : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? categoryColor
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getCategoryIcon(category),
                        color: isSelected ? categoryColor : Colors.grey.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? categoryColor : Colors.grey.shade300,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategorySelection() {
    if (_selectedCategory == null) return const SizedBox.shrink();
    
    final subcategories = _problemCategories[_selectedCategory]!.keys.toList();
    final categoryColor = _getCategoryColor(
      _problemCategories.keys.toList().indexOf(_selectedCategory!),
    );
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: categoryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select Subcategory',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...subcategories.map((subcategory) {
            final isSelected = _selectedSubcategory == subcategory;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedSubcategory = subcategory;
                    _selectedSpecificIssue = null;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? categoryColor.withOpacity(0.2)
                        : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? categoryColor
                          : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getSubcategoryIcon(subcategory),
                        color: isSelected ? categoryColor : Colors.grey.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          subcategory,
                          style: TextStyle(
                            color: isSelected ? categoryColor : Colors.grey.shade300,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: categoryColor,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSpecificIssueSelection() {
    if (_selectedCategory == null || _selectedSubcategory == null) {
      return const SizedBox.shrink();
    }
    
    final specificIssues = _problemCategories[_selectedCategory]![_selectedSubcategory]!;
    final categoryColor = _getCategoryColor(
      _problemCategories.keys.toList().indexOf(_selectedCategory!),
    );
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem, color: categoryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Specific Issue',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...specificIssues.map((issue) {
            final isSelected = _selectedSpecificIssue == issue;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedSpecificIssue = issue;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? categoryColor.withOpacity(0.2)
                        : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? categoryColor
                          : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isSelected ? categoryColor : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? categoryColor : Colors.grey.shade400,
                            width: 2,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          issue,
                          style: TextStyle(
                            color: isSelected ? categoryColor : Colors.grey.shade300,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDetailsForm() {
    final categoryColor = _getCategoryColor(
      _problemCategories.keys.toList().indexOf(_selectedCategory!),
    );
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: categoryColor, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Additional Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Description field — capped to prevent abuse
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            maxLength: AppConfig.maxReportDescriptionLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            style: const TextStyle(fontSize: 16, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Describe the issue in more detail... (Optional)',
              counterStyle: TextStyle(color: Colors.grey.shade500),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: categoryColor, width: 2),
              ),
              hintStyle: TextStyle(color: Colors.grey.shade500),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Location field
          TextField(
            controller: _locationController,
            style: const TextStyle(fontSize: 16, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Specific location (Optional)',
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              prefixIcon: Icon(Icons.location_on, color: categoryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: categoryColor, width: 2),
              ),
              hintStyle: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Success screen shown after report submission
class ReportSuccessScreen extends StatelessWidget {
  const ReportSuccessScreen({super.key, required this.reportId});

  final String reportId;

  static const Color _primary = Color(0xFF00D9A3);
  static const Color _bg = Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success animation placeholder
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: _primary,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Success message
              Text(
                'Report Submitted!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Thank you for helping improve our community.\nWe\'ll review your report and take action.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade300,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Action buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/home',
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/history');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'View My Reports',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 