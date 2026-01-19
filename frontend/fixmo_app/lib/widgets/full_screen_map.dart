import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../models/report_model.dart';
import '../services/reports_service.dart';
import 'report_detail_card.dart';

/// Full-screen interactive map modal
class FullScreenMap extends StatefulWidget {
  final Position? userLocation;
  final List<ReportModel> reports;
  final String? selectedMunicipality;

  const FullScreenMap({
    super.key,
    this.userLocation,
    required this.reports,
    this.selectedMunicipality,
  });

  @override
  State<FullScreenMap> createState() => _FullScreenMapState();
}

class _FullScreenMapState extends State<FullScreenMap>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  ReportModel? _selectedReport;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeMap();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _slideController.forward();
    _fadeController.forward();
  }

  Future<void> _initializeMap() async {
    await _createMarkers();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _createMarkers() async {
    final Set<Marker> markers = {};

    // Add user location marker
    if (widget.userLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(
            widget.userLocation!.latitude,
            widget.userLocation!.longitude,
          ),
          icon: await _createCustomIcon(
            color: Colors.blue,
            isUserLocation: true,
          ),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'You are here',
          ),
        ),
      );
    }

    // Add report markers
    for (final report in widget.reports) {
      markers.add(
        Marker(
          markerId: MarkerId(report.id),
          position: LatLng(
            report.location.latitude,
            report.location.longitude,
          ),
          icon: await _createCustomIcon(
            color: report.isCurrentUser ? Colors.green : Colors.red,
            isUserLocation: false,
          ),
          infoWindow: InfoWindow(
            title: report.title,
            snippet: report.category,
          ),
          onTap: () => _onMarkerTapped(report),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<BitmapDescriptor> _createCustomIcon({
    required Color color,
    required bool isUserLocation,
  }) async {
    // For now, use default markers with different colors
    if (isUserLocation) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    } else if (color == Colors.green) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  void _onMarkerTapped(ReportModel report) {
    setState(() {
      _selectedReport = report;
    });
  }

  void _closeModal() {
    _slideController.reverse().then((_) {
      Navigator.of(context).pop();
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitMapToMarkers();
  }

  void _fitMapToMarkers() {
    if (_markers.isEmpty || _mapController == null) return;

    final bounds = _calculateBounds();
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  LatLngBounds _calculateBounds() {
    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;

    for (final marker in _markers) {
      minLat = math.min(minLat, marker.position.latitude);
      maxLat = math.max(maxLat, marker.position.latitude);
      minLng = math.min(minLng, marker.position.longitude);
      maxLng = math.max(maxLng, marker.position.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header with close button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Interactive Map',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.selectedMunicipality != null)
                              Text(
                                widget.selectedMunicipality!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: _closeModal,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                          ),
                          tooltip: 'Close map',
                        ),
                      ),
                    ],
                  ),
                ),

                // Map area
                Expanded(
                  child: Stack(
                    children: [
                      // Google Map
                      _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : GoogleMap(
                              onMapCreated: _onMapCreated,
                              initialCameraPosition: CameraPosition(
                                target: widget.userLocation != null
                                    ? LatLng(
                                        widget.userLocation!.latitude,
                                        widget.userLocation!.longitude,
                                      )
                                    : const LatLng(-20.2, 57.5), // Default to Mauritius center
                                zoom: 12.0,
                              ),
                              markers: _markers,
                              mapType: MapType.normal,
                              myLocationEnabled: true,
                              myLocationButtonEnabled: true,
                              zoomControlsEnabled: true,
                              mapToolbarEnabled: false,
                              onTap: (_) {
                                // Close report detail when tapping map
                                if (_selectedReport != null) {
                                  setState(() {
                                    _selectedReport = null;
                                  });
                                }
                              },
                            ),

                      // Report detail card overlay
                      if (_selectedReport != null)
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: ReportDetailCard(
                            report: _selectedReport!,
                            onClose: () {
                              setState(() {
                                _selectedReport = null;
                              });
                            },
                          ),
                        ),

                      // Map legend
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Legend',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildLegendItem(
                                color: Colors.blue,
                                label: 'Your Location',
                              ),
                              const SizedBox(height: 4),
                              _buildLegendItem(
                                color: Colors.green,
                                label: 'Your Reports',
                              ),
                              const SizedBox(height: 4),
                              _buildLegendItem(
                                color: Colors.red,
                                label: 'Other Reports',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
} 