// lib/services/location_tracking_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';
import '../models/location_log_model.dart';
import 'field_operations_repository.dart';

// Background task name
const String locationTrackingTask = "locationTrackingTask";

// Background callback handler - must be a top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == locationTrackingTask) {
        // Get current position
        final position = await Geolocator.getCurrentPosition();

        // Get visit ID from input data
        final visitId = inputData?['visitId'] as String?;
        if (visitId == null) return false;

        // Create location log
        final locationLog = LocationLog(
          visitId: visitId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
          heading: position.heading,
          altitude: position.altitude,
        );

        // Store location log
        final repository = FieldOperationsRepository();
        await repository.initialize();
        await repository.saveLocationLog(locationLog);

        debugPrint(
          'Background location tracked: ${position.latitude}, ${position.longitude}',
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error in background location tracking: $e');
      return false;
    }
  });
}

class LocationTrackingService {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;

  LocationTrackingService._internal();

  final FieldOperationsRepository _repository = FieldOperationsRepository();

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _backgroundRegistrationTimer;
  bool _isTrackingEnabled = false;
  String? _currentVisitId;

  // Initialize location service
  Future<void> initialize() async {
    await _repository.initialize();

    // Initialize Workmanager for background tasks
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    // Check if location services are enabled
    await _checkLocationPermission();

    debugPrint('LocationTrackingService initialized');
  }

  // Check and request location permissions
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      // We could request the user to enable location services here
      // but for now we'll just return false
      return false;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, we cannot request permissions.
      debugPrint('Location permissions are permanently denied.');
      return false;
    }

    return true;
  }

  // Start tracking for a specific visit
  Future<bool> startTracking(String visitId) async {
    if (_isTrackingEnabled) {
      await stopTracking(); // Stop existing tracking
    }

    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) return false;

    _currentVisitId = visitId;

    // Start foreground tracking
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter:
            10, // Minimum distance (in meters) before receiving updates
      ),
    ).listen(_onPositionUpdate);

    // Register background task
    _registerBackgroundTask();

    _isTrackingEnabled = true;
    debugPrint('Location tracking started for visit: $visitId');

    return true;
  }

  // Stop tracking
  Future<void> stopTracking() async {
    // Cancel foreground tracking
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    // Cancel background task registration timer
    _backgroundRegistrationTimer?.cancel();
    _backgroundRegistrationTimer = null;

    // Cancel background task
    await Workmanager().cancelByTag(_currentVisitId ?? 'location_tracking');

    _isTrackingEnabled = false;
    _currentVisitId = null;

    debugPrint('Location tracking stopped');
  }

  // Position update handler
  Future<void> _onPositionUpdate(Position position) async {
    if (_currentVisitId == null) return;

    final locationLog = LocationLog(
      visitId: _currentVisitId!,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      heading: position.heading,
      altitude: position.altitude,
    );

    // Save location log
    await _repository.saveLocationLog(locationLog);

    debugPrint('Location tracked: ${position.latitude}, ${position.longitude}');
  }

  // Register background task that re-registers itself
  void _registerBackgroundTask() {
    // Cancel existing timer
    _backgroundRegistrationTimer?.cancel();

    // Schedule the task
    _scheduleBackgroundTask();

    // Re-register the task periodically to ensure it keeps running
    _backgroundRegistrationTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _scheduleBackgroundTask(),
    );
  }

  // Schedule the background task
  Future<void> _scheduleBackgroundTask() async {
    if (_currentVisitId == null) return;

    await Workmanager().registerPeriodicTask(
      _currentVisitId!, // Unique name
      locationTrackingTask, // Task name
      tag: _currentVisitId!, // Tag to cancel by later
      initialDelay: const Duration(seconds: 10),
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      inputData: {'visitId': _currentVisitId},
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );

    debugPrint('Background location tracking task registered');
  }

  // Get current position
  Future<Position> getCurrentPosition() async {
    await _checkLocationPermission();
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Check if tracking is enabled
  bool isTrackingEnabled() {
    return _isTrackingEnabled;
  }

  // Get current visit ID being tracked
  String? getCurrentVisitId() {
    return _currentVisitId;
  }
}
