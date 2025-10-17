import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SiteVisitsService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getAssignedSiteVisits() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('site_visits')
        .select()
        .eq('assigned_to', user.id)
        .order('due_date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<String?> getCurrentCity() async {
    if (kIsWeb) {
      // On web, we can't reliably get location without user interaction
      // Return null to show all visits
      return null;
    }
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      return placemarks.first.locality; // e.g., "Kampala"
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getNearbySiteVisits() async {
    final allVisits = await getAssignedSiteVisits();
    final currentCity = await getCurrentCity();
    if (currentCity == null) return allVisits;

    // Filter by site_code matching current city
    return allVisits.where((visit) => visit['site_code'] == currentCity).toList();
  }

  Future<void> confirmArrival(String visitId) async {
    if (kIsWeb) {
      // On web, GPS might not be available, store a placeholder
      final gpsData = {
        'latitude': 0.0,
        'longitude': 0.0,
        'timestamp': DateTime.now().toIso8601String(),
        'note': 'Location not available on web',
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('arrival_$visitId', gpsData.toString());

      await supabase
          .from('site_visits')
          .update({'status': 'arrived'})
          .eq('id', visitId);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final gpsData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Store locally (replace with Supabase table later)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('arrival_$visitId', gpsData.toString());

      // Update visit status in Supabase
      await supabase
          .from('site_visits')
          .update({'status': 'arrived'})
          .eq('id', visitId);
    } catch (e) {
      throw Exception('Failed to confirm arrival: $e');
    }
  }

  // Placeholder for loading MMPs based on site_code
  Future<List<Map<String, dynamic>>> getMMPsForSite(String siteCode) async {
    // Assuming an 'mmps' table exists; filter by site_code
    final response = await supabase
        .from('mmps') // Replace with actual table name
        .select()
        .eq('site_code', siteCode);
    return List<Map<String, dynamic>>.from(response);
  }
}