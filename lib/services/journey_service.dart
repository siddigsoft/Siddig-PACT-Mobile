// lib/services/journey_service.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/site_visit.dart';
import '../algorithms/route_optimizer.dart';
import '../algorithms/nearest_site_visits.dart';
import '../services/location_tracking_service.dart';
import '../services/staff_tracking_service.dart';

class JourneyWaypoint {
  final SiteVisit visit;
  final LatLng position;
  final int order;
  final bool isCompleted;

  JourneyWaypoint({
    required this.visit,
    required this.position,
    required this.order,
    this.isCompleted = false,
  });
}

class JourneyProgress {
  final List<JourneyWaypoint> waypoints;
  final JourneyWaypoint? currentWaypoint;
  final double distanceTraveled;
  final Duration timeElapsed;
  final LatLng currentPosition;

  JourneyProgress({
    required this.waypoints,
    this.currentWaypoint,
    required this.distanceTraveled,
    required this.timeElapsed,
    required this.currentPosition,
  });

  double get progressPercentage {
    final completedCount = waypoints.where((w) => w.isCompleted).length;
    return waypoints.isEmpty ? 0.0 : (completedCount / waypoints.length) * 100;
  }
}

class JourneyService {
  final LocationTrackingService _locationTracking;
  final StaffTrackingService _staffTracking;

  JourneyService(this._locationTracking, this._staffTracking);

  StreamSubscription<Position>? _journeyTrackingSubscription;
  List<JourneyWaypoint> _currentJourney = [];
  DateTime? _journeyStartTime;
  double _lastDistance = 0.0;

  /// Start a journey with optimized route for assigned tasks
  Future<List<JourneyWaypoint>> startJourney({
    required List<SiteVisit> assignedTasks,
    required LatLng startPosition,
  }) async {
    // Optimize route using route_optimizer algorithm
    final optimizedRoute = RouteOptimizer.optimizeRoute(
      visits: assignedTasks,
      startLocation: Location(
        latitude: startPosition.latitude,
        longitude: startPosition.longitude,
      ),
    );

    // Create journey waypoints
    _currentJourney = [];
    for (int i = 0; i < optimizedRoute.length; i++) {
      final visit = optimizedRoute[i];
      _currentJourney.add(JourneyWaypoint(
        visit: visit,
        position: LatLng(visit.latitude!, visit.longitude!),
        order: i + 1,
      ));
    }

    // Start journey tracking
    _journeyStartTime = DateTime.now();
    await _startJourneyTracking();

    return _currentJourney;
  }

  /// Start location tracking for the journey
  Future<void> _startJourneyTracking() async {
    // Start location tracking with journey-specific settings
    await _locationTracking.initialize();

    // Configure for journey tracking - balance between accuracy and battery
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
      timeLimit: Duration(seconds: 30),
    );

    _journeyTrackingSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onLocationUpdate);
  }

  /// Handle location updates during journey
  void _onLocationUpdate(Position position) {
    final currentLatLng = LatLng(position.latitude, position.longitude);

    // Check if we've reached the current waypoint
    _checkWaypointCompletion(currentLatLng);

    // Update journey progress
    _updateJourneyProgress(currentLatLng, position);
  }

  /// Check if current waypoint has been reached
  void _checkWaypointCompletion(LatLng currentPosition) {
    if (_currentJourney.isEmpty) return;

    final currentWaypoint = _currentJourney.firstWhere(
      (waypoint) => !waypoint.isCompleted,
      orElse: () => _currentJourney.last,
    );

    if (currentWaypoint.isCompleted) return;

    // Calculate distance to current waypoint
    final distance = _calculateDistance(currentPosition, currentWaypoint.position);

    // If within 50 meters of waypoint, mark as completed
    if (distance <= 50.0) {
      _markWaypointCompleted(currentWaypoint);
    }
  }

  /// Mark a waypoint as completed
  void _markWaypointCompleted(JourneyWaypoint waypoint) {
    final index = _currentJourney.indexOf(waypoint);
    if (index != -1) {
      _currentJourney[index] = JourneyWaypoint(
        visit: waypoint.visit,
        position: waypoint.position,
        order: waypoint.order,
        isCompleted: true,
      );
    }
  }

  /// Update journey progress metrics
  void _updateJourneyProgress(LatLng currentPosition, Position position) {
    // Calculate distance traveled since last update
    if (_lastDistance > 0) {
      final newDistance = _calculateDistanceFromLastPosition(currentPosition);
      _lastDistance += newDistance;
    } else {
      _lastDistance = 0.0;
    }
  }

  /// Get current journey progress
  JourneyProgress getCurrentProgress(LatLng currentPosition) {
    final currentWaypoint = _currentJourney.isNotEmpty
        ? _currentJourney.firstWhere(
            (waypoint) => !waypoint.isCompleted,
            orElse: () => _currentJourney.last,
          )
        : null;

    final timeElapsed = _journeyStartTime != null
        ? DateTime.now().difference(_journeyStartTime!)
        : Duration.zero;

    return JourneyProgress(
      waypoints: _currentJourney,
      currentWaypoint: currentWaypoint,
      distanceTraveled: _lastDistance,
      timeElapsed: timeElapsed,
      currentPosition: currentPosition,
    );
  }

  /// Stop journey tracking
  Future<void> stopJourney() async {
    await _journeyTrackingSubscription?.cancel();
    _journeyTrackingSubscription = null;
    _currentJourney.clear();
    _journeyStartTime = null;
    _lastDistance = 0.0;

    await _locationTracking.stopTracking();
  }

  /// Calculate distance between two LatLng points
  double _calculateDistance(LatLng point1, LatLng point2) {
    return _haversineDistance(
      point1.latitude, point1.longitude,
      point2.latitude, point2.longitude,
    );
  }

  /// Calculate distance from last known position
  double _calculateDistanceFromLastPosition(LatLng currentPosition) {
    // This would need to track the last position
    // For simplicity, returning 0 - implement proper distance calculation
    return 0.0;
  }

  /// Haversine distance calculation
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * (3.141592653589793 / 180);

  /// Get optimized route polyline for map display
  List<LatLng> getRoutePolyline() {
    return _currentJourney.map((waypoint) => waypoint.position).toList();
  }

  /// Check if journey is completed
  bool get isJourneyCompleted {
    return _currentJourney.every((waypoint) => waypoint.isCompleted);
  }
}