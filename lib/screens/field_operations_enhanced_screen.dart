// lib/screens/field_operations_enhanced_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/site_visit.dart';
import '../models/visit_status.dart';
import '../services/site_visit_service.dart';
import '../services/auth_service.dart';
import '../services/location_tracking_service.dart';
import '../services/sync_manager.dart';
import '../theme/app_colors.dart';
import '../widgets/app_menu_overlay.dart';
import '../widgets/modern_app_header.dart';
import '../widgets/modern_card.dart';
import 'components/report_form_sheet.dart';
import 'components/visit_assignment_sheet.dart';
import 'components/visit_details_sheet.dart';

class FieldOperationsEnhancedScreen extends StatefulWidget {
  const FieldOperationsEnhancedScreen({super.key});

  @override
  State<FieldOperationsEnhancedScreen> createState() =>
      _FieldOperationsEnhancedScreenState();
}

class _FieldOperationsEnhancedScreenState
    extends State<FieldOperationsEnhancedScreen> {
  // UI state
  bool _showMenu = false;
  bool _isLoading = true;
  bool _isSyncing = false;

  // Map controller
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};

  // Services
  final LocationTrackingService _locationService = LocationTrackingService();
  final SiteVisitService _siteVisitService = SiteVisitService();
  final AuthService _authService = AuthService();
  final SyncManager _syncManager = SyncManager();

  // Location
  LatLng _currentLocation = const LatLng(
    12.8628,
    30.2176,
  ); // Default center on Sudan

  // Visit data
  List<SiteVisit> _availableVisits = [];
  List<SiteVisit> _myVisits = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize location tracking
    _initializeLocationTracking();

    // Initialize repository and sync manager
    _initializeServices();

    // Load visits
    _loadVisits();
  }

  @override
  void dispose() {
    super.dispose();
  }


  // Initialize location tracking
  Future<void> _initializeLocationTracking() async {
    try {
      await _locationService.initialize();
      _getCurrentLocation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing location: $e')),
        );
      }
    }
  }

  // Initialize services
  Future<void> _initializeServices() async {
    try {
      await _syncManager.initialize();
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      _updateMapCamera();
      _updateMarkers();
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  // Update map camera
  Future<void> _updateMapCamera() async {
    if (!_mapController.isCompleted) return;

    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation, 15));
  }

  // Update map markers
  void _updateMarkers() {
    final markers = <Marker>{};

    // Add current location marker
    markers.add(
      Marker(
        markerId: const MarkerId('currentLocation'),
        position: _currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'You are here',
        ),
      ),
    );

    // Add visit markers
    for (final visit in [..._availableVisits, ..._myVisits]) {
      if (visit.latitude != null && visit.longitude != null) {
        markers.add(
          Marker(
            markerId: MarkerId(visit.id),
            position: LatLng(visit.latitude!, visit.longitude!),
            icon: _getMarkerIcon(visit.status),
            infoWindow: InfoWindow(
              title: visit.siteName ?? 'Unnamed Site',
              snippet: visit.locationString.isNotEmpty
                  ? visit.locationString
                  : 'No location specified',
            ),
            onTap: () => _selectVisit(visit),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  // Get marker icon based on visit status
  BitmapDescriptor _getMarkerIcon(String status) {
    switch (visitStatusFromString(status)) {
      case VisitStatus.pending:
      case VisitStatus.available:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case VisitStatus.assigned:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        );
      case VisitStatus.inProgress:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      case VisitStatus.completed:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case VisitStatus.rejected:
      case VisitStatus.cancelled:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
    }
  }

  // Load visits from Supabase
  Future<void> _loadVisits() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final visitData = await _siteVisitService.getAssignedSiteVisits(userId);
      final visits = visitData.map((data) => SiteVisit.fromJson(data)).toList();

      if (mounted) {
        setState(() {
          _availableVisits = visits;
          _myVisits = visits.where((v) => v.assignedTo == userId).toList();
          _isLoading = false;
        });
      }

      _updateMarkers();
    } catch (e) {
      debugPrint('Error loading visits: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading visits: $e')));
      }
    }
  }

  // This method is no longer needed since we're using real data
  Future<void> _generateExampleVisits() async {
    // Implementation removed as we now use real data from Supabase
    await _loadVisits();
  }

  // Select a visit
  void _selectVisit(SiteVisit visit) {
    // Show visit details bottom sheet directly
    _showVisitDetailsSheet(visit);
  }

  // Show visit details sheet
  void _showVisitDetailsSheet(SiteVisit visit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VisitDetailsSheet(
        visit: visit,
        onStatusChanged: (newStatus) =>
            _handleVisitStatusChanged(visit, newStatus),
      ),
    );
  }

  // Handle visit status changes
  Future<void> _handleVisitStatusChanged(
    SiteVisit visit,
    String newStatus,
  ) async {
    try {
      final visitStatus = visitStatusFromString(newStatus);
      final updatedVisit = visit.copyWith(status: newStatus);

      // If visit was in-progress and is now completed, stop tracking
      if (visitStatus == VisitStatus.completed &&
          _locationService.getCurrentVisitId() == visit.id) {
        await _locationService.stopTracking();
      }

      // If visit is now in-progress, start tracking
      if (visitStatus == VisitStatus.inProgress &&
          _locationService.getCurrentVisitId() != visit.id) {
        await _locationService.startTracking(visit.id);
      }

      // Update visit in Supabase
      await _siteVisitService.updateSiteVisit(updatedVisit);

      // Show report form if completed
      if (visitStatus == VisitStatus.completed) {
        _showReportFormSheet(updatedVisit);
      }

      // Reload visits and update UI
      await _loadVisits();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating visit: $e')));
      }
    }
  }

  // Show report form sheet
  void _showReportFormSheet(SiteVisit visit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ReportFormSheet(
        visit: visit,
        onReportSubmitted: (report) {
          // Reload visits after report submission
          _loadVisits();
        },
      ),
    );
  }

  // Show visit assignment sheet
  void _showVisitAssignmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VisitAssignmentSheet(
        availableVisits: _availableVisits,
        onVisitAssigned: _handleVisitAssigned,
      ),
    );
  }

  // Handle visit assignment
  Future<void> _handleVisitAssigned(SiteVisit visit) async {
    try {
      final updatedVisit = visit.copyWith(
        status: VisitStatus.assigned.toString(),
        assignedTo: _authService.currentUser?.id,
      );

      // Update visit in Supabase
      await _siteVisitService.updateSiteVisit(updatedVisit);

      // Reload visits and update UI
      await _loadVisits();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error assigning visit: $e')));
      }
    }
  }

  // Force sync data
  Future<void> _forceSyncData() async {
    setState(() => _isSyncing = true);

    try {
      await _syncManager.forceSyncNow();
      await _loadVisits();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error during sync: $e')));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      floatingActionButton: FloatingActionButton(
        heroTag: 'addVisit',
        onPressed: () => _showVisitAssignmentSheet(),
        backgroundColor: AppColors.accentGreen,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildContent(),
                ),
              ],
            ),
          ),
          // Show menu overlay when menu button is clicked
          if (_showMenu)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showMenu = false;
                });
              },
              child: AppMenuOverlay(
                onClose: () {
                  setState(() {
                    _showMenu = false;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        // Map
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentLocation,
            zoom: 14.0,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: _markers,
          onMapCreated: (controller) {
            _mapController.complete(controller);
          },
        ),

        // Overlay UI
        Column(
          children: [
            // Status card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildStatusCard(),
            ),

            const Spacer(),

            // Bottom panel with visits
            _buildVisitsPanel(),
          ],
        ),

        // My location button
        Positioned(
          right: 16,
          bottom: 170,
          child: FloatingActionButton(
            onPressed: _getCurrentLocation,
            backgroundColor: Colors.white,
            child: Icon(Icons.my_location, color: AppColors.primaryBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return ModernAppHeader(
      title: 'Field Operations',
      actions: [
        HeaderActionButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          backgroundColor: Colors.white,
          color: AppColors.primaryBlue,
          onPressed: () {
            HapticFeedback.lightImpact();
            _loadVisits();
          },
        ),
        const SizedBox(width: 8),
        HeaderActionButton(
          icon: Icons.menu_rounded,
          tooltip: 'Menu',
          backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
          color: AppColors.primaryBlue,
          onPressed: () {
            HapticFeedback.mediumImpact();
            setState(() {
              _showMenu = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return ModernCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowColor.withOpacity(0.12),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      ],
      animationDelay: 100.ms,
      animate: true,
      animationDuration: 500.ms,
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Visit stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCounter(
                'Available',
                _availableVisits.length,
                Colors.blue,
              ),
              _buildStatCounter(
                'My Visits',
                _myVisits.length,
                AppColors.primaryOrange,
              ),
              _buildStatCounter(
                'Completed',
                _myVisits
                    .where((v) => v.status == VisitStatus.completed)
                    .length,
                AppColors.accentGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCounter(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textDark.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitsPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16.0),
      child: ModernCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
        headerLeading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.backgroundGray,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.map_outlined,
            color: AppColors.primaryOrange,
            size: 18,
          ),
        ),
        headerTitle: 'My Visits',
        headerTrailing: TextButton(
          onPressed: _showVisitAssignmentSheet,
          child: Text(
            'Assign Visit',
            style: GoogleFonts.poppins(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        animationDelay: 200.ms,
        child: SizedBox(
          height: 120,
          child: _myVisits.isEmpty
              ? Center(
                  child: Text(
                    'No assigned visits yet',
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _myVisits.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final visit = _myVisits[index];
                    return _buildVisitCard(visit);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildVisitCard(SiteVisit visit) {
    // Determine color based on visit status
    Color statusColor;
    final status = visitStatusFromString(visit.status);
    switch (status) {
      case VisitStatus.assigned:
        statusColor = AppColors.primaryBlue;
        break;
      case VisitStatus.inProgress:
        statusColor = Colors.amber.shade700;
        break;
      case VisitStatus.completed:
        statusColor = AppColors.accentGreen;
        break;
      default:
        statusColor = Colors.grey;
    }

    return GestureDetector(
      onTap: () => _selectVisit(visit),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.siteName ?? 'Unnamed Site',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  visit.locationString.isNotEmpty
                      ? visit.locationString
                      : 'No location',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusLabel(visit.status),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: statusColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    return visitStatusFromString(status).label;
  }
}
