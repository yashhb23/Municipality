import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:permission_handler/permission_handler.dart';
import '../config/app_config.dart';
import '../providers/app_state_provider.dart';
import '../services/location_service.dart';
import '../services/reports_service.dart';
import '../services/map_marker_service.dart';
import '../models/report_model.dart';
import '../widgets/report_detail_card.dart';
import '../widgets/bottom_sheet_incident_detail.dart';
import '../widgets/category_chips.dart';
import '../widgets/quick_report_modal.dart';
import '../widgets/advanced_filter_modal.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Home screen: full-screen map, right FABs, draggable bottom sheet, 5-tab nav.
/// All colors read from Theme.of(context) so light/dark themes work correctly.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<ReportModel> _filteredReports = [];
  bool _isLoading = true;
  int _selectedNavIndex = 0;
  ReportModel? _selectedReport;
  String? _selectedCategory;
  String? _darkMapStyleJson;

  // Search overlay state
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  Marker? _searchMarker;

  // My-reports-only toggle
  bool _showMyReportsOnly = false;

  // Advanced filter state
  Set<String> _statusFilters = {};
  String _dateRange = 'all';
  Set<String> _priorityFilters = {};
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    _loadDarkMapStyle();
    _initializeData();
  }

  Future<void> _loadDarkMapStyle() async {
    try {
      _darkMapStyleJson = await rootBundle.loadString('assets/map_styles/dark_map_style.json');
    } catch (_) {}
  }

  Future<void> _initializeData() async {
    await _loadReports();
    await _createMapMarkers();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadReports() async {
    final reportsService = context.read<ReportsService>();
    final appState = context.read<AppStateProvider>();
    if (appState.selectedMunicipality != null) {
      _filteredReports = reportsService.getReportsForMunicipality(appState.selectedMunicipality!);
    } else {
      _filteredReports = reportsService.allReports;
    }
  }

  /// Returns reports after applying all active filters:
  /// category chips, my-reports toggle, and advanced filters.
  List<ReportModel> get _reportsForMap {
    Iterable<ReportModel> results = _filteredReports;

    if (_selectedCategory != null) {
      results = results.where((r) => r.category == _selectedCategory);
    }
    if (_showMyReportsOnly) {
      results = results.where((r) => r.isCurrentUser);
    }
    if (_statusFilters.isNotEmpty) {
      results = results.where((r) => _statusFilters.contains(r.status));
    }
    if (_priorityFilters.isNotEmpty) {
      results = results.where((r) => _priorityFilters.contains(r.priority.toString()));
    }
    if (_dateRange != 'all') {
      final now = DateTime.now();
      final cutoff = switch (_dateRange) {
        '24h' => now.subtract(const Duration(hours: 24)),
        '7d' => now.subtract(const Duration(days: 7)),
        '30d' => now.subtract(const Duration(days: 30)),
        _ => DateTime(2000),
      };
      results = results.where((r) => r.createdAt.isAfter(cutoff));
    }
    if (_distanceKm != null) {
      final appState = context.read<AppStateProvider>();
      if (appState.currentPosition != null) {
        final userLat = appState.currentPosition!.latitude;
        final userLng = appState.currentPosition!.longitude;
        results = results.where((r) {
          final d = _haversineKm(userLat, userLng, r.location.latitude, r.location.longitude);
          return d <= _distanceKm!;
        });
      }
    }
    return results.toList();
  }

  /// Haversine distance in kilometres between two lat/lng pairs.
  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _deg2rad(double deg) => deg * (pi / 180);

  Future<void> _createMapMarkers() async {
    final Set<Marker> markers = {};
    final appState = context.read<AppStateProvider>();
    final reports = _reportsForMap;

    if (appState.currentPosition != null) {
      final icon = await MapMarkerService.getUserLocationMarker();
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(appState.currentPosition!.latitude, appState.currentPosition!.longitude),
          icon: icon,
          infoWindow: InfoWindow(title: 'Your Location', snippet: appState.selectedMunicipality ?? ''),
        ),
      );
    }

    for (final report in reports) {
      final icon = await MapMarkerService.getReportMarker(
        category: report.category,
        isCurrentUser: report.isCurrentUser,
      );
      markers.add(
        Marker(
          markerId: MarkerId(report.id),
          position: LatLng(report.location.latitude, report.location.longitude),
          icon: icon,
          infoWindow: InfoWindow(title: report.title, snippet: '${report.category} • ${report.timeAgo}'),
          onTap: () => _onReportTap(report),
        ),
      );
    }

    // Preserve search marker if present
    if (_searchMarker != null) markers.add(_searchMarker!);

    if (mounted) setState(() => _markers = markers);
  }

  void _onReportTap(ReportModel report) {
    setState(() => _selectedReport = report);
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(report.location.latitude, report.location.longitude)),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _applyMapStyle();
    _fitMapToMauritius();
  }

  /// Apply the dark map style only when the current theme is dark.
  void _applyMapStyle() {
    if (_mapController == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _mapController!.setMapStyle(isDark ? _darkMapStyleJson : null);
  }

  void _fitMapToMauritius() {
    if (_mapController == null) return;
    final bounds = LatLngBounds(
      southwest: const LatLng(-20.525, 57.3),
      northeast: const LatLng(-19.9, 57.8),
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      }
    });
  }

  void _recenterLocation() {
    final appState = context.read<AppStateProvider>();
    if (appState.currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(
          appState.currentPosition!.latitude,
          appState.currentPosition!.longitude,
        )),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyMapStyle();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: _selectedNavIndex == 1
                ? const HistoryScreen()
                : _selectedNavIndex == 2
                    ? const SettingsScreen()
                    : Stack(
                        children: [
                          _buildMap(),
                          _buildLocationBanner(cs),
                          _buildRightFABs(cs),
                          _buildBottomSheet(),
                          if (_showSearch) _buildSearchBar(cs),
                        ],
                      ),
          ),
          _buildBottomNav(cs),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final appState = context.watch<AppStateProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initialPosition = appState.currentPosition != null
        ? LatLng(appState.currentPosition!.latitude, appState.currentPosition!.longitude)
        : const LatLng(AppConfig.mauritiusLatitude, AppConfig.mauritiusLongitude);

    return Positioned.fill(
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: initialPosition, zoom: 12),
        onMapCreated: _onMapCreated,
        markers: _markers,
        mapType: MapType.normal,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        style: isDark ? _darkMapStyleJson : null,
      ),
    );
  }

  Widget _buildLocationBanner(ColorScheme cs) {
    final appState = context.watch<AppStateProvider>();
    final locationService = context.read<LocationService>();
    if (appState.isLocationPermissionGranted != false && !locationService.isUsingFallbackLocation) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 80,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: cs.surface.withOpacity(0.9),
        child: InkWell(
          onTap: () => openAppSettings(),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.location_off, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Enable location for better accuracy',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 12),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Settings', style: TextStyle(color: cs.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightFABs(ColorScheme cs) {
    final bool hasAdvancedFilters =
        _statusFilters.isNotEmpty || _priorityFilters.isNotEmpty || _dateRange != 'all' || _distanceKm != null;

    return Positioned(
      right: 16,
      top: 0,
      bottom: 80,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _fab(Icons.search, _toggleSearch, cs),
            const SizedBox(height: 12),
            _fab(
              Icons.person_outline,
              _toggleMyReports,
              cs,
              isActive: _showMyReportsOnly,
            ),
            const SizedBox(height: 12),
            _fab(Icons.my_location, _recenterLocation, cs),
            const SizedBox(height: 12),
            _fab(
              Icons.filter_list,
              _openAdvancedFilter,
              cs,
              isActive: hasAdvancedFilters,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fab(IconData icon, VoidCallback onPressed, ColorScheme cs, {bool isActive = false}) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(28),
      color: isActive ? cs.primary : cs.surface,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            icon,
            color: isActive ? cs.onPrimary : cs.onSurface.withOpacity(0.7),
            size: 24,
          ),
        ),
      ),
    );
  }

  // ── Search overlay ────────────────────────────────────────────────

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _searchMarker = null;
        _createMapMarkers();
      }
    });
  }

  Widget _buildSearchBar(ColorScheme cs) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        color: cs.surface,
        child: Row(
          children: [
            const SizedBox(width: 14),
            if (_isSearching)
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
            else
              Icon(Icons.search, color: cs.onSurface.withOpacity(0.5), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search address or place...',
                  hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.4)),
                  border: InputBorder.none,
                ),
                style: TextStyle(color: cs.onSurface),
                onSubmitted: _performSearch,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: cs.onSurface.withOpacity(0.5)),
              onPressed: _toggleSearch,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);

    try {
      final locations = await geo.locationFromAddress(query);
      if (locations.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No results found')),
          );
        }
        return;
      }

      final loc = locations.first;
      final target = LatLng(loc.latitude, loc.longitude);

      setState(() {
        _searchMarker = Marker(
          markerId: const MarkerId('search_result'),
          position: target,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(title: query),
        );
      });

      await _createMapMarkers();
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: ${e.toString().split(':').last.trim()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── My reports toggle ─────────────────────────────────────────────

  void _toggleMyReports() {
    setState(() => _showMyReportsOnly = !_showMyReportsOnly);
    _createMapMarkers();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_showMyReportsOnly ? 'Showing your reports only' : 'Showing all reports'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Advanced filter modal ─────────────────────────────────────────

  void _openAdvancedFilter() {
    final appState = context.read<AppStateProvider>();
    final hasLocation = appState.currentPosition != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdvancedFilterModal(
        statusFilters: _statusFilters,
        dateRange: _dateRange,
        priorityFilters: _priorityFilters,
        distanceKm: _distanceKm,
        hasUserLocation: hasLocation,
        onApply: (status, date, priority, distance) {
          setState(() {
            _statusFilters = status;
            _dateRange = date;
            _priorityFilters = priority;
            _distanceKm = distance;
          });
          _createMapMarkers();
        },
        onReset: () {
          setState(() {
            _statusFilters = {};
            _dateRange = 'all';
            _priorityFilters = {};
            _distanceKm = null;
          });
          _createMapMarkers();
        },
      ),
    );
  }

  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.25,
      minChildSize: 0.12,
      maxChildSize: 0.6,
      builder: (context, scrollController) {
        return BottomSheetIncidentDetail(
          scrollController: scrollController,
          report: _selectedReport,
          onViewDetails: _showFullReportDetail,
          selectedCategory: _selectedCategory,
          onCategoryChanged: (cat) {
            setState(() => _selectedCategory = cat);
            _createMapMarkers();
          },
          categories: CategoryChips.defaultCategories,
        );
      },
    );
  }

  void _showFullReportDetail(ReportModel report) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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

  Widget _buildBottomNav(ColorScheme cs) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(0, Icons.home_rounded, 'Home', cs),
          _navFAB(cs),
          _navItem(1, Icons.history, 'History', cs),
          _navItem(2, Icons.settings_outlined, 'Settings', cs),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, ColorScheme cs) {
    final isSelected = _selectedNavIndex == index;
    final color = isSelected ? cs.primary : cs.onSurface.withOpacity(0.4);
    return InkWell(
      onTap: () => setState(() => _selectedNavIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navFAB(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(28),
        color: cs.primary,
        child: InkWell(
          onTap: () {
            _openQuickReportModal();
          },
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.add, color: cs.onPrimary, size: 32),
          ),
        ),
      ),
    );
  }

  void _openQuickReportModal() {
    QuickReportModal.show(context);
  }
}
