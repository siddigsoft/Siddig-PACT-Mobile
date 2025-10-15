import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';
import '../repositories/equipment_repository.dart';
import '../repositories/incident_repository.dart';
import '../repositories/safety_checklist_repository.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';

class SyncService {
  static const String syncTaskKey = 'syncData';
  final DatabaseService _databaseService;
  final SupabaseService _supabaseService;
  Timer? _syncTimer;

  SyncService(this._databaseService, this._supabaseService);

  Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
    await _setupPeriodicSync();
    _setupConnectivityListener();
  }

  Future<void> _setupPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      syncTaskKey,
      syncTaskKey,
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncData();
      }
    });
  }

  Future<void> syncData() async {
    if (_syncTimer?.isActive ?? false) return;

    _syncTimer = Timer(const Duration(seconds: 30), () async {
      final db = await _databaseService.database;

      // Create repositories
      final equipmentRepo = EquipmentRepository(
        database: db,
        supabaseService: _supabaseService,
      );
      final incidentRepo = IncidentRepository(
        database: db,
        supabaseService: _supabaseService,
      );
      final safetyChecklistRepo = SafetyChecklistRepository(
        database: db,
        supabaseService: _supabaseService,
      );

      // Sync all repositories
      await Future.wait([
        equipmentRepo.syncWithSupabase(),
        incidentRepo.syncWithSupabase(),
        safetyChecklistRepo.syncWithSupabase(),
      ]);
    });
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    switch (taskName) {
      case SyncService.syncTaskKey:
        final db = await DatabaseService().database;
        final supabase = SupabaseService();
        
        final syncService = SyncService(DatabaseService(), supabase);
        await syncService.syncData();
        break;
    }
    return true;
  });
}