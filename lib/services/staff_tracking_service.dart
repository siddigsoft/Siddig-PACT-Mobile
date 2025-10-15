import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/location_log_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class StaffTrackingService {
  final SupabaseClient _supabase;
  Timer? _uploadTimer;
  StreamSubscription<Position>? _positionStream;
  final List<LocationLog> _pendingLogs = [];
  final int _batchSize = 50;
  final int _uploadIntervalSeconds = 300; // 5 minutes
  
  StaffTrackingService(this._supabase);

  /// Start tracking staff movement
  Future<void> startTracking(String userId) async {
    // Request location permissions
    final permission = await _requestLocationPermission();
    if (!permission) {
      throw Exception('Location permission denied');
    }

    // Configure location tracking
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20, // meters
      timeLimit: Duration(seconds: 30),
    );

    // Start location updates
    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) async {
      final log = LocationLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        accuracy: position.accuracy,
        speed: position.speed,
      );

      _pendingLogs.add(log);
      
      // If we have enough logs, try to upload
      if (_pendingLogs.length >= _batchSize) {
        await _uploadPendingLogs();
      }
    });

    // Set up periodic uploads
    _uploadTimer = Timer.periodic(
      Duration(seconds: _uploadIntervalSeconds),
      (_) => _uploadPendingLogs(),
    );
  }

  /// Upload pending location logs to Supabase
  Future<void> _uploadPendingLogs() async {
    if (_pendingLogs.isEmpty) return;

    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return; // No internet connection
    }

    try {
      // Take a batch of logs
      final logsToUpload = _pendingLogs.take(_batchSize).toList();
      final logData = logsToUpload.map((log) => log.toJson()).toList();

      // Upload to Supabase
      final response = await _supabase.rpc(
        'upload_location_logs',
        params: {
          'log_data': logData,
        },
      ).execute();

      if (response.error != null) {
        throw response.error!;
      }

      // Remove uploaded logs from pending
      _pendingLogs.removeRange(0, logsToUpload.length);
    } catch (e) {
      debugPrint('Error uploading location logs: $e');
      // Implement exponential backoff here if needed
    }
  }

  /// Record a specific site location
  Future<bool> recordSiteLocation({
    required String siteId,
    required Position position,
    String? notes,
  }) async {
    try {
      final response = await _supabase
          .from('site_locations')
          .upsert({
            'site_id': siteId,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'recorded_at': DateTime.now().toIso8601String(),
            'notes': notes,
          })
          .execute();

      return response.error == null;
    } catch (e) {
      debugPrint('Error recording site location: $e');
      return false;
    }
  }

  /// Request location permissions
  Future<bool> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Stop tracking
  void stopTracking() {
    _positionStream?.cancel();
    _uploadTimer?.cancel();
    _uploadPendingLogs(); // Upload any remaining logs
  }

  /// Dispose of resources
  void dispose() {
    stopTracking();
  }
}