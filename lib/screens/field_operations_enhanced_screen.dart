// lib/screens/field_operations_enhanced_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
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
import '../services/user_notification_service.dart';
import '../models/user_notification.dart';
import '../services/offline_data_service.dart';
import 'components/report_form_sheet.dart';
import 'components/visit_assignment_sheet.dart';
import 'components/visit_details_sheet.dart';
import 'components/mmp_files_sheet.dart';
import '../theme/app_design_system.dart';
import '../widgets/active_visit_overlay.dart';
import '../utils/error_handler.dart';
import '../widgets/app_widgets.dart';

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
  late final JourneyService _journeyService;
  late final LocationTrackingService _locationTrackingService;
  final UserNotificationService _notificationService = UserNotificationService();

  // Listen for new MMP files
  StreamSubscription? _mmpFileSubscription;
  StreamSubscription<Position>? _locationStreamSubscription;
  StreamSubscription<List<UserNotification>>? _notificationSubscription;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Location
  latlong.LatLng _currentLocation = const latlong.LatLng(
    12.8628,
    30.2176,
  ); // Default center on Sudan

  // Visit data
  List<SiteVisit> _availableVisits = [];
  List<SiteVisit> _myVisits = [];
  List<SiteVisit> _assignedVisits = []; // For displaying assigned/accepted visits
  int _completedVisitsCount = 0; // Track completed visits count
  Set<String> _pendingSyncVisitIds = {}; // Track visits with pending offline changes
  Set<String> _draftVisitIds = {}; // Track visits with saved drafts

  // Task data
  List<SiteVisitWithDistance> _nearbyTasks = [];
  final List<SiteVisit> _acceptedTasks = [];
  bool _isLoadingTasks = false;
  
  // Location accuracy tracking
  int _consecutiveLowAccuracyCount = 0;
  static const int _maxLowAccuracyAttempts = 3;

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
    _notificationService.initialize();

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
    _notificationSubscription?.cancel();
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

    final wasOffline = !_isOnline;
    
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
    
    // If we just came online, trigger sync and refresh data
    if (wasOffline && hasConnectivity) {
      debugPrint('🔄 Coming online - syncing pending changes...');
      _syncPendingChanges();
    }
  }

  /// Sync pending offline changes when coming online
  Future<void> _syncPendingChanges() async {
    if (!_isOnline || _isSyncing) return;
    
    setState(() {
      _isSyncing = true;
    });
    
    try {
      // Sync pending changes from OfflineDataService
      final offlineService = OfflineDataService();
      final pendingCount = await offlineService.getPendingSyncCount();
      
      if (pendingCount > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Syncing $pendingCount pending changes...'),
                ],
              ),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        final results = await offlineService.syncAll();
        final totalSynced = results.values.fold<int>(0, (sum, count) => sum + count);
        
        if (mounted && totalSynced > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.cloud_done, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Synced $totalSynced changes successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      
      // Refresh data from server
      await _loadVisits();
    } catch (e) {
      debugPrint('Error syncing pending changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Sync failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
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
      // Now get fresh, accurate position with retry for better accuracy
      Position position;
      int retryCount = 0;
      const maxRetries = 3;
      const maxAccuracy = 5.0; // Maximum 5 meters accuracy

      do {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: kIsWeb ? LocationAccuracy.high : LocationAccuracy.best,
          forceAndroidLocationManager:
              false, // Use FusedLocationProvider on Android for better accuracy
        );

        debugPrint(
            'GPS location attempt ${retryCount + 1}: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');

        if (position.accuracy <= maxAccuracy) {
          debugPrint('✓ Accuracy acceptable: ${position.accuracy}m');
          break;
        }

        retryCount++;
        if (retryCount < maxRetries) {
          debugPrint('⚠ Accuracy too low (${position.accuracy}m), retrying...');
          await Future.delayed(const Duration(seconds: 2));
        }
      } while (retryCount < maxRetries);

      if (position.accuracy > maxAccuracy) {
        debugPrint('⚠ Could not achieve ${maxAccuracy}m accuracy after $maxRetries attempts. Using best available: ${position.accuracy}m');
      }

      if (mounted) {
        setState(() {
          _currentLocation =
              latlong.LatLng(position.latitude, position.longitude);
        });

        // Move map camera to current location when user presses the location button
        _updateMapCamera();
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
          const maxAccuracy = 5.0; // Prefer 5m or better accuracy
          
          if (position.accuracy <= maxAccuracy) {
            // Reset counter when we get good accuracy
            _consecutiveLowAccuracyCount = 0;
            debugPrint(
                '✓ Location stream update: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');
            setState(() {
              _currentLocation =
                  latlong.LatLng(position.latitude, position.longitude);
            });
            // Update markers when location changes
            _updateMarkers();
          } else {
            // Increment counter for consecutive low accuracy
            _consecutiveLowAccuracyCount++;
            
            // After 3 consecutive low accuracy readings, accept what we have
            if (_consecutiveLowAccuracyCount >= _maxLowAccuracyAttempts) {
              debugPrint(
                  '⚠ After $_maxLowAccuracyAttempts attempts, accepting available accuracy: ${position.accuracy}m');
              setState(() {
                _currentLocation =
                    latlong.LatLng(position.latitude, position.longitude);
              });
              _updateMarkers();
              // Reset counter after accepting
              _consecutiveLowAccuracyCount = 0;
            } else {
              debugPrint(
                  '⚠ Location accuracy: ${position.accuracy}m (attempt $_consecutiveLowAccuracyCount/$_maxLowAccuracyAttempts, preferred: ≤${maxAccuracy}m)');
            }
          }
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

  // Load visits from Supabase or local cache
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

      // Check connectivity
      final offlineService = OfflineDataService();
      final isOnline = await offlineService.isOnline();

      if (isOnline) {
        // ONLINE: Fetch from service methods and cache for offline
        try {
          final available = await _siteVisitService.getAvailableSiteVisits();
          final claimed = await _siteVisitService.getClaimedSiteVisits(userId);
          final accepted = await _siteVisitService.getAcceptedSiteVisits(userId);
          final ongoing = await _siteVisitService.getOngoingSiteVisits(userId);
          final completed = await _siteVisitService.getCompletedSiteVisits(userId);
          
          // Cache for offline use
          await offlineService.cacheSiteVisitsByCategory(
            available: available.map((v) => v.toJson()).toList(),
            claimed: claimed.map((v) => v.toJson()).toList(),
            accepted: accepted.map((v) => v.toJson()).toList(),
            ongoing: ongoing.map((v) => v.toJson()).toList(),
            completed: completed.map((v) => v.toJson()).toList(),
          );
          
          _completedVisitsCount = completed.length;

          if (mounted) {
            setState(() {
              _availableVisits = available;
              _myVisits = [...available, ...claimed, ...accepted, ...ongoing];
              _assignedVisits = [...available, ...claimed, ...accepted, ...ongoing];
              _isLoading = false;
            });
          }
          _updateMarkers();
        } catch (e) {
          debugPrint('Error fetching visits online, falling back to cache: $e');
          // Fall back to cached data
          await _loadVisitsFromCache(userId);
        }
      } else {
        // OFFLINE: Load from local cache
        debugPrint('📦 Loading visits from offline cache...');
        await _loadVisitsFromCache(userId);
      }
    } catch (e) {
      debugPrint('Error loading visits: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isOnline ? 'Error loading visits: $e' : 'Viewing offline data. Some information may be outdated.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    }
  }

  /// Load visits from local cache when offline
  Future<void> _loadVisitsFromCache(String userId) async {
    final offlineService = OfflineDataService();
    
    // Get cached visits by category
    final availableData = await offlineService.getCachedSiteVisitsByCategory('available');
    final claimedData = await offlineService.getCachedSiteVisitsByCategory('claimed');
    final acceptedData = await offlineService.getCachedSiteVisitsByCategory('accepted');
    final ongoingData = await offlineService.getCachedSiteVisitsByCategory('ongoing');
    final completedData = await offlineService.getCachedSiteVisitsByCategory('completed');
    
    // Convert to SiteVisit objects
    final available = availableData.map((j) => SiteVisit.fromJson(j)).toList();
    final claimed = claimedData.map((j) => SiteVisit.fromJson(j)).toList();
    final accepted = acceptedData.map((j) => SiteVisit.fromJson(j)).toList();
    final ongoing = ongoingData.map((j) => SiteVisit.fromJson(j)).toList();
    final completed = completedData.map((j) => SiteVisit.fromJson(j)).toList();
    
    _completedVisitsCount = completed.length;
    
    // Get pending sync visit IDs
    final pendingIds = await offlineService.getPendingVisitIds();
    
    // Get draft visit IDs (saved but not completed)
    final draftIds = await offlineService.getDraftVisitIds();

    if (mounted) {
      setState(() {
        _availableVisits = available;
        _myVisits = [...available, ...claimed, ...accepted, ...ongoing];
        _assignedVisits = [...available, ...claimed, ...accepted, ...ongoing];
        _pendingSyncVisitIds = pendingIds;
        _draftVisitIds = draftIds;
        _isLoading = false;
      });
    }
    _updateMarkers();
    
    // Show offline indicator
    if (mounted && !_isOnline) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Offline mode - showing cached data'),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
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
        onReject: (reason) => _handleVisitRejection(visit, reason),
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

  Future<void> _handleVisitRejection(SiteVisit visit, String reason) async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) return;
      
      await _siteVisitService.rejectVisit(visit.id, userId, reason);
      await _loadVisits();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit rejected successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        context.showError(e);
      }
    }
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
      
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      if (newStatus.toLowerCase() == 'assigned' || newStatus.toLowerCase() == 'claimed') {
        // Site has been claimed - just reload visits to show updated state
        await _loadVisits();
      } else if (newStatus.toLowerCase() == 'accepted' || newStatus.toLowerCase() == 'accept') {
        await _siteVisitService.acceptVisit(visit.id, userId);
        // Start tracking location upon acceptance
        await _locationTrackingService.startTracking(visit.id);
        // Reload visits and update UI
        await _loadVisits();
      } else if (newStatus.toLowerCase() == 'ongoing' || newStatus.toLowerCase() == 'in_progress') {
        await _siteVisitService.startVisit(visit.id);
        // Reload visits and update UI
        await _loadVisits();
      } else if (newStatus == 'Completed' || newStatus == 'Complete') {
        await _siteVisitService.completeVisit(visit.id);
        // Stop tracking
        await _locationTrackingService.stopTracking();
        // Show report form - don't reload visits yet, let the report callback handle it
        _showReportFormSheet(visit);
      } else {
        // Fallback for other statuses or legacy logic
        final visitStatus = visitStatusFromString(newStatus);
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

        // Update visit in Supabase (with offline cache support)
        await _siteVisitService.updateSiteVisitCached(updatedVisit);

        // Show report form if completed
        if (visitStatus == VisitStatus.completed) {
          debugPrint('Visit ${visit.id} marked completed; opening report form');
          _showReportFormSheet(updatedVisit);
        } else {
          // Reload visits only if not completing (completion reload is handled by report callback)
          await _loadVisits();
        }
      }
    } catch (e) {
      debugPrint('Error in _handleVisitStatusChanged: $e'); // Added logging
      if (mounted) {
        // Friendly error message for common DB permission problems
        final message = e.toString();
        if (message.contains('row-level-security') || message.contains('RLS') || message.contains('42501') ||
            message.toLowerCase().contains('permission')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permission denied: cannot update visit in remote database. Contact admin or try again later.'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          context.showError(e);
        }
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
          // Simply close the report form and reload visits
          // Don't open another sheet to avoid UI conflicts
          Navigator.of(context).pop();
          
          // Reload visits after report submission
          _loadVisits().then((_) {
            if (!mounted) return;
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report submitted successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
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

      // Update visit in Supabase (with offline cache support)
      await _siteVisitService.updateSiteVisitCached(updatedVisit);

      // Reload visits and update UI
      await _loadVisits();
    } catch (e) {
      if (mounted) {
        context.showError(e);
      }
    }
  }

  // Show notifications panel
  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (_notificationService.unreadCount > 0)
                      TextButton(
                        onPressed: () async {
                          final notifications = _notificationService.currentNotifications;
                          final unreadIds = notifications
                              .where((n) => !n.isRead)
                              .map((n) => n.id)
                              .toList();
                          if (unreadIds.isNotEmpty) {
                            await _notificationService.markManyAsRead(unreadIds);
                          }
                        },
                        child: Text(
                          'Mark all read',
                          style: TextStyle(color: AppColors.primaryBlue),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Notifications list
              Expanded(
                child: StreamBuilder<List<UserNotification>>(
                  stream: _notificationService.watchNotifications(),
                  builder: (context, snapshot) {
                    final notifications = _notificationService.currentNotifications;
                    
                    if (notifications.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return _buildNotificationItem(notification);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(UserNotification notification) {
    final isUnread = !notification.isRead;
    
    return InkWell(
      onTap: () async {
        if (isUnread) {
          await _notificationService.markAsRead(notification.id);
        }
        // Handle navigation based on notification type or link
        if (notification.link != null) {
          // TODO: Navigate to specific screen based on link
          debugPrint('Navigate to: ${notification.link}');
        }
      },
      child: Container(
        color: isUnread ? AppColors.primaryBlue.withOpacity(0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon based on notification type
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getNotificationColor(notification.type).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getNotificationIcon(notification.type),
                color: _getNotificationColor(notification.type),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatNotificationTime(notification.createdAt),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
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

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'warning':
        return Icons.warning_rounded;
      case 'error':
        return Icons.error_rounded;
      case 'success':
        return Icons.check_circle_rounded;
      case 'mmp':
        return Icons.description_rounded;
      case 'chat':
        return Icons.chat_rounded;
      case 'task':
        return Icons.task_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'warning':
        return AppColors.accentYellow;
      case 'error':
        return AppColors.accentRed;
      case 'success':
        return AppColors.accentGreen;
      case 'mmp':
        return AppColors.primaryOrange;
      case 'chat':
        return AppColors.primaryBlue;
      case 'task':
        return Colors.purple;
      default:
        return AppColors.primaryBlue;
    }
  }

  String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
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
      if (mounted) {
        setState(() {
          _nearbyTasks = tasks;
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTasks = false;
        });
      }
      debugPrint('Error loading nearby tasks: $e');
    }
  }

  // Handle task acceptance
  Future<void> _handleTaskAccepted(SiteVisit task) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    try {
      // Accept the task directly
      await _siteVisitService.acceptVisit(task.id, userId);
      
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
      // Decline the task directly
      await _siteVisitService.rejectVisit(task.id, userId, 'Declined by user');

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
      await _siteVisitService.supabase.from('mmp_site_entries').update({
        'additional_data': {
          ...(_currentTrackedTask!.additionalData ?? {}),
          'arrival_latitude': _currentLocation.latitude,
          'arrival_longitude': _currentLocation.longitude,
          'arrival_timestamp': DateTime.now().toUtc().toIso8601String(),
          'journey_path': _journeyPath
              .map((point) => {'lat': point.latitude, 'lng': point.longitude})
              .toList(),
          'arrival_recorded': true,
        },
        'status': 'Ongoing',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
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
          // Active visit overlay
          const ActiveVisitOverlay(),
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

              // My Visits Panel (includes available sites)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 220, // Increased for better tile visibility
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
        StreamBuilder<List<UserNotification>>(
          stream: _notificationService.watchNotifications(),
          builder: (context, snapshot) {
            final unreadCount = _notificationService.unreadCount;
            
            return Stack(
              clipBehavior: Clip.none,
              children: [
                HeaderActionButton(
                  icon: Icons.notifications,
                  tooltip: 'Notifications',
                  backgroundColor: Colors.white,
                  color: AppColors.primaryBlue,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showNotificationsPanel();
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.accentRed,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
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
                _myVisits.where((v) => v.acceptedBy == _authService.currentUser?.id).length,
                AppColors.primaryOrange,
              ),
              _buildStatCounter(
                'Completed',
                _completedVisitsCount,
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ModernCard(
        padding: const EdgeInsets.all(8),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: _myVisits.isEmpty
                  ? Center(
                      child: Text(
                        'No visits available',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _assignedVisits.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final visit = _assignedVisits[index];
                        return _buildVisitCard(visit, showCost: true);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitCard(SiteVisit visit, {bool showCost = false}) {
    // Determine color and status type based on visit status
    Color statusColor;
    StatusType statusType;
    IconData statusIcon;
    final status = visitStatusFromString(visit.status);

    switch (status) {
      case VisitStatus.available:
        statusColor = Colors.red;
        statusType = StatusType.error;
        statusIcon = Icons.assignment_late;
        break;
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

    // Calculate total fee
    final totalFee = (visit.enumeratorFee ?? 0) + (visit.transportFee ?? 0);
    final hasFeesInfo = visit.enumeratorFee != null || visit.transportFee != null;

    return AppCard(
      onTap: () => _selectVisit(visit),
      shadows: AppDesignSystem.shadowMD,
      child: Container(
        width: 240,
        constraints: const BoxConstraints(maxHeight: 150),
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with status icon and site code
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          statusIcon,
                          color: statusColor,
                          size: 12,
                        ),
                      ),
                      // Pending sync indicator
                      if (_pendingSyncVisitIds.contains(visit.id)) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Pending sync - will upload when online',
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_upload_outlined,
                              color: Colors.orange,
                              size: 10,
                            ),
                          ),
                        ),
                      ],
                      // Draft indicator
                      if (_draftVisitIds.contains(visit.id)) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Draft saved - tap to continue',
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_note,
                              color: Colors.blue,
                              size: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (visit.siteCode.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        visit.siteCode,
                        style: AppDesignSystem.bodySmall.copyWith(
                          fontSize: 7,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Site name
              Text(
                visit.siteName ?? 'Unnamed Site',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppDesignSystem.titleMedium.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              // Location
              Row(
                children: [
                  Icon(Icons.location_on, size: 9, color: Colors.grey.shade600),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      visit.locationString.isNotEmpty
                          ? visit.locationString
                          : '${visit.locality}, ${visit.state}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // Main activity (only if not empty and space permits)
              if (visit.mainActivity.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.task_alt, size: 9, color: Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        visit.mainActivity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppDesignSystem.bodySmall.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              if (visit.mainActivity.isNotEmpty) const SizedBox(height: 2),
              // Visit date OR fees (not both to save space)
              if (showCost && hasFeesInfo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.attach_money, size: 10, color: AppColors.primaryBlue),
                      const SizedBox(width: 1),
                      Text(
                        totalFee.toStringAsFixed(0),
                        style: AppDesignSystem.bodySmall.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                )
              else if (visit.dueDate != null)
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 9, color: Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Text(
                      '${visit.dueDate!.day}/${visit.dueDate!.month}/${visit.dueDate!.year}',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              // Status badge
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
                  Icon(Icons.chevron_right, size: 10, color: statusColor),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }

  String _getStatusLabel(String status) {
    return visitStatusFromString(status).label;
  }
}
