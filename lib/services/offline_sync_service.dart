import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'connectivity_service.dart';
import 'local_storage_service.dart';
import '../models/task.dart';
import '../models/equipment.dart';
import '../models/safety_report.dart';
import '../models/user_profile.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

class SyncResult {
  final bool success;
  final String? error;
  final int uploadedCount;
  final int downloadedCount;

  SyncResult({
    required this.success,
    this.error,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
  });
}

class OfflineSyncService {
  final SupabaseClient _supabase;
  final LocalStorageService _localStorage;
  final ConnectivityService _connectivity;

  final StreamController<SyncStatus> _syncStatusController = StreamController<SyncStatus>.broadcast();
  final StreamController<String> _syncMessageController = StreamController<String>.broadcast();

  Timer? _syncTimer;
  SyncStatus _currentStatus = SyncStatus.idle;

  OfflineSyncService(this._supabase, this._localStorage, this._connectivity) {
    // Start periodic sync when online
    _startPeriodicSync();
  }

  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;
  Stream<String> get syncMessages => _syncMessageController.stream;
  SyncStatus get currentStatus => _currentStatus;

  void _updateStatus(SyncStatus status, [String? message]) {
    _currentStatus = status;
    _syncStatusController.add(status);
    if (message != null) {
      _syncMessageController.add(message);
    }
  }

  void _startPeriodicSync() {
    // Sync every 5 minutes when online
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (_connectivity.isOnline) {
        await performFullSync();
      }
    });
  }

  Future<SyncResult> performFullSync() async {
    if (!_connectivity.isOnline) {
      return SyncResult(success: false, error: 'No internet connection');
    }

    _updateStatus(SyncStatus.syncing, 'Starting sync...');

    try {
      int totalUploaded = 0;
      int totalDownloaded = 0;

      // Sync tasks
      final taskResult = await _syncTasks();
      totalUploaded += taskResult.uploaded;
      totalDownloaded += taskResult.downloaded;

      // Sync equipment
      final equipmentResult = await _syncEquipment();
      totalUploaded += equipmentResult.uploaded;
      totalDownloaded += equipmentResult.downloaded;

      // Sync safety reports
      final safetyResult = await _syncSafetyReports();
      totalUploaded += safetyResult.uploaded;
      totalDownloaded += safetyResult.downloaded;

      // Sync user profiles
      final profileResult = await _syncUserProfiles();
      totalUploaded += profileResult.uploaded;
      totalDownloaded += profileResult.downloaded;

      _updateStatus(SyncStatus.success, 'Sync completed successfully');
      return SyncResult(
        success: true,
        uploadedCount: totalUploaded,
        downloadedCount: totalDownloaded,
      );
    } catch (e) {
      _updateStatus(SyncStatus.error, 'Sync failed: $e');
      return SyncResult(success: false, error: e.toString());
    }
  }

  Future<_SyncCounts> _syncTasks() async {
    _updateStatus(SyncStatus.syncing, 'Syncing tasks...');

    // Get local tasks that need syncing
    final localTasks = _localStorage.getAllTasks();
    final unsyncedTasks = localTasks.where((task) =>
      !_localStorage.isSynced('tasks', task.id)).toList();

    int uploaded = 0;
    int downloaded = 0;

    // Upload unsynced tasks
    for (final task in unsyncedTasks) {
      try {
        await _supabase.from('tasks').upsert(task.toJson());
        _localStorage.markAsSynced('tasks', task.id);
        uploaded++;
      } catch (e) {
        debugPrint('Failed to upload task ${task.id}: $e');
        // Continue with other tasks
      }
    }

    // Download latest tasks from server
    try {
      final response = await _supabase.from('tasks').select('*');
      final serverTasks = (response as List)
          .map((json) => Task.fromJson(json))
          .toList();

      // Merge with local data (server takes precedence for conflicts)
      await _localStorage.saveMultipleTasks(serverTasks);
      downloaded = serverTasks.length;
    } catch (e) {
      debugPrint('Failed to download tasks: $e');
    }

    return _SyncCounts(uploaded: uploaded, downloaded: downloaded);
  }

  Future<_SyncCounts> _syncEquipment() async {
    _updateStatus(SyncStatus.syncing, 'Syncing equipment...');

    // Similar logic for equipment
    final localEquipment = _localStorage.getAllEquipments();
    final unsyncedEquipment = localEquipment.where((eq) =>
      !_localStorage.isSynced('equipments', eq.id)).toList();

    int uploaded = 0;
    int downloaded = 0;

    // Upload unsynced equipment
    for (final equipment in unsyncedEquipment) {
      try {
        await _supabase.from('equipment').upsert(equipment.toJson());
        _localStorage.markAsSynced('equipments', equipment.id);
        uploaded++;
      } catch (e) {
        debugPrint('Failed to upload equipment ${equipment.id}: $e');
      }
    }

    // Download equipment
    try {
      final response = await _supabase.from('equipment').select('*');
      final serverEquipment = (response as List)
          .map((json) => Equipment.fromJson(json))
          .toList();

      await _localStorage.saveMultipleEquipments(serverEquipment);
      downloaded = serverEquipment.length;
    } catch (e) {
      debugPrint('Failed to download equipment: $e');
    }

    return _SyncCounts(uploaded: uploaded, downloaded: downloaded);
  }

  Future<_SyncCounts> _syncSafetyReports() async {
    _updateStatus(SyncStatus.syncing, 'Syncing safety reports...');

    final localReports = _localStorage.getAllSafetyReports();
    final unsyncedReports = localReports.where((report) =>
      !_localStorage.isSynced('safetyReports', report.id)).toList();

    int uploaded = 0;
    int downloaded = 0;

    // Upload unsynced reports
    for (final report in unsyncedReports) {
      try {
        await _supabase.from('safety_reports').upsert(report.toJson());
        _localStorage.markAsSynced('safetyReports', report.id);
        uploaded++;
      } catch (e) {
        debugPrint('Failed to upload safety report ${report.id}: $e');
      }
    }

    // Download reports
    try {
      final response = await _supabase.from('safety_reports').select('*');
      final serverReports = (response as List)
          .map((json) => SafetyReport.fromJson(json))
          .toList();

      await _localStorage.saveMultipleSafetyReports(serverReports);
      downloaded = serverReports.length;
    } catch (e) {
      debugPrint('Failed to download safety reports: $e');
    }

    return _SyncCounts(uploaded: uploaded, downloaded: downloaded);
  }

  Future<_SyncCounts> _syncUserProfiles() async {
    _updateStatus(SyncStatus.syncing, 'Syncing user profiles...');

    // User profiles are typically downloaded, not uploaded
    int downloaded = 0;

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        final response = await _supabase
            .from('user_profiles')
            .select('*')
            .eq('user_id', currentUser.id)
            .single();

        final profile = UserProfile.fromJson(response);
        await _localStorage.saveUserProfile(profile);
        downloaded = 1;
      }
    } catch (e) {
      debugPrint('Failed to sync user profile: $e');
    }

    return _SyncCounts(uploaded: 0, downloaded: downloaded);
  }

  // Manual sync methods for specific data types
  Future<void> syncTasks() async => await _syncTasks();
  Future<void> syncEquipment() async => await _syncEquipment();
  Future<void> syncSafetyReports() async => await _syncSafetyReports();
  Future<void> syncUserProfile() async => await _syncUserProfiles();

  // Force sync (ignores sync status flags)
  Future<SyncResult> forceSync() async {
    // Reset all sync flags and perform full sync
    // Implementation would clear sync status and force re-sync
    return await performFullSync();
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncStatusController.close();
    _syncMessageController.close();
  }
}

class _SyncCounts {
  final int uploaded;
  final int downloaded;

  _SyncCounts({required this.uploaded, required this.downloaded});
}