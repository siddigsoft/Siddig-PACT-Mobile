import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Service for managing offline data storage and synchronization
class OfflineDataService {
  static const String _siteVisitsBox = 'site_visits';
  static const String _reportsBox = 'reports';
  static const String _mmpsBox = 'mmps';
  static const String _chatMessagesBox = 'chat_messages';
  static const String _syncQueueBox = 'sync_queue';
  static const String _lastSyncBox = 'last_sync';

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Initialize Hive and register adapters
  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Open boxes for different data types
    await Hive.openBox(_siteVisitsBox);
    await Hive.openBox(_reportsBox);
    await Hive.openBox(_mmpsBox);
    await Hive.openBox(_chatMessagesBox);
    await Hive.openBox(_syncQueueBox);
    await Hive.openBox(_lastSyncBox);
  }

  /// Check if device is online
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  // ==================== SITE VISITS ====================

  /// Cache site visits for offline access
  Future<void> cacheSiteVisits(List<Map<String, dynamic>> visits) async {
    final box = Hive.box(_siteVisitsBox);
    await box.clear();

    for (var visit in visits) {
      await box.put(visit['id'], jsonEncode(visit));
    }

    await _updateLastSync('site_visits');
  }

  /// Get cached site visits
  Future<List<Map<String, dynamic>>> getCachedSiteVisits() async {
    final box = Hive.box(_siteVisitsBox);
    final List<Map<String, dynamic>> visits = [];

    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        visits.add(Map<String, dynamic>.from(jsonDecode(data)));
      }
    }

    return visits;
  }

  /// Get site visits (online or offline)
  Future<List<Map<String, dynamic>>> getSiteVisits({String? assignedTo}) async {
    if (await isOnline()) {
      try {
        // Fetch from Supabase
        var query = _supabase.from('site_visits').select();

        if (assignedTo != null) {
          query = query.eq('assigned_to', assignedTo);
        }

        final List<dynamic> data = await query;
        final visits = data.map((e) => Map<String, dynamic>.from(e)).toList();

        // Cache for offline use
        await cacheSiteVisits(visits);

        return visits;
      } catch (e) {
        debugPrint('Error fetching site visits online: $e');
        // Fall back to cached data
        return getCachedSiteVisits();
      }
    } else {
      // Return cached data
      return getCachedSiteVisits();
    }
  }

  // ==================== REPORTS ====================

  /// Save report to local queue for syncing
  Future<String> saveReportOffline(Map<String, dynamic> reportData) async {
    final box = Hive.box(_syncQueueBox);
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final queueItem = {
      'id': id,
      'type': 'report',
      'data': reportData,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': false,
    };

    await box.put(id, jsonEncode(queueItem));

    // Also save to reports box for immediate viewing
    final reportsBox = Hive.box(_reportsBox);
    await reportsBox.put(id, jsonEncode(reportData));

    return id;
  }

  /// Get cached reports
  Future<List<Map<String, dynamic>>> getCachedReports() async {
    final box = Hive.box(_reportsBox);
    final List<Map<String, dynamic>> reports = [];

    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        reports.add(Map<String, dynamic>.from(jsonDecode(data)));
      }
    }

    return reports;
  }

  /// Sync pending reports when online
  Future<int> syncPendingReports() async {
    if (!await isOnline()) {
      return 0;
    }

    final box = Hive.box(_syncQueueBox);
    int syncedCount = 0;

    for (var key in box.keys.toList()) {
      final data = box.get(key);
      if (data == null) continue;

      final queueItem = Map<String, dynamic>.from(jsonDecode(data));

      if (queueItem['synced'] == true) continue;
      if (queueItem['type'] != 'report') continue;

      try {
        // Upload report to Supabase
        final reportData = Map<String, dynamic>.from(queueItem['data']);

        // Separate photos from main insert payload
        final List<dynamic> photosRaw = (reportData['photos'] as List?) ?? [];
        final reportInsert = Map<String, dynamic>.from(reportData)
          ..remove('photos');

        // Insert report
        final reportResponse = await _supabase
            .from('reports')
            .insert(reportInsert)
            .select()
            .single();

        // Upload photos to storage and insert metadata
        if (photosRaw.isNotEmpty) {
          final reportId = reportResponse['id'];
          final bucket = 'report_photos';
          final List<Map<String, dynamic>> photoInserts = [];
          for (final item in photosRaw) {
            final photo = Map<String, dynamic>.from(item as Map);
            final localPath = photo['photo_url']?.toString();
            if (localPath == null) continue;
            try {
              final file = File(localPath);
              if (await file.exists()) {
                final fileName = p.basename(localPath);
                final folder = 'reports/$reportId';
                // Upload and get public URL
                final publicUrl = await StorageService().uploadFile(
                  file,
                  bucket,
                  folder: folder,
                );
                photoInserts.add({
                  'report_id': reportId,
                  'photo_url': publicUrl,
                  'storage_path': '$folder/$fileName',
                  'is_synced': true,
                  'last_modified': DateTime.now().toIso8601String(),
                });
              } else {
                // If file no longer exists, skip or insert placeholder
              }
            } catch (e) {
              debugPrint('Failed to upload offline photo $localPath: $e');
            }
          }
          if (photoInserts.isNotEmpty) {
            await _supabase.from('report_photos').insert(photoInserts);
          }
        }

        // Mark as synced
        queueItem['synced'] = true;
        await box.put(key, jsonEncode(queueItem));
        syncedCount++;

        debugPrint('Synced report: ${queueItem['id']}');
      } catch (e) {
        debugPrint('Error syncing report ${queueItem['id']}: $e');
      }
    }

    return syncedCount;
  }

  // ==================== MMPs (Files) ====================

  /// Cache MMP file data for offline access
  Future<void> cacheMMP(
      String mmpId, Map<String, dynamic> mmpData, List<int>? fileBytes) async {
    final box = Hive.box(_mmpsBox);

    final cacheData = {
      'metadata': mmpData,
      'fileBytes': fileBytes != null ? base64Encode(fileBytes) : null,
      'cachedAt': DateTime.now().toIso8601String(),
    };

    await box.put(mmpId, jsonEncode(cacheData));
  }

  /// Get cached MMP
  Future<Map<String, dynamic>?> getCachedMMP(String mmpId) async {
    final box = Hive.box(_mmpsBox);
    final data = box.get(mmpId);

    if (data == null) return null;

    final cacheData = Map<String, dynamic>.from(jsonDecode(data));

    // Decode file bytes if present
    if (cacheData['fileBytes'] != null) {
      cacheData['fileBytes'] = base64Decode(cacheData['fileBytes']);
    }

    return cacheData;
  }

  /// Get all cached MMPs
  Future<List<Map<String, dynamic>>> getCachedMMPs() async {
    final box = Hive.box(_mmpsBox);
    final List<Map<String, dynamic>> mmps = [];

    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final cacheData = Map<String, dynamic>.from(jsonDecode(data));
        mmps.add(cacheData['metadata'] as Map<String, dynamic>);
      }
    }

    return mmps;
  }

  // ==================== CHAT MESSAGES ====================

  /// Cache chat messages for offline access
  Future<void> cacheChatMessages(
      String chatId, List<Map<String, dynamic>> messages) async {
    final box = Hive.box(_chatMessagesBox);
    await box.put(chatId, jsonEncode(messages));
  }

  /// Get cached chat messages
  Future<List<Map<String, dynamic>>> getCachedChatMessages(
      String chatId) async {
    final box = Hive.box(_chatMessagesBox);
    final data = box.get(chatId);

    if (data == null) return [];

    final List<dynamic> messages = jsonDecode(data);
    return messages.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Save chat message to local queue for syncing
  Future<String> saveChatMessageOffline(
      Map<String, dynamic> messageData) async {
    final box = Hive.box(_syncQueueBox);
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final queueItem = {
      'id': id,
      'type': 'chat_message',
      'data': messageData,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': false,
    };

    await box.put(id, jsonEncode(queueItem));

    return id;
  }

  /// Sync pending chat messages when online
  Future<int> syncPendingChatMessages() async {
    if (!await isOnline()) {
      return 0;
    }

    final box = Hive.box(_syncQueueBox);
    int syncedCount = 0;

    for (var key in box.keys.toList()) {
      final data = box.get(key);
      if (data == null) continue;

      final queueItem = Map<String, dynamic>.from(jsonDecode(data));

      if (queueItem['synced'] == true) continue;
      if (queueItem['type'] != 'chat_message') continue;

      try {
        // Upload message to Supabase
        final messageData = Map<String, dynamic>.from(queueItem['data']);

        await _supabase.from('chat_messages').insert(messageData);

        // Mark as synced
        queueItem['synced'] = true;
        await box.put(key, jsonEncode(queueItem));
        syncedCount++;

        debugPrint('Synced chat message: ${queueItem['id']}');
      } catch (e) {
        debugPrint('Error syncing chat message ${queueItem['id']}: $e');
      }
    }

    return syncedCount;
  }

  // ==================== SYNC MANAGEMENT ====================

  /// Sync all pending data
  Future<Map<String, int>> syncAll() async {
    final results = {
      'visit_status': await syncPendingVisitStatuses(),
      'reports': await syncPendingReports(),
      'site_locations': await syncPendingSiteLocations(),
      'chat_messages': await syncPendingChatMessages(),
    };

    return results;
  }

  /// Get pending sync count
  Future<int> getPendingSyncCount() async {
    final box = Hive.box(_syncQueueBox);
    int count = 0;

    for (var key in box.keys) {
      final data = box.get(key);
      if (data == null) continue;

      final queueItem = Map<String, dynamic>.from(jsonDecode(data));
      if (queueItem['synced'] != true) {
        count++;
      }
    }

    return count;
  }

  /// Clear synced items from queue
  Future<void> clearSyncedItems() async {
    final box = Hive.box(_syncQueueBox);

    for (var key in box.keys.toList()) {
      final data = box.get(key);
      if (data == null) continue;

      final queueItem = Map<String, dynamic>.from(jsonDecode(data));
      if (queueItem['synced'] == true) {
        await box.delete(key);
      }
    }
  }

  /// Update last sync timestamp
  Future<void> _updateLastSync(String dataType) async {
    final box = Hive.box(_lastSyncBox);
    await box.put(dataType, DateTime.now().toIso8601String());
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSync(String dataType) async {
    final box = Hive.box(_lastSyncBox);
    final timestamp = box.get(dataType);

    if (timestamp == null) return null;

    return DateTime.parse(timestamp);
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    await Hive.box(_siteVisitsBox).clear();
    await Hive.box(_reportsBox).clear();
    await Hive.box(_mmpsBox).clear();
    await Hive.box(_chatMessagesBox).clear();
    await Hive.box(_lastSyncBox).clear();
  }

  /// Close all boxes
  static Future<void> dispose() async {
    await Hive.close();
  }

  // ==================== VISIT STATUS OFFLINE QUEUE ====================

  /// Queue a visit status change for later sync
  Future<String> queueVisitStatusUpdate({
    required String visitId,
    required String newStatus,
    Map<String, dynamic>? extra,
  }) async {
    final box = Hive.box(_syncQueueBox);
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final payload = {
      'visit_id': visitId,
      'status': newStatus,
      'extra': extra,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final queueItem = {
      'id': id,
      'type': 'visit_status',
      'data': payload,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': false,
    };
    await box.put(id, jsonEncode(queueItem));
    return id;
  }

  /// Sync pending visit status updates
  Future<int> syncPendingVisitStatuses() async {
    if (!await isOnline()) return 0;

    final box = Hive.box(_syncQueueBox);
    int synced = 0;
    for (final key in box.keys.toList()) {
      final data = box.get(key);
      if (data == null) continue;
      final queueItem = Map<String, dynamic>.from(jsonDecode(data));
      if (queueItem['synced'] == true) continue;
      if (queueItem['type'] != 'visit_status') continue;

      try {
        final payload = Map<String, dynamic>.from(queueItem['data']);
        final visitId = payload['visit_id'] as String;
        final status = payload['status'] as String;

        await _supabase.from('mmp_site_entries').update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', visitId);

        queueItem['synced'] = true;
        await box.put(key, jsonEncode(queueItem));
        synced++;
      } catch (e) {
        debugPrint('Error syncing visit status $key: $e');
      }
    }

    return synced;
  }

  // ==================== SITE LOCATIONS OFFLINE QUEUE ====================

  /// Queue site location capture for later sync
  Future<String> queueSiteLocation(Map<String, dynamic> locationData) async {
    final box = Hive.box(_syncQueueBox);
    final id = 'site_location_${DateTime.now().millisecondsSinceEpoch}';
    final queueItem = {
      'id': id,
      'type': 'site_location',
      'data': locationData,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': false,
    };
    await box.put(id, jsonEncode(queueItem));
    return id;
  }

  /// Sync pending site locations
  Future<int> syncPendingSiteLocations() async {
    if (!await isOnline()) return 0;

    final box = Hive.box(_syncQueueBox);
    int synced = 0;
    for (final key in box.keys.toList()) {
      final data = box.get(key);
      if (data == null) continue;
      final queueItem = Map<String, dynamic>.from(jsonDecode(data));
      if (queueItem['synced'] == true) continue;
      if (queueItem['type'] != 'site_location') continue;

      try {
        final payload = Map<String, dynamic>.from(queueItem['data']);
        await _supabase
            .from('site_locations')
            .upsert(payload, onConflict: 'site_id')
            .select('site_id')
            .single();

        queueItem['synced'] = true;
        await box.put(key, jsonEncode(queueItem));
        synced++;
      } catch (e) {
        debugPrint('Error syncing site location $key: $e');
      }
    }
    return synced;
  }
}
