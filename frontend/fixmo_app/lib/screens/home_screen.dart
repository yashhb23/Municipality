import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/app_state_provider.dart';
import '../services/location_service.dart';
import '../services/reports_service.dart';
import '../services/map_marker_service.dart';
import '../models/report_model.dart';
import '../widgets/municipality_selector.dart';
import '../widgets/full_screen_map.dart';
import '../widgets/report_detail_card.dart';

/// Modern responsive home screen with interactive map and reports
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<ReportModel> _filteredReports = [];
  List<ReportModel> _userReports = [];
  bool _isLoading = true;
  int _selectedNavIndex = 0;
  int _selectedSectionIndex = 0; // 0 = Overview, 1 = Community Reports
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeData();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    _fadeController.forward();
  }

  Future<void> _initializeData() async {
    await _loadReports();
    await _createMapMarkers();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadReports() async {
    final reportsService = context.read<ReportsService>();
    final appState = context.read<AppStateProvider>();
    
    if (appState.selectedMunicipality != null) {
      _filteredReports = reportsService.getReportsForMunicipality(
        appState.selectedMunicipality!,
      );
    } else {
      _filteredReports = reportsService.allReports;
    }
    
    // Filter user's own reports
    _userReports = _filteredReports.where((report) => report.isCurrentUser).toList();
    
    print('📊 Loaded ${_filteredReports.length} total reports (${_userReports.length} yours)');
  }

  Future<void> _createMapMarkers() async {
    final Set<Marker> markers = {};
    final appState = context.read<AppStateProvider>();

    // Add user location marker with custom red marker
    if (appState.currentPosition != null) {
      final userLocationIcon = await MapMarkerService.getUserLocationMarker();
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(
            appState.currentPosition!.latitude,
            appState.currentPosition!.longitude,
          ),
          icon: userLocationIcon,
          infoWindow: InfoWindow(
            title: 'Your Location',
            snippet: appState.selectedMunicipality ?? 'Current Position',
          ),
        ),
      );
    }

    // Add municipality markers
    final municipalities = [
      {'name': 'Port Louis', 'lat': -20.1669, 'lng': 57.5009},
      {'name': 'Curepipe', 'lat': -20.3167, 'lng': 57.5167},
      {'name': 'Quatre Bornes', 'lat': -20.2658, 'lng': 57.4789},
      {'name': 'Beau Bassin-Rose Hill', 'lat': -20.2500, 'lng': 57.4700},
      {'name': 'Vacoas-Phoenix', 'lat': -20.2986, 'lng': 57.4947},
      {'name': 'Mahébourg', 'lat': -20.4081, 'lng': 57.7000},
      {'name': 'Centre de Flacq', 'lat': -20.2013, 'lng': 57.7181},
      {'name': 'Goodlands', 'lat': -20.0375, 'lng': 57.6419},
      {'name': 'Triolet', 'lat': -20.0569, 'lng': 57.5475},
      {'name': 'Saint Pierre', 'lat': -20.2181, 'lng': 57.5206},
    ];

    final municipalityIcon = await MapMarkerService.getMunicipalityMarker();
    for (final municipality in municipalities) {
      markers.add(
        Marker(
          markerId: MarkerId('municipality_${municipality['name']}'),
          position: LatLng(municipality['lat'] as double, municipality['lng'] as double),
          icon: municipalityIcon,
          infoWindow: InfoWindow(
            title: municipality['name'] as String,
            snippet: 'Municipality',
          ),
        ),
      );
    }

    // Add report markers with custom icons
    for (final report in _filteredReports) {
      final reportIcon = await MapMarkerService.getReportMarker(
        category: report.category,
        status: report.status,
        isCurrentUser: report.isCurrentUser,
      );

      markers.add(
        Marker(
          markerId: MarkerId(report.id),
          position: LatLng(
            report.location.latitude,
            report.location.longitude,
          ),
          icon: reportIcon,
          infoWindow: InfoWindow(
            title: report.title,
            snippet: '${report.category} • ${report.timeAgo}',
          ),
          onTap: () => _showReportDetails(report),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _showReportDetails(ReportModel report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: ReportDetailCard(
              report: report,
              onClose: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    );
  }

  void _openFullScreenMap() {
    final appState = context.read<AppStateProvider>();
    
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => FullScreenMap(
          userLocation: appState.currentPosition,
          reports: _filteredReports,
          selectedMunicipality: appState.selectedMunicipality,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitMapToMauritius();
  }

  void _fitMapToMauritius() {
    if (_mapController == null) return;

    // Focus on Mauritius with proper bounds
    final mauritiusBounds = LatLngBounds(
      southwest: LatLng(-20.525, 57.3),
      northeast: LatLng(-19.9, 57.8),
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(mauritiusBounds, 50.0),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Consumer2<AppStateProvider, ReportsService>(
        builder: (context, appState, reportsService, child) {
          return Stack(
            children: [
              // 1. Full Screen Map Layer (Background)
              Positioned.fill(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: CameraPosition(
                          target: appState.currentPosition != null
                              ? LatLng(
                                  appState.currentPosition!.latitude,
                                  appState.currentPosition!.longitude,
                                )
                              : const LatLng(-20.2, 57.5),
                          zoom: 12.0,
                        ),
                        markers: _markers,
                        mapType: MapType.normal,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        onTap: (_) {
                          // TODO: Minimize sheet on map tap
                          // For now, focus can return to map
                        },
                      ),
              ),

              // 2. Floating Top Header & Search
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Find reports in ${appState.selectedMunicipality ?? "all Mauritus"}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
                                child: const Icon(Icons.person, size: 20, color: Color(0xFF6C63FF)),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Categories / Municipality Filter Pills
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildPill(appState.selectedMunicipality ?? 'All Areas', true, () {
                                // Trigger municipality selector
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  builder: (context) => const Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: MunicipalitySelector(), // Assuming this widget handles UI
                                  ),
                                );
                              }),
                              const SizedBox(width: 8),
                              _buildPill('My Reports', false, () {
                                // Filter logic
                              }),
                              const SizedBox(width: 8),
                              _buildPill('Pending', false, () {}),
                              const SizedBox(width: 8),
                              _buildPill('Resolved', false, () {}),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Draggable Bottom Sheet for Reports
              DraggableScrollableSheet(
                initialChildSize: 0.3,
                minChildSize: 0.2,
                maxChildSize: 0.9,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: -2,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 8),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        
                        // Sheet Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Reports',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  // Expand sheet
                                },
                                child: const Text('See All'),
                              ),
                            ],
                          ),
                        ),

                        // List Content
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _filteredReports.length,
                                  itemBuilder: (context, index) {
                                    final report = _filteredReports[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: _buildModernReportCard(report),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),


            ],
          );
        },
      ),
      bottomNavigationBar: _buildCircularBottomNav(),
    );
  }

  Widget _buildPill(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isActive)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildModernReportCard(ReportModel report) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showReportDetails(report),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                 // Image Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[100],
                    child: report.imageUrls.isNotEmpty
                        ? Image.network(
                            report.imageUrls.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(report.categoryIcon, color: Colors.grey),
                          )
                        : Icon(report.categoryIcon, color: const Color(0xFF6C63FF), size: 30),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: report.statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              report.statusDisplay.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: report.statusColor,
                              ),
                            ),
                          ),
                          Text(
                            report.timeAgo,
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.address.isNotEmpty ? report.address : report.municipality,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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


  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Reports Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to report an issue in your municipality!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularBottomNav() {
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        // Bottom nav bar
        Container(
          height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: _selectedNavIndex == 0,
                onTap: () {
                  setState(() {
                    _selectedNavIndex = 0;
                  });
                },
              ),
              _buildNavItem(
                icon: Icons.add_circle_outline_rounded,
                label: 'Report',
                isSelected: false, // Always acts as a button
                onTap: () {
                  Navigator.pushNamed(context, '/report');
                },
              ),
              _buildNavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isSelected: _selectedNavIndex == 2,
                onTap: () {
                  setState(() {
                    _selectedNavIndex = 2;
                  });
                  Navigator.pushNamed(context, '/settings');
                },
              ),
            ],
          ),
        ),
      ),

      ],
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = isSelected ? const Color(0xFF6C63FF) : Colors.grey[400];
            
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 