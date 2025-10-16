// lib/services/geographical_task_service.dart

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/site_visit.dart';
import '../algorithms/nearest_site_visits.dart';
import '../services/site_visit_service.dart';

class GeographicalTaskService {
  final SiteVisitService _service;

  GeographicalTaskService(this._service);

  /// Gets available tasks in the user's geographical area
  /// Uses current location and nearest_site_visits algorithm
  Future<List<SiteVisitWithDistance>> getNearbyAvailableTasks({
    int maxTasks = 10,
    double maxRadiusKm = 50.0, // 50km radius
  }) async {
    try {
      // Get current user location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLocation = Location(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      // Get all available site visits from service
      final allAvailableVisits = await _service.getAvailableSiteVisits();

      // Filter visits with valid coordinates
      final validVisits = allAvailableVisits.where((visit) {
        return visit.latitude != null && visit.longitude != null;
      }).toList();

      // Use nearest_site_visits algorithm to find closest tasks
      final nearbyTasks = NearestSiteVisits.findNearest(
        userLocation: userLocation,
        availableVisits: validVisits,
        k: maxTasks,
        maxRadiusMeters: maxRadiusKm * 1000, // Convert km to meters
      );

      return nearbyTasks;
    } catch (e) {
      // If location access fails, return empty list
      // Could implement fallback logic here
      return [];
    }
  }

  /// Gets tasks assigned to current user that are in progress
  Future<List<SiteVisit>> getAssignedTasks(String userId) async {
    return await _service.getAcceptedSiteVisits(userId);
  }

  /// Gets tasks assigned to user that need acceptance/decline
  Future<List<SiteVisit>> getPendingAcceptanceTasks(String userId) async {
    return await _service.getAssignedPendingSiteVisits(userId);
  }
}