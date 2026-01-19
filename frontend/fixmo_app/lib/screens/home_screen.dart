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
      backgroundColor: Colors.grey[50],
      body: Consumer2<AppStateProvider, ReportsService>(
        builder: (context, appState, reportsService, child) {
          return SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  // 1. Modern header with neutral message
                  SliverToBoxAdapter(
                    child: _buildModernHeader(appState),
                  ),
                  
                  // 2. MAP - Moved here from community section
                  SliverToBoxAdapter(
                    child: _buildCompactMapSection(appState),
                  ),
                  
                  // 3. Overview Section Header
                  SliverToBoxAdapter(
                    child: _buildSectionHeader('Overview', 'Your submitted reports', 0),
                  ),
                  
                  // 4. My Reports horizontal scroll
                  SliverToBoxAdapter(
                    child: _buildMyReportsSection(),
                  ),
                  
                  // 5. Community Reports Section Header
                  SliverToBoxAdapter(
                    child: _buildSectionHeader('Community Reports', 'All municipality reports', 1),
                  ),
                  
                  // 6. Community reports grid (NO MAP - map is now at top)
                  _isLoading
                      ? const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        )
                      : _filteredReports.isEmpty
                          ? SliverToBoxAdapter(child: _buildEmptyState())
                          : SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.8,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    return _buildReportCard(_filteredReports[index]);
                                  },
                                  childCount: _filteredReports.length,
                                ),
                              ),
                            ),
                  
                  // Bottom padding for circular button
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                            ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildCircularBottomNav(),
    );
  }

  Widget _buildModernHeader(AppStateProvider appState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Neutral message
          Text(
            'What would you like to report?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Help improve your community',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          
          // Municipality selector
          const MunicipalitySelector(),
          
          const SizedBox(height: 16),
          
          // Stats row
          Row(
            children: [
              _buildStatChip(
                icon: Icons.assignment,
                label: '${_userReports.length}',
                subtitle: 'Your Reports',
                color: const Color(0xFF6C63FF),
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                icon: Icons.people,
                label: '${_filteredReports.length}',
                subtitle: 'Community',
                color: const Color(0xFF4ECDC4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
              ),
            const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                        fontWeight: FontWeight.bold,
                      color: color,
                      ),
                    ),
                      Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, int sectionIndex) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyReportsSection() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_userReports.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No reports yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first report to help improve your community',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _userReports.length,
        itemBuilder: (context, index) {
          return Container(
            width: 300,
            margin: EdgeInsets.only(right: index < _userReports.length - 1 ? 12 : 0),
            child: _buildHorizontalReportCard(_userReports[index]),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalReportCard(ReportModel report) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReportDetails(report),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // Image
              Container(
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                child: report.imageUrls.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                        child: Image.network(
                          report.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            report.categoryIcon,
                            color: Theme.of(context).primaryColor,
                            size: 40,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          report.categoryIcon,
                          color: Theme.of(context).primaryColor,
                          size: 40,
                        ),
                      ),
              ),
              
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                          color: report.statusColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                          report.status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.category,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            report.timeAgo,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                ),
              ),
            ],
          ),
                    ],
                  ),
                ),
              ),
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMapSection(AppStateProvider appState) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Google Map
            _isLoading
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
                      zoom: 11.0,
                    ),
                    markers: _markers,
                    mapType: MapType.normal,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    onTap: (_) => _openFullScreenMap(),
                  ),

            // Fullscreen button overlay
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _openFullScreenMap,
                  icon: const Icon(Icons.fullscreen, color: Color(0xFF6C63FF)),
                      tooltip: 'Expand map',
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 10,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }


  Widget _buildReportCard(ReportModel report) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: report.isCurrentUser 
            ? Border.all(color: Colors.green, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReportDetails(report),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (report.imageUrls.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          child: Image.network(
                            report.imageUrls.first,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              report.categoryIcon,
                              color: Theme.of(context).primaryColor,
                              size: 32,
                            ),
                          ),
                        )
                      else
                        Center(
                          child: Icon(
                            report.categoryIcon,
                            color: Theme.of(context).primaryColor,
                            size: 32,
                          ),
                        ),
                      
                      // Status badge
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: report.statusColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            report.status.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      
                      // User indicator
                      if (report.isCurrentUser)
                        const Positioned(
                          top: 8,
                          left: 8,
                          child: Icon(
                            Icons.star,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Content
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.category,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              report.timeAgo,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                const SizedBox(width: 60), // Space for circular button
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
        // Circular floating button (centered, elevated)
        Positioned(
          top: -28,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, '/report');
                },
                borderRadius: BorderRadius.circular(28),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
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