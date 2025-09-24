// lib/screens/field_operations_enhanced_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/visit_model.dart';
import '../services/field_operations_repository.dart';
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
  bool _isOnline = false;
  bool _showMenu = false;
  bool _isLoading = true;
  bool _isSyncing = false;

  // Map controller
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};

  // Services
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();
  final LocationTrackingService _locationService = LocationTrackingService();
  final FieldOperationsRepository _repository = FieldOperationsRepository();
  final SyncManager _syncManager = SyncManager();

  // Location
  LatLng _currentLocation = const LatLng(
    12.8628,
    30.2176,
  ); // Default center on Sudan

  // Visit data
  List<Visit> _availableVisits = [];
  List<Visit> _myVisits = [];

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );

    // Initialize location tracking
    _initializeLocationTracking();

    // Initialize repository and sync manager
    _initializeServices();

    // Load visits
    _loadVisits();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  // Initialize connectivity checking
  Future<void> _initConnectivity() async {
    List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return;
    }
    _updateConnectionStatus(result);
  }

  // Update connection status based on connectivity changes
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnectivity =
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);

    setState(() {
      _isOnline = hasConnectivity;
    });

    // Update collector status in repository
    _repository.saveCollectorStatus(hasConnectivity);
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
      await _repository.initialize();
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
              title: visit.title,
              snippet: visit.location ?? 'No location specified',
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
  BitmapDescriptor _getMarkerIcon(VisitStatus status) {
    switch (status) {
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

  // Load visits
  Future<void> _loadVisits() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      await _repository.initialize();

      // Get visits from repository
      final availableVisits = await _repository.getVisitsByStatus(
        VisitStatus.available,
      );
      final myVisits = await _repository.getMyVisits();

      // If we don't have any visits in the repository, generate some example data
      if (availableVisits.isEmpty && myVisits.isEmpty) {
        _generateExampleVisits();
      } else {
        if (mounted) {
          setState(() {
            _availableVisits = availableVisits;
            _myVisits = myVisits;
            _isLoading = false;
          });
          _updateMarkers();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading visits: $e')));
      }
    }
  }

  // Generate some example visits for demonstration
  Future<void> _generateExampleVisits() async {
    final availableVisits = [
      Visit(
        title: 'Site Inspection #1',
        description: 'Inspect construction site for safety compliance',
        latitude: 12.8528, // Khartoum area
        longitude: 30.2176,
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
        status: VisitStatus.available,
        location: 'Central Khartoum',
        address: '123 Al Qasr Ave, Khartoum',
        clientInfo: 'Sudan Construction Ltd.',
        notes: 'Check all safety equipment and documentation',
        priority: 'High',
      ),
      Visit(
        title: 'Field Survey #2',
        description: 'Conduct field survey for new project',
        latitude: 12.8428,
        longitude: 30.2276,
        scheduledDate: DateTime.now().add(const Duration(days: 2)),
        status: VisitStatus.available,
        location: 'North Khartoum',
        address: '45 Al Nile Street, Khartoum North',
        clientInfo: 'Ministry of Infrastructure',
        notes: 'Bring survey equipment and drones',
      ),
      Visit(
        title: 'Water Quality Testing',
        description: 'Test water quality at multiple locations',
        latitude: 12.8328,
        longitude: 30.2376,
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
        status: VisitStatus.available,
        location: 'East Khartoum',
        address: '78 Blue Nile Rd, Khartoum',
        clientInfo: 'Water Resources Authority',
        notes: 'Bring water testing kit and sample containers',
        priority: 'Medium',
      ),
    ];

    final myAssignedVisits = [
      Visit(
        title: 'Equipment Maintenance',
        description: 'Perform routine maintenance on field equipment',
        latitude: 12.8728,
        longitude: 30.2076,
        scheduledDate: DateTime.now(),
        status: VisitStatus.assigned,
        location: 'South Khartoum',
        address: '78 Al Mek Nimir Ave, Khartoum',
        clientInfo: 'PACT Field Office',
        notes: 'Check generators and water pumps',
        assignedUserId: 'current-user-id',
      ),
      Visit(
        title: 'Community Meeting',
        description: 'Attend community meeting for new water project',
        latitude: 12.8828,
        longitude: 30.1976,
        scheduledDate: DateTime.now().subtract(const Duration(days: 1)),
        status: VisitStatus.inProgress,
        location: 'West Khartoum',
        address: '156 Africa St, Khartoum',
        clientInfo: 'Local Community Council',
        notes: 'Bring presentation materials and surveys',
        assignedUserId: 'current-user-id',
      ),
    ];

    // Save example visits to repository
    for (final visit in [...availableVisits, ...myAssignedVisits]) {
      await _repository.saveVisit(visit);
    }

    // Update state
    if (mounted) {
      setState(() {
        _availableVisits = availableVisits;
        _myVisits = myAssignedVisits;
        _isLoading = false;
      });
      _updateMarkers();
    }
  }

  // Select a visit
  void _selectVisit(Visit visit) {
    // Show visit details bottom sheet directly
    _showVisitDetailsSheet(visit);
  }

  // Show visit details sheet
  void _showVisitDetailsSheet(Visit visit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VisitDetailsSheet(
        visit: visit,
        onStatusChange: _handleVisitStatusChanged,
      ),
    );
  }

  // Handle visit status changes
  Future<void> _handleVisitStatusChanged(Visit updatedVisit) async {
    try {
      // If visit was in-progress and is now completed, stop tracking
      if (updatedVisit.status == VisitStatus.completed &&
          _locationService.getCurrentVisitId() == updatedVisit.id) {
        await _locationService.stopTracking();
      }

      // If visit is now in-progress, start tracking
      if (updatedVisit.status == VisitStatus.inProgress &&
          _locationService.getCurrentVisitId() != updatedVisit.id) {
        await _locationService.startTracking(updatedVisit.id);
      }

      // Update visit in repository
      await _repository.saveVisit(updatedVisit);

      // Show report form if completed
      if (updatedVisit.status == VisitStatus.completed) {
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
  void _showReportFormSheet(Visit visit) {
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
  Future<void> _handleVisitAssigned(Visit visit) async {
    try {
      final updatedVisit = visit.copyWith(
        status: VisitStatus.assigned,
        assignedUserId: 'current-user-id', // In a real app, use actual user ID
      );

      // Update visit in repository
      await _repository.saveVisit(updatedVisit);

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

  // Toggle collector online/offline status
  Future<void> _toggleOnlineStatus() async {
    final newStatus = !_isOnline;

    try {
      // Save status to repository
      await _repository.saveCollectorStatus(newStatus);

      setState(() {
        _isOnline = newStatus;
      });

      // If going online, try to sync
      if (newStatus) {
        _forceSyncData();
      } else {
        // If going offline, stop any active tracking
        if (_locationService.isTrackingEnabled()) {
          await _locationService.stopTracking();
        }
      }

      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are now ${newStatus ? 'online' : 'offline'}'),
            backgroundColor: newStatus
                ? AppColors.accentGreen
                : AppColors.accentRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error changing status: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
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
        // Online/Offline toggle
        Switch(
          value: _isOnline,
          onChanged: (value) => _toggleOnlineStatus(),
          activeColor: AppColors.accentGreen,
          activeTrackColor: AppColors.accentGreen.withOpacity(0.3),
          inactiveThumbColor: AppColors.accentRed,
          inactiveTrackColor: AppColors.accentRed.withOpacity(0.3),
        ),

        // Sync indicator
        if (_isSyncing)
          Container(
            padding: const EdgeInsets.all(8),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            ),
          )
        else
          HeaderActionButton(
            icon: _isOnline ? Icons.cloud_done : Icons.cloud_off,
            tooltip: _isOnline ? 'Sync Data' : 'Offline',
            backgroundColor: _isOnline
                ? AppColors.accentGreen.withOpacity(0.1)
                : AppColors.accentRed.withOpacity(0.1),
            color: _isOnline ? AppColors.accentGreen : AppColors.accentRed,
            onPressed: () {
              if (_isOnline) {
                HapticFeedback.lightImpact();
                _forceSyncData();
              }
            },
          ),
        const SizedBox(width: 8),
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
          // Connection status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGray,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      color: _isOnline
                          ? AppColors.accentGreen
                          : AppColors.accentRed,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Connection',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? AppColors.accentGreen.withOpacity(0.1)
                      : AppColors.accentRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _isOnline
                        ? AppColors.accentGreen.withOpacity(0.3)
                        : AppColors.accentRed.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _isOnline
                                ? AppColors.accentGreen
                                : AppColors.accentRed,
                            shape: BoxShape.circle,
                          ),
                        )
                        .animate(onPlay: (controller) => controller.repeat())
                        .fadeOut(
                          duration: 1.seconds,
                          curve: Curves.easeInOutCirc,
                        )
                        .fadeIn(
                          duration: 1.seconds,
                          curve: Curves.easeInOutCirc,
                        ),
                    const SizedBox(width: 6),
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _isOnline
                            ? AppColors.accentGreen
                            : AppColors.accentRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

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
        headerTrailing: _isOnline
            ? TextButton(
                onPressed: _showVisitAssignmentSheet,
                child: Text(
                  'Assign Visit',
                  style: GoogleFonts.poppins(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
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

  Widget _buildVisitCard(Visit visit) {
    // Determine color based on visit status
    Color statusColor;
    switch (visit.status) {
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
                  visit.title,
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
                  visit.location ?? 'No location',
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

  String _getStatusLabel(VisitStatus status) {
    switch (status) {
      case VisitStatus.pending:
        return 'Pending';
      case VisitStatus.available:
        return 'Available';
      case VisitStatus.assigned:
        return 'Assigned';
      case VisitStatus.inProgress:
        return 'In Progress';
      case VisitStatus.completed:
        return 'Completed';
      case VisitStatus.rejected:
        return 'Rejected';
      case VisitStatus.cancelled:
        return 'Cancelled';
    }
  }
}
