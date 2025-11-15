import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_data_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/site_visit.dart';

class SiteVisitService {
  final SupabaseClient _supabase = Supabase.instance.client;

  SupabaseClient get supabase => _supabase;

  Future<List<Map<String, dynamic>>> getAssignedSiteVisits(
    String userId,
  ) async {
    final response = await _supabase
        .from('site_visits')
        .select()
        .eq('assigned_to', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> getSiteVisitDetails(String visitId) async {
    final response =
        await _supabase.from('site_visits').select().eq('id', visitId).single();

    return response;
  }

  Future<void> updateSiteVisitStatus(String visitId, String status) async {
    try {
      print('🔄 Updating visit status: $visitId -> $status');
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final hasConnection = connectivity != ConnectivityResult.none;
      if (!hasConnection) {
        // Queue offline
        await OfflineDataService().queueVisitStatusUpdate(
          visitId: visitId,
          newStatus: status,
          extra: {
            'queued_at': DateTime.now().toIso8601String(),
          },
        );
        print('📦 Visit status queued for sync (offline).');
        await _updateCachedVisitStatus(visitId, status);
        return;
      }
      await _supabase.from('site_visits').update({
        'status': status,
        'user_id': _supabase.auth.currentUser?.id,
        'last_modified': DateTime.now().toIso8601String(),
      }).eq('id', visitId);
      print('✅ Visit status updated in Supabase');
      await _updateCachedVisitStatus(visitId, status);
    } catch (e) {
      print('❌ Failed to update visit status: $e');
      rethrow;
    }
  }

  Future<void> updateSiteVisit(SiteVisit visit) async {
    try {
      print('🔄 Updating visit: ${visit.id}');
      final connectivity = await Connectivity().checkConnectivity();
      final hasConnection = connectivity != ConnectivityResult.none;
      if (!hasConnection) {
        await _queueVisitForSync(visit);
        await _updateLocalCacheWithVisit(visit);
        print('📦 Visit update queued for sync (offline).');
        return;
      }
      final visitData = visit.toJson();
      await _supabase.from('site_visits').update(visitData).eq('id', visit.id);
      print('✅ Visit updated in Supabase');
      await _updateLocalCacheWithVisit(visit);
    } catch (e) {
      print('❌ Failed to update visit: $e');
      await _queueVisitForSync(visit);
      await _updateLocalCacheWithVisit(visit);
      rethrow;
    }
  }

  Future<List<SiteVisit>> getAvailableSiteVisits() async {
    final response = await _supabase
        .from('site_visits')
        .select()
        .eq('status', 'available')
        .order('created_at', ascending: false);

    return response.map((json) => SiteVisit.fromJson(json)).toList();
  }

  Future<List<SiteVisit>> getAcceptedSiteVisits(String userId) async {
    final response = await _supabase
        .from('site_visits')
        .select()
        .eq('assigned_to', userId)
        .eq('status', 'accepted')
        .order('created_at', ascending: false);

    return response.map((json) => SiteVisit.fromJson(json)).toList();
  }

  Future<List<SiteVisit>> getAssignedPendingSiteVisits(String userId) async {
    final response = await _supabase
        .from('site_visits')
        .select()
        .eq('assigned_to', userId)
        .eq('status', 'assigned')
        .order('created_at', ascending: false);

    return response.map((json) => SiteVisit.fromJson(json)).toList();
  }

  Future<SiteVisit?> getSiteVisitById(String id) async {
    final response =
        await _supabase.from('site_visits').select().eq('id', id).single();

    return SiteVisit.fromJson(response);
  }

  Future<void> markTaskDeclined(String taskId, String userId) async {
    // This could be implemented as a separate table for declined tasks
    // For now, we'll just log it locally or update a declined status
    await _supabase.from('site_visits').update({
      'status': 'declined',
      'declined_by': userId,
      'declined_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId);
  }

  // ===== LOCAL STORAGE METHODS =====

  /// Initialize Hive boxes for local storage
  static Future<void> initializeLocalStorage() async {
    await Hive.initFlutter();
    // Register adapters if needed for complex objects
  }

  /// Get local visits box
  Future<Box> _getVisitsBox() async {
    return await Hive.openBox('visits_cache');
  }

  /// Cache visits data locally for offline access
  Future<void> cacheVisitsLocally(
      List<SiteVisit> visits, String cacheKey) async {
    try {
      final box = await _getVisitsBox();
      final visitsJson = visits.map((visit) => visit.toJson()).toList();
      await box.put(cacheKey, {
        'data': visitsJson,
        'cached_at': DateTime.now().toIso8601String(),
        'count': visits.length,
      });
    } catch (e) {
      print('Error caching visits locally: $e');
    }
  }

  /// Get cached visits data
  Future<List<SiteVisit>?> getCachedVisits(String cacheKey) async {
    try {
      final box = await _getVisitsBox();
      final cached = box.get(cacheKey);
      if (cached == null) return null;

      final visitsJson = cached['data'] as List<dynamic>;
      return visitsJson.map((json) => SiteVisit.fromJson(json)).toList();
    } catch (e) {
      print('Error getting cached visits: $e');
      return null;
    }
  }

  Future<List<SiteVisit>> getAssignedSiteVisitsFromCache(String userId) async {
    final cached = await getCachedVisits('assigned_$userId');
    return cached ?? [];
  }

  /// Get assigned site visits with local caching
  Future<List<Map<String, dynamic>>> getAssignedSiteVisitsCached(
    String userId,
  ) async {
    try {
      // Try to get from remote first
      final remoteData = await getAssignedSiteVisits(userId);

      // Cache the data locally
      final visits =
          remoteData.map((json) => SiteVisit.fromJson(json)).toList();
      await cacheVisitsLocally(visits, 'assigned_$userId');

      return remoteData;
    } catch (e) {
      // If remote fails, try to get from cache
      print('Remote fetch failed, trying cache: $e');
      final cachedVisits = await getCachedVisits('assigned_$userId');
      if (cachedVisits != null) {
        return cachedVisits.map((visit) => visit.toJson()).toList();
      }
      rethrow; // Re-throw if no cache available
    }
  }

  /// Get available site visits with local caching
  Future<List<SiteVisit>> getAvailableSiteVisitsCached() async {
    try {
      // Try to get from remote first
      final remoteData = await getAvailableSiteVisits();

      // Cache the data locally
      await cacheVisitsLocally(remoteData, 'available_visits');

      return remoteData;
    } catch (e) {
      // If remote fails, try to get from cache
      print('Remote fetch failed, trying cache: $e');
      final cachedVisits = await getCachedVisits('available_visits');
      if (cachedVisits != null) {
        return cachedVisits;
      }
      rethrow; // Re-throw if no cache available
    }
  }

  /// Update site visit with local caching and sync queue
  Future<void> updateSiteVisitCached(SiteVisit visit) async {
    try {
      // Update remote first
      await updateSiteVisit(visit);

      // Update local cache if it exists
      await _updateLocalCacheWithVisit(visit);
    } catch (e) {
      // If remote fails, queue for later sync
      print('Remote update failed, queuing for sync: $e');
      await _queueVisitForSync(visit);
      await _updateLocalCacheWithVisit(visit);
      rethrow;
    }
  }

  /// Queue visit update for later synchronization
  Future<void> _queueVisitForSync(SiteVisit visit) async {
    try {
      final box = await Hive.openBox('sync_queue');
      final queueItem = {
        'id': visit.id,
        'data': visit.toJson(),
        'operation': 'update',
        'timestamp': DateTime.now().toIso8601String(),
        'retry_count': 0,
      };
      await box.put('visit_${visit.id}', queueItem);
    } catch (e) {
      print('Error queuing visit for sync: $e');
    }
  }

  /// Update local cache with single visit
  Future<void> _updateLocalCacheWithVisit(SiteVisit visit) async {
    try {
      final box = await _getVisitsBox();

      // Update in assigned visits cache
      final assignedCache = box.get('assigned_${visit.assignedTo}');
      if (assignedCache != null) {
        final visitsJson = assignedCache['data'] as List<dynamic>;
        final updatedVisits = visitsJson.map((json) {
          if (json['id'] == visit.id) {
            return visit.toJson();
          }
          return json;
        }).toList();

        await box.put('assigned_${visit.assignedTo}', {
          'data': updatedVisits,
          'cached_at': DateTime.now().toIso8601String(),
          'count': updatedVisits.length,
        });
      }

      // Update in available visits cache if applicable
      final availableCache = box.get('available_visits');
      if (availableCache != null && visit.status == 'available') {
        final visitsJson = availableCache['data'] as List<dynamic>;
        final updatedVisits = visitsJson.map((json) {
          if (json['id'] == visit.id) {
            return visit.toJson();
          }
          return json;
        }).toList();

        await box.put('available_visits', {
          'data': updatedVisits,
          'cached_at': DateTime.now().toIso8601String(),
          'count': updatedVisits.length,
        });
      }
    } catch (e) {
      print('Error updating local cache: $e');
    }
  }

  Future<void> _updateCachedVisitStatus(String visitId, String status) async {
    try {
      final box = await _getVisitsBox();
      for (final key in box.keys) {
        final cached = box.get(key);
        if (cached == null || cached['data'] == null) continue;
        final List<dynamic> visitsJson = List<dynamic>.from(cached['data']);
        bool updated = false;
        final updatedVisits = visitsJson.map((json) {
          if (json['id'] == visitId) {
            updated = true;
            return {
              ...json,
              'status': status,
              'last_modified': DateTime.now().toIso8601String(),
            };
          }
          return json;
        }).toList();

        if (updated) {
          await box.put(key, {
            'data': updatedVisits,
            'cached_at': DateTime.now().toIso8601String(),
            'count': updatedVisits.length,
          });
        }
      }
    } catch (e) {
      print('Error updating cached visit status: $e');
    }
  }

  /// Sync queued visit updates when online
  Future<void> syncQueuedVisits() async {
    try {
      final box = await Hive.openBox('sync_queue');
      final keys = box.keys.where((key) => key.toString().startsWith('visit_'));

      for (final key in keys) {
        final queueItem = box.get(key);
        if (queueItem != null) {
          try {
            final visit = SiteVisit.fromJson(queueItem['data']);
            await updateSiteVisit(visit);
            await box.delete(key); // Remove from queue on success
          } catch (e) {
            // Increment retry count
            queueItem['retry_count'] = (queueItem['retry_count'] ?? 0) + 1;
            if (queueItem['retry_count'] > 3) {
              await box.delete(key); // Remove after max retries
            } else {
              await box.put(key, queueItem);
            }
            print('Failed to sync visit ${queueItem['id']}: $e');
          }
        }
      }
    } catch (e) {
      print('Error syncing queued visits: $e');
    }
  }

  /// Clear all local cache data
  Future<void> clearLocalCache() async {
    try {
      final visitsBox = await _getVisitsBox();
      await visitsBox.clear();

      final syncBox = await Hive.openBox('sync_queue');
      await syncBox.clear();
    } catch (e) {
      print('Error clearing local cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final visitsBox = await _getVisitsBox();
      final syncBox = await Hive.openBox('sync_queue');

      return {
        'cached_visits_count': visitsBox.length,
        'queued_sync_operations': syncBox.length,
        'cache_keys': visitsBox.keys.toList(),
      };
    } catch (e) {
      print('Error getting cache stats: $e');
      return {};
    }
  }

  // ===== ADDITIONAL METHODS FROM SITE VISITS SERVICE =====

  Future<List<Map<String, dynamic>>>
      getAssignedSiteVisitsForCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
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
    final allVisits = await getAssignedSiteVisitsForCurrentUser();
    final currentCity = await getCurrentCity();
    if (currentCity == null) return allVisits;

    // Filter by site_code matching current city
    return allVisits
        .where((visit) => visit['site_code'] == currentCity)
        .toList();
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

      await _supabase.from('site_visits').update({
        'status': 'arrived',
        'arrival_recorded': true,
        'arrival_timestamp': DateTime.now().toIso8601String(),
      }).eq('id', visitId);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Update visit with arrival data
      await _supabase.from('site_visits').update({
        'status': 'arrived',
        'arrival_recorded': true,
        'arrival_latitude': position.latitude,
        'arrival_longitude': position.longitude,
        'arrival_timestamp': DateTime.now().toIso8601String(),
      }).eq('id', visitId);

      // Store locally for backup
      final prefs = await SharedPreferences.getInstance();
      final gpsData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString('arrival_$visitId', gpsData.toString());
    } catch (e) {
      throw Exception('Failed to confirm arrival: $e');
    }
  }

  // Placeholder for loading MMPs based on site_code
  Future<List<Map<String, dynamic>>> getMMPsForSite(String siteCode) async {
    // Assuming an 'mmps' table exists; filter by site_code
    final response = await _supabase
        .from('mmps') // Replace with actual table name
        .select()
        .eq('site_code', siteCode);
    return List<Map<String, dynamic>>.from(response);
  }
}
