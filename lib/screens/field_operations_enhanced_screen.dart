// lib/screens/field_operations_enhanced_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:location/location.dart' as location_package;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/map_tile_cache_service.dart'
    if (dart.library.html) '../services/map_tile_cache_service_web.dart';
import '../models/site_visit.dart';
import '../models/visit_status.dart';
import '../services/site_visit_service.dart';
import '../services/auth_service.dart';
import '../services/location_tracking_service.dart';
import '../services/sync_manager.dart';
import '../services/mmp_file_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_switcher.dart';
import '../services/geographical_task_service.dart';
import '../services/task_assignment_service.dart';
import '../services/journey_service.dart';
import '../services/staff_tracking_service.dart';
import '../widgets/task_dashboard.dart';
import '../algorithms/nearest_site_visits.dart';
import '../theme/app_colors.dart';
import '../widgets/app_menu_overlay.dart';
import '../widgets/modern_app_header.dart';
import '../widgets/modern_card.dart';
import '../widgets/custom_drawer_menu.dart';
import '../widgets/offline_sync_indicator.dart';
import '../services/notification_service.dart';
import '../services/offline_data_service.dart';
import 'components/report_form_sheet.dart';
import 'components/visit_assignment_sheet.dart';
import 'components/visit_details_sheet.dart';
import 'components/mmp_files_sheet.dart';
import '../theme/app_design_system.dart';
import '../widgets/app_widgets.dart';
import '../utils/error_handler.dart';

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
  late final MapController _mapController; // flutter_map controller
  bool _isMapReady = false; // Track if map is fully initialized

  Set<Marker> _markers = {}; // flutter_map markers
  Set<Polyline> _journeyPolylines = {}; // flutter_map polylines

  // Services
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();
  late final location_package.Location _locationService;
  final SiteVisitService _siteVisitService = SiteVisitService();
  final AuthService _authService = AuthService();
  final MMPFileService _mmpFileService = MMPFileService();
  final SyncManager _syncManager = SyncManager();
  late final GeographicalTaskService _geographicalTaskService;
  late final TaskAssignmentService _taskAssignmentService;
  late final JourneyService _journeyService;
  late final LocationTrackingService _locationTrackingService;

  // Listen for new MMP files
  StreamSubscription? _mmpFileSubscription;
  StreamSubscription<Position>? _locationStreamSubscription;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Location
  latlong.LatLng _currentLocation = const latlong.LatLng(
    12.8628,
    30.2176,
  ); // Default center on Sudan

  // Visit data
  List<SiteVisit> _availableVisits = [];
  List<SiteVisit> _myVisits = [];

  // Task data
  List<SiteVisitWithDistance> _nearbyTasks = [];
  final List<SiteVisit> _acceptedTasks = [];
  bool _isLoadingTasks = false;

  // Journey tracking state
  bool _isTrackingJourney = false;
  latlong.LatLng? _journeyStartPosition;
  List<latlong.LatLng> _journeyPath = [];
  SiteVisit? _currentTrackedTask;
  StreamSubscription<location_package.LocationData>?
      _journeyProgressSubscription;

  // OSRM routing state
  Set<Polyline> _routePolylines = {}; // For OSRM directions

  @override
  void initState() {
    super.initState();
    _mapController = MapController(); // Initialize flutter_map controller
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );

    // Initialize notifications
    NotificationService.initialize();

    // Listen for new MMP files
    _mmpFileSubscription = _mmpFileService.onNewFiles.listen((files) {
      if (files.isNotEmpty) {
        final firstFile = files.first;
        NotificationService.showMMPFileNotification(
          title: 'New MMP Files',
          body:
              '${files.length} new MMP file${files.length > 1 ? 's have' : ' has'} been uploaded',
          fileId: firstFile['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          fileName: firstFile['title']?.toString() ?? 'MMP File',
        );
      }
    });

    // Initialize location tracking
    _initializeLocationTracking();

    // Initialize repository and sync manager
    _initializeServices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load visits after dependencies are initialized
    _loadVisits();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _mmpFileSubscription?.cancel();
    _locationStreamSubscription?.cancel();
    _journeyProgressSubscription?.cancel();
    if (_isTrackingJourney) {
      _journeyService.stopJourney();
    }
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
  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    final hasConnectivity = results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);

    setState(() {
      _isOnline = hasConnectivity;
    });

    // Update collector status
    if (_authService.currentUser != null) {
      try {
        await _authService.supabase
            .from('user_roles')
            .update({'status': hasConnectivity ? 'online' : 'offline'}).eq(
                'user_id', _authService.currentUser!.id);
      } catch (e) {
        debugPrint('Error updating user status: $e');
      }
    }
  }

  // Initialize location tracking
  Future<void> _initializeLocationTracking() async {
    _locationService =
        location_package.Location(); // Initialize location service

    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) return;
      }

      location_package.PermissionStatus permissionGranted =
          await _locationService.hasPermission();
      if (permissionGranted == location_package.PermissionStatus.denied) {
        permissionGranted = await _locationService.requestPermission();
        if (permissionGranted != location_package.PermissionStatus.granted) {
          return;
        }
      }

      _getCurrentLocation();

      // Start continuous location updates for better accuracy
      _startLocationStream();
    } catch (e) {
      if (mounted) {
        context.showError(e, onRetry: _initializeLocationTracking);
      }
    }
  }

  // Initialize services
  Future<void> _initializeServices() async {
    try {
      await _syncManager.initialize();

      // Initialize new task services
      _geographicalTaskService = GeographicalTaskService(_siteVisitService);
      _taskAssignmentService =
          TaskAssignmentService(_siteVisitService.supabase, _siteVisitService);
      _journeyService = JourneyService(LocationTrackingService(),
          StaffTrackingService(_siteVisitService.supabase));
      _locationTrackingService = LocationTrackingService();

      // Load initial tasks
      await _loadNearbyTasks();
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      // Try to get the last known position for instant feedback (not supported on web)
      if (!kIsWeb) {
        Position? lastKnown;
        try {
          lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null && mounted) {
            setState(() {
              _currentLocation =
                  latlong.LatLng(lastKnown!.latitude, lastKnown.longitude);
            });
            // Don't call _updateMapCamera here - map not ready yet
            _updateMarkers();
            debugPrint(
                'Using last known location: ${lastKnown.latitude}, ${lastKnown.longitude}');
          }
        } catch (e) {
          debugPrint('No last known position: $e');
        }
      }

      // Now get fresh, accurate position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: kIsWeb ? LocationAccuracy.high : LocationAccuracy.best,
        forceAndroidLocationManager:
            false, // Use FusedLocationProvider on Android for better accuracy
      );

      debugPrint(
          'Fresh GPS location: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');

      if (mounted) {
        setState(() {
          _currentLocation =
              latlong.LatLng(position.latitude, position.longitude);
        });

        // Don't call _updateMapCamera here - let the map use initialCenter
        // Camera updates will happen via onMapReady or manual user interaction
        _updateMarkers();
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');

      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Location error. Using default location.',
          type: SnackBarType.warning,
        );
      }
    }
  }

  // Start continuous location stream for real-time updates
  void _startLocationStream() {
    const locationSettings = LocationSettings(
      accuracy:
          LocationAccuracy.bestForNavigation, // Best accuracy for navigation
      distanceFilter: 5, // Update every 5 meters for better tracking
    );

    _locationStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        if (mounted) {
          debugPrint(
              'Location stream update: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');
          setState(() {
            _currentLocation =
                latlong.LatLng(position.latitude, position.longitude);
          });
          // Update markers when location changes
          _updateMarkers();
        }
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  // Update map camera
  void _updateMapCamera() {
    // Only update camera if map is fully ready
    if (!mounted || !_isMapReady) {
      debugPrint('Skipping camera update - map not ready yet');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isMapReady) return;
      try {
        _mapController.move(_currentLocation, 17.0);
      } catch (e) {
        debugPrint('Error updating map camera: $e');
      }
    });
  }

  // Update map markers
  void _updateMarkers() {
    if (!mounted) return;

    final markers = <Marker>{};

    // Add current location marker (with custom icon if tracking)
    markers.add(
      Marker(
        width: 200,
        height: 90,
        point: _currentLocation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Location icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isTrackingJourney
                    ? AppColors.primaryOrange
                    : AppColors.primaryBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.radio_button_checked,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(height: 4),
            // Location label below
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBlue, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'You are here',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );

    // Add visit markers
    for (final visit in [..._availableVisits, ..._myVisits]) {
      if (visit.latitude != null && visit.longitude != null) {
        markers.add(
          Marker(
            width: 180,
            height: 120,
            point: latlong.LatLng(visit.latitude!, visit.longitude!),
            child: GestureDetector(
              onTap: () => _selectVisit(visit),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Visit icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getMarkerColor(visit.status),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.radio_button_checked,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 4),
                  // Visit label below icon
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _getMarkerColor(visit.status), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          visit.siteName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _getPriorityColor(visit.priority),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              visit.priority.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: _getPriorityColor(visit.priority),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  // Get marker color based on visit status
  Color _getMarkerColor(String status) {
    switch (visitStatusFromString(status)) {
      case VisitStatus.pending:
      case VisitStatus.available:
        return Colors.red;
      case VisitStatus.assigned:
        return Colors.purple;
      case VisitStatus.inProgress:
        return AppColors.primaryOrange;
      case VisitStatus.completed:
        return AppColors.accentGreen;
      case VisitStatus.rejected:
      case VisitStatus.cancelled:
        return Colors.grey;
    }
  }

  // Get priority color for labels
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
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
      final allVisits =
          visitData.map((data) => SiteVisit.fromJson(data)).toList();

      // Show all assigned visits (removed location filtering for reliability)
      final filteredVisits =
          allVisits; // when implementing geofencing based on city change this

      if (mounted) {
        setState(() {
          _availableVisits = filteredVisits;
          _myVisits =
              filteredVisits.where((v) => v.assignedTo == userId).toList();
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
        // Use addPostFrameCallback to show error after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.showError(e, onRetry: _loadVisits);
          }
        });
      }
    }
  }

  // This method is no longer needed since we're using real data
  Future<void> _generateExampleVisits() async {
    // Implementation removed as we now use real data from Supabase
    await _loadVisits();
  }

  Future<String?> _getCurrentCity() async {
    if (kIsWeb) {
      // On web, we can't reliably get location without user interaction
      // Return null to show all visits
      return null;
    }

    try {
      // Check location permissions first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied');
        return null;
      }

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Get placemarks from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && placemarks.first.locality != null) {
        return placemarks.first.locality; // e.g., "Kampala"
      } else {
        debugPrint('No locality found in placemarks');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting current city: $e');
      return null;
    }
  }

  // Select a visit
  void _selectVisit(SiteVisit visit) {
    // Show visit details bottom sheet directly
    _showVisitDetailsSheet(visit);
  }

  // Show visit details sheet
  void _showVisitDetailsSheet(SiteVisit visit, {bool reportSubmitted = false}) {
    final isTrackedVisit = _currentTrackedTask?.id == visit.id;
    final isNear = isTrackedVisit && _isNearDestination(visit);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VisitDetailsSheet(
        visit: visit,
        onStatusChanged: (newStatus) =>
            _handleVisitStatusChanged(visit, newStatus),
        isTrackingJourney: isTrackedVisit && _isTrackingJourney,
        isNearDestination: isNear,
        onArrived: isTrackedVisit ? _handleArrived : null,
        onGetDirections: () => _getDirectionsToVisit(visit),
        reportSubmitted: reportSubmitted,
        onSubmitReportRequested: () {
          // Open report form for this visit
          _showReportFormSheet(visit);
        },
      ),
    );
  }

  // Handle visit status changes
  Future<void> _handleVisitStatusChanged(
    SiteVisit visit,
    String newStatus,
  ) async {
    try {
      // Avoid redundant updates
      if (visit.status.toLowerCase() == newStatus.toLowerCase()) {
        debugPrint('Visit ${visit.id} already in status $newStatus; skipping');
        return;
      }
      final visitStatus = visitStatusFromString(newStatus);
      // Ensure the visit carries the current user's ID for RLS-compliant updates
      final userId = _authService.currentUser?.id;
      final updatedVisit = visit.copyWith(
        status: newStatus,
        userId: visit.userId ?? userId,
      );

      // If visit was in-progress and is now completed, stop tracking
      if (visitStatus == VisitStatus.completed &&
          _locationTrackingService.getCurrentVisitId() == visit.id) {
        await _locationTrackingService.stopTracking();
      }

      // If visit is now in-progress, start tracking
      if (visitStatus == VisitStatus.inProgress &&
          _locationTrackingService.getCurrentVisitId() != visit.id) {
        await _locationTrackingService.startTracking(visit.id);
      }

      // Update visit in Supabase
      await _siteVisitService.updateSiteVisit(updatedVisit);

      // Show report form if completed
      if (visitStatus == VisitStatus.completed) {
        debugPrint('Visit ${visit.id} marked completed; opening report form');
        _showReportFormSheet(updatedVisit);
      }

      // Reload visits and update UI
      await _loadVisits();
    } catch (e) {
      if (mounted) {
        context.showError(e);
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
          // Reload visits after report submission, then show capture location
          _loadVisits().then((_) async {
            try {
              final refreshed =
                  await _siteVisitService.getSiteVisitById(visit.id);
              if (!mounted) return;
              if (refreshed != null) {
                // Reopen details with reportSubmitted=true so capture button is shown
                _showVisitDetailsSheet(refreshed, reportSubmitted: true);
              } else {
                // Fallback: show original with flag
                _showVisitDetailsSheet(visit, reportSubmitted: true);
              }
            } catch (_) {
              if (!mounted) return;
              _showVisitDetailsSheet(visit, reportSubmitted: true);
            }
          });
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
        context.showError(e);
      }
    }
  }

  // Load nearby tasks using geographical algorithm
  Future<void> _loadNearbyTasks() async {
    if (!mounted) return;

    setState(() {
      _isLoadingTasks = true;
    });

    try {
      final tasks = await _geographicalTaskService.getNearbyAvailableTasks();
      setState(() {
        _nearbyTasks = tasks;
        _isLoadingTasks = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTasks = false;
      });
      debugPrint('Error loading nearby tasks: $e');
    }
  }

  // Handle task acceptance
  Future<void> _handleTaskAccepted(SiteVisit task) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _taskAssignmentService.acceptTask(
        taskId: task.id,
        userId: userId,
      );

      if (response.result == TaskAssignmentResult.success) {
        // Show dialog to start tracking
        _showStartTrackingDialog(task);

        // Remove from nearby tasks
        setState(() {
          _nearbyTasks.removeWhere((t) => t.visit.id == task.id);
        });

        if (mounted) {
          AppSnackBar.show(
            context,
            message: 'Task accepted successfully',
            type: SnackBarType.success,
          );
        }
      } else {
        if (mounted) {
          AppSnackBar.show(
            context,
            message: response.message ?? 'Failed to accept task',
            type: SnackBarType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        context.showError(e, onRetry: () => _handleTaskAccepted(task));
      }
    }
  }

  // Handle task decline
  Future<void> _handleTaskDeclined(SiteVisit task) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _taskAssignmentService.declineTask(
        taskId: task.id,
        userId: userId,
      );

      // Remove from nearby tasks
      setState(() {
        _nearbyTasks.removeWhere((t) => t.visit.id == task.id);
      });

      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Task declined',
          type: SnackBarType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showError(e);
      }
    }
  }

  // Start journey tracking for accepted task
  Future<void> _startJourneyForTask(SiteVisit task) async {
    try {
      _journeyStartPosition = _currentLocation;
      _currentTrackedTask = task;

      final journeyWaypoints = await _journeyService.startJourney(
        assignedTasks: [task],
        startPosition: _currentLocation,
      );

      // Initialize polyline from start to destination
      final destinationLatLng = latlong.LatLng(task.latitude!, task.longitude!);

      setState(() {
        _isTrackingJourney = true;
        _acceptedTasks.add(task);
        _journeyPath = [_journeyStartPosition!, destinationLatLng];

        // Create orange polyline for journey path
        _journeyPolylines = {
          Polyline(
            points: [_journeyStartPosition!],
            color: AppColors.primaryOrange,
            strokeWidth: 5.0,
          ),
        };
      });

      // Listen to location updates for real-time path tracking
      _journeyProgressSubscription = _locationService.onLocationChanged
          .listen((location_package.LocationData locationData) {
        final currentLatLng =
            latlong.LatLng(locationData.latitude!, locationData.longitude!);

        setState(() {
          _currentLocation = currentLatLng;

          // Add current position to journey path
          if (!_journeyPath.contains(currentLatLng)) {
            _journeyPath.add(currentLatLng);
          }

          // Update polyline with accumulated path
          _journeyPolylines = {
            Polyline(
              points: _journeyPath,
              color: AppColors.primaryOrange,
              strokeWidth: 5.0,
            ),
          };

          _updateMarkers();
        });

        // Update map camera to follow user
        _updateMapCamera();
      });

      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Journey started - location tracking active',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      debugPrint('Error starting journey: $e');
      if (mounted) {
        context.showError(e, onRetry: () => _startJourneyForTask(task));
      }
    }
  }

  // Show dialog to confirm starting journey tracking
  void _showStartTrackingDialog(SiteVisit task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ready to Start Journey?'),
        content: const Text(
          'Enable location tracking to monitor your route to the site. '
          'Your path will be displayed on the map with an orange line.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startJourneyForTask(task);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            child: const Text('Start Tracking'),
          ),
        ],
      ),
    );
  }

  // Check if user is near the destination (within 50 meters)
  bool _isNearDestination(SiteVisit visit) {
    if (visit.latitude == null || visit.longitude == null) return false;

    final distance = latlong.Distance().as(
      latlong.LengthUnit.Meter,
      _currentLocation,
      latlong.LatLng(visit.latitude!, visit.longitude!),
    );

    return distance <= 50; // 50 meters threshold
  }

  // Handle arrival at destination
  Future<void> _handleArrived() async {
    if (_currentTrackedTask == null) return;

    try {
      // Prepare arrival data for database storage
      final arrivalData = {
        'arrival_latitude': _currentLocation.latitude,
        'arrival_longitude': _currentLocation.longitude,
        'arrival_timestamp': DateTime.now().toUtc(),
        'journey_path': _journeyPath
            .map((point) => {'lat': point.latitude, 'lng': point.longitude})
            .toList(),
        'arrival_recorded': true,
      };

      // Update visit in Supabase with arrival data
      await _siteVisitService.supabase.from('site_visits').update({
        'arrival_latitude': _currentLocation.latitude,
        'arrival_longitude': _currentLocation.longitude,
        'arrival_timestamp': DateTime.now().toUtc(),
        'journey_path': _journeyPath
            .map((point) => {'lat': point.latitude, 'lng': point.longitude})
            .toList(),
        'arrival_recorded': true,
        'status': 'in_progress',
      }).eq('id', _currentTrackedTask!.id);

      // Also update local visitData for consistency
      final updatedVisit = _currentTrackedTask!.copyWith(
        visitData: {
          ..._currentTrackedTask!.visitData ?? {},
          'arrival': arrivalData,
        },
        status: 'in_progress',
      );

      // Stop tracking but keep the path visible
      await _journeyProgressSubscription?.cancel();
      _journeyProgressSubscription = null;

      setState(() {
        _isTrackingJourney = false;
        // Update the visit in the list
        final index =
            _myVisits.indexWhere((v) => v.id == _currentTrackedTask!.id);
        if (index != -1) {
          _myVisits[index] = updatedVisit;
        }
      });

      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Arrival recorded! You can now complete your task.',
          type: SnackBarType.success,
        );

        // Close the details sheet and reload
        Navigator.pop(context);
        await _loadVisits();
      }
    } catch (e) {
      debugPrint('Error recording arrival: $e');
      if (mounted) {
        context.showError(e, onRetry: _handleArrived);
      }
    }
  }

  // Get directions to visit using OSRM
  Future<void> _getDirectionsToVisit(SiteVisit visit) async {
    if (visit.latitude == null || visit.longitude == null) {
      if (mounted) context.showError('This visit has no coordinates');
      return;
    }

    try {
      // Ensure we have current location permissions and position
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      if (!serviceEnabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }

      // If still not granted, fallback to external maps intent
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final uri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=${visit.latitude},${visit.longitude}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      final start =
          '${_currentLocation.longitude},${_currentLocation.latitude}';
      final end = '${visit.longitude},${visit.latitude}';

      // Use OSRM public API (free, rate-limited)
      final url =
          'https://router.project-osrm.org/route/v1/driving/$start;$end?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0]['geometry']['coordinates'] as List;

        final points =
            route.map((coord) => latlong.LatLng(coord[1], coord[0])).toList();

        setState(() {
          _routePolylines = {
            Polyline(
              points: points,
              color: Colors.blue,
              strokeWidth: 4.0,
              borderColor: Colors.white,
              borderStrokeWidth: 2.0,
            ),
          };
        });

        // Fit map to show the route
        if (points.isNotEmpty) {
          final bounds = LatLngBounds.fromPoints(points);
          _mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
          );
        }

        if (mounted) {
          AppSnackBar.show(
            context,
            message: 'Directions loaded',
            type: SnackBarType.success,
          );
        }
      } else {
        // Fallback to opening Google Maps when OSRM fails
        final uri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&origin=${_currentLocation.latitude},${_currentLocation.longitude}&destination=${visit.latitude},${visit.longitude}&travelmode=driving');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
        throw Exception('Failed to load directions');
      }
    } catch (e) {
      debugPrint('Error getting directions: $e');
      if (mounted) {
        context.showError(e, onRetry: () => _getDirectionsToVisit(visit));
      }
    }
  }

  // Clear directions
  void _clearDirections() {
    setState(() {
      _routePolylines.clear();
    });
  }

  // Force sync data
  Future<void> _forceSyncData() async {
    setState(() => _isSyncing = true);

    try {
      await _syncManager.forceSyncNow();
      await _loadVisits();

      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Sync completed successfully',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showError(e, onRetry: _forceSyncData);
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  // Toggle collector online/offline status
  Future<void> _toggleOnlineStatus() async {
    final newStatus = !_isOnline;

    try {
      // Save status to Supabase
      await _authService.supabase
          .from('user_roles')
          .update({'status': newStatus ? 'online' : 'offline'}).eq(
              'user_id', _authService.currentUser!.id);

      setState(() {
        _isOnline = newStatus;
      });

      // If going online, try to sync
      if (newStatus) {
        _forceSyncData();
      } else {
        // If going offline, stop any active tracking
        if (_locationTrackingService.isTrackingEnabled()) {
          await _locationTrackingService.stopTracking();
        }
      }

      // Show confirmation
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'You are now ${newStatus ? 'online' : 'offline'}',
          type: newStatus ? SnackBarType.success : SnackBarType.warning,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showError(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final orientation = MediaQuery.of(context).orientation;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundGray,
      drawer: CustomDrawerMenu(
        currentUser: _authService.currentUser,
        onClose: () => _scaffoldKey.currentState?.closeDrawer(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Make header height responsive to screen size and orientation
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: orientation == Orientation.portrait
                        ? screenHeight *
                            0.12 // Max 12% of screen height in portrait
                        : screenHeight * 0.18, // Max 18% in landscape
                    minHeight: orientation == Orientation.portrait
                        ? 60.0 // Minimum height for usability
                        : 50.0,
                  ),
                  child: _buildHeader(),
                ),
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
    return _buildMapView();
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 14.0,
            onMapReady: () {
              debugPrint('Map ready');
              setState(() => _isMapReady = true);
              if (mounted) {
                _updateMarkers();
                _updateMapCamera();
              }
            },
            // If tiles fail we still want gestures active
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            // Use OpenStreetMap tiles across all platforms
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.pact_mobile',
              tileProvider: MapTileCacheService.getTileProvider(
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              // Graceful per-tile error logging
              errorTileCallback: (tile, error, stack) {
                debugPrint('Tile load error: $error');
              },
            ),
            // Markers & polylines
            MarkerLayer(markers: _markers.toList()),
            if (_journeyPolylines.isNotEmpty || _routePolylines.isNotEmpty)
              PolylineLayer(
                polylines: {..._journeyPolylines, ..._routePolylines}.toList(),
              ),
          ],
        ),

        // Overlay UI
        Positioned.fill(
          child: Column(
            children: [
              // Status card
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildStatusCard(),
              ),

              // Offline sync indicator
              const OfflineSyncIndicator(),

              const Spacer(),

              // Bottom panel with visits
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 200, // Reduced from 220 to fit content
                ),
                child: _buildVisitsPanel(),
              ),
              const SizedBox(height: 8), // Add bottom padding
            ],
          ),
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

        // Clear directions button (show when routes exist)
        if (_routePolylines.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              onPressed: _clearDirections,
              backgroundColor: Colors.white,
              child: Icon(Icons.clear, color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return ModernAppHeader(
      title: 'Field Ops',
      actions: [
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
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        const SizedBox(width: 8),
        const LanguageSwitcher(),
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8), // Reduced bottom margin
      child: ModernCard(
        padding: const EdgeInsets.all(8), // Reduced from 12
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 140), // Reduced from 160
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
    // Determine color and status type based on visit status
    Color statusColor;
    StatusType statusType;
    IconData statusIcon;
    final status = visitStatusFromString(visit.status);

    switch (status) {
      case VisitStatus.assigned:
        statusColor = AppColors.primaryBlue;
        statusType = StatusType.info;
        statusIcon = Icons.assignment;
        break;
      case VisitStatus.inProgress:
        statusColor = Colors.amber.shade700;
        statusType = StatusType.warning;
        statusIcon = Icons.pending_actions;
        break;
      case VisitStatus.completed:
        statusColor = AppColors.accentGreen;
        statusType = StatusType.success;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusType = StatusType.pending;
        statusIcon = Icons.help_outline;
    }

    return AppCard(
      onTap: () => _selectVisit(visit),
      shadows: AppDesignSystem.shadowMD,
      child: Container(
        width: 170, // Reduced from 180
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Was 10
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status icon
            Container(
              width: 24, // Reduced from 28
              height: 24, // Reduced from 28
              margin: const EdgeInsets.only(bottom: 2), // Reduced from 4
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 14, // Reduced from 16
              ),
            ),
            Text(
              visit.siteName ?? 'Unnamed Site',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppDesignSystem.titleMedium
                  .copyWith(fontSize: 11), // Reduced from 12
            ),
            const SizedBox(height: 2), // Reduced from 3
            Text(
              visit.locationString.isNotEmpty
                  ? visit.locationString
                  : 'No location',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppDesignSystem.bodySmall.copyWith(
                color: Colors.grey.shade600,
                fontSize: 9, // Reduced from 10
              ),
            ),
            const SizedBox(height: 2), // Reduced from 3
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: StatusBadge(
                    text: _getStatusLabel(visit.status),
                    type: statusType,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    size: 12, color: statusColor), // Reduced from 16
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }

  String _getStatusLabel(String status) {
    return visitStatusFromString(status).label;
  }
}
