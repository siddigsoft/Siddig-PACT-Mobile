// lib/services/sync_manager.dart
import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/location_log_model.dart';
import '../models/report_model.dart';
import '../models/visit_model.dart';
import 'field_operations_repository.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;

  SyncManager._internal();

  final FieldOperationsRepository _repository = FieldOperationsRepository();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicSyncTimer;

  bool _isSyncing = false;
  bool _isInitialized = false;

  // API endpoints for sync - replace with real API endpoints
  static const String _apiBaseUrl = 'https://api.example.com';
  static const String _visitsSyncEndpoint = '/visits';
  static const String _locationLogsSyncEndpoint = '/location-logs';
  static const String _reportsSyncEndpoint = '/reports';

  // Initialize the sync manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _repository.initialize();

    // Set up connectivity monitoring
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    // Set up periodic sync (every 30 minutes)
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _checkAndSync(),
    );

    // Check connectivity immediately
    final connectivityResult = await _connectivity.checkConnectivity();
    _handleConnectivityChange(connectivityResult);

    _isInitialized = true;
    debugPrint('SyncManager initialized');
  }

  // Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasConnectivity =
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);

    if (hasConnectivity) {
      debugPrint('Connectivity restored, checking for sync');
      _checkAndSync();
    }
  }

  // Check and sync data if needed
  Future<void> _checkAndSync() async {
    // Skip if already syncing or not online
    if (_isSyncing) return;

    final isCollectorOnline = await _repository.getCollectorStatus();
    if (!isCollectorOnline) {
      debugPrint('Collector is offline, skipping sync');
      return;
    }

    await syncData();
  }

  // Sync all data
  Future<bool> syncData() async {
    if (_isSyncing) return false;

    _isSyncing = true;
    debugPrint('Starting data sync');

    try {
      // Get all unsynced data
      final unsyncedVisits = await _repository.getUnsyncedVisits();
      final unsyncedLogs = await _repository.getUnsyncedLocationLogs();
      final unsyncedReports = await _repository.getUnsyncedReports();

      debugPrint(
        'Unsynced data: ${unsyncedVisits.length} visits, '
        '${unsyncedLogs.length} location logs, '
        '${unsyncedReports.length} reports',
      );

      // Sync each type of data
      final visitsSuccess = await _syncVisits(unsyncedVisits);
      final logsSuccess = await _syncLocationLogs(unsyncedLogs);
      final reportsSuccess = await _syncReports(unsyncedReports);

      // Clean up old data
      await _repository.wipeOldSyncedData(30); // Wipe data older than 30 days

      _isSyncing = false;
      return visitsSuccess && logsSuccess && reportsSuccess;
    } catch (e) {
      debugPrint('Error during sync: $e');
      _isSyncing = false;
      return false;
    }
  }

  // Force sync immediately
  Future<bool> forceSyncNow() async {
    return syncData();
  }

  // Sync visits
  Future<bool> _syncVisits(List<Visit> visits) async {
    if (visits.isEmpty) return true;

    try {
      for (final visit in visits) {
        // In a real app, this would be an API call
        final response = await http.post(
          Uri.parse('$_apiBaseUrl$_visitsSyncEndpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(visit.toMap()),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _repository.markVisitSynced(visit.id);
          debugPrint('Synced visit ${visit.id}');
        } else if (response.statusCode == 409) {
          // Conflict - another collector took this visit
          final updatedVisit = visit.copyWith(status: VisitStatus.rejected);
          await _repository.saveVisit(updatedVisit);
          await _repository.markVisitSynced(visit.id);
          debugPrint('Visit ${visit.id} rejected due to conflict');
        } else {
          debugPrint(
            'Failed to sync visit ${visit.id}: ${response.statusCode}',
          );
          // Don't mark as synced, will retry later
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error syncing visits: $e');
      return false;
    }
  }

  // Sync location logs
  Future<bool> _syncLocationLogs(List<LocationLog> logs) async {
    if (logs.isEmpty) return true;

    try {
      // Group logs by visit ID for efficiency
      final Map<String, List<LocationLog>> groupedLogs = {};
      for (final log in logs) {
        if (!groupedLogs.containsKey(log.visitId)) {
          groupedLogs[log.visitId] = [];
        }
        groupedLogs[log.visitId]!.add(log);
      }

      // Sync each group
      for (final entry in groupedLogs.entries) {
        final visitId = entry.key;
        final visitLogs = entry.value;

        // In a real app, this would be an API call
        final response = await http.post(
          Uri.parse('$_apiBaseUrl$_locationLogsSyncEndpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'visitId': visitId,
            'logs': visitLogs.map((log) => log.toMap()).toList(),
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          for (final log in visitLogs) {
            await _repository.markLocationLogSynced(log.id);
          }
          debugPrint(
            'Synced ${visitLogs.length} location logs for visit $visitId',
          );
        } else {
          debugPrint(
            'Failed to sync location logs for visit $visitId: ${response.statusCode}',
          );
          // Don't mark as synced, will retry later
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error syncing location logs: $e');
      return false;
    }
  }

  // Sync reports
  Future<bool> _syncReports(List<Report> reports) async {
    if (reports.isEmpty) return true;

    try {
      for (final report in reports) {
        // In a real app, this would be an API call
        final response = await http.post(
          Uri.parse('$_apiBaseUrl$_reportsSyncEndpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(report.toMap()),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _repository.markReportSynced(report.id);
          debugPrint('Synced report ${report.id} for visit ${report.visitId}');
        } else {
          debugPrint(
            'Failed to sync report ${report.id}: ${response.statusCode}',
          );
          // Don't mark as synced, will retry later
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error syncing reports: $e');
      return false;
    }
  }

  // Check if currently syncing
  bool isSyncing() {
    return _isSyncing;
  }

  // Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _isInitialized = false;
  }
}
