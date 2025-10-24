import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/equipment.dart';
import '../models/safety_checklist.dart';
import '../models/safety_report.dart';
import '../models/task.dart';
import 'local_storage_service.dart';

class DataMigrationService {
  final LocalStorageService _localStorage;

  DataMigrationService(this._localStorage);

  /// Migrate all data from SharedPreferences to Hive
  Future<void> migrateAllData() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if migration has already been done
    final migrationDone = prefs.getBool('migration_completed') ?? false;
    if (migrationDone) {
      print('Data migration already completed');
      return;
    }

    print('Starting data migration from SharedPreferences to Hive...');

    try {
      await _migrateEquipmentData(prefs);
      await _migrateSafetyData(prefs);
      await _migrateTaskData(prefs);
      await _migrateAppSettings(prefs);

      // Mark migration as completed
      await prefs.setBool('migration_completed', true);
      print('Data migration completed successfully');
    } catch (e) {
      print('Error during data migration: $e');
      // Don't mark as completed if there was an error
    }
  }

  Future<void> _migrateEquipmentData(SharedPreferences prefs) async {
    const equipmentKey = 'equipment_data';
    final equipmentData = prefs.getString(equipmentKey);

    if (equipmentData != null) {
      try {
        final List<dynamic> jsonList = json.decode(equipmentData);
        final equipmentList = jsonList.map((json) => Equipment.fromJson(json)).toList();

        // Save all equipment to Hive
        for (final equipment in equipmentList) {
          await _localStorage.saveEquipment(equipment);
        }

        print('Migrated ${equipmentList.length} equipment items');
      } catch (e) {
        print('Error migrating equipment data: $e');
      }
    }
  }

  Future<void> _migrateSafetyData(SharedPreferences prefs) async {
    // Migrate safety checklists
    const checklistKey = 'safety_checklists';
    final checklistData = prefs.getString(checklistKey);

    if (checklistData != null) {
      try {
        final List<dynamic> jsonList = json.decode(checklistData);
        final checklists = jsonList.map((json) => SafetyChecklist.fromJson(json)).toList();

        // Convert checklists to safety reports for consistency
        for (final checklist in checklists) {
          final report = SafetyReport(
            id: checklist.id,
            title: 'Safety Checklist - ${checklist.location}',
            description: checklist.safetyNotes ?? checklist.additionalNotes ?? 'Safety checklist completed',
            status: 'submitted',
            createdAt: checklist.date,
            submittedAt: checklist.date,
            location: checklist.location,
            hazards: checklist.threatsEncountered ? ['Threats encountered'] : [],
            recommendations: checklist.areaSafe ? ['Area is safe'] : ['Area needs attention'],
            incidentType: 'safety_checklist',
            incidentDate: checklist.date,
          );

          await _localStorage.saveSafetyReport(report);
        }

        print('Migrated ${checklists.length} safety checklists');
      } catch (e) {
        print('Error migrating safety checklists: $e');
      }
    }

    // Migrate incident reports
    const incidentKey = 'incident_reports';
    final incidentData = prefs.getString(incidentKey);

    if (incidentData != null) {
      try {
        final List<dynamic> jsonList = json.decode(incidentData);
        final incidents = jsonList.map((json) => _convertIncidentReport(json)).toList();

        for (final incident in incidents) {
          await _localStorage.saveSafetyReport(incident);
        }

        print('Migrated ${incidents.length} incident reports');
      } catch (e) {
        print('Error migrating incident reports: $e');
      }
    }
  }

  SafetyReport _convertIncidentReport(Map<String, dynamic> json) {
    return SafetyReport(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Incident Report - ${json['type'] ?? 'Unknown'}',
      description: json['description'] ?? '',
      status: 'submitted',
      createdAt: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      submittedAt: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      location: json['location'] ?? 'Unknown',
      hazards: [json['type'] ?? 'Unknown'],
      recommendations: json['actionTaken'] != null ? [json['actionTaken']] : [],
      incidentType: json['type'],
      incidentDate: json['date'] != null ? DateTime.parse(json['date']) : null,
      witnesses: json['witnesses'] != null ? List<String>.from(json['witnesses']) : null,
      requiresImmediate: json['requiresImmediate'] ?? false,
      actionTaken: json['actionTaken'],
      mediaUrls: json['mediaUrls'] != null ? List<String>.from(json['mediaUrls']) : null,
      reportedBy: json['reportedBy'] ?? 'Unknown',
    );
  }

  Future<void> _migrateTaskData(SharedPreferences prefs) async {
    // Look for various task-related keys
    const taskKeys = [
      'tasks',
      'assigned_tasks',
      'task_data',
      'user_tasks'
    ];

    for (final key in taskKeys) {
      final taskData = prefs.getString(key);
      if (taskData != null) {
        try {
          final List<dynamic> jsonList = json.decode(taskData);
          final tasks = jsonList.map((json) => _convertTask(json)).toList();

          for (final task in tasks) {
            await _localStorage.saveTask(task);
          }

          print('Migrated ${tasks.length} tasks from key: $key');
        } catch (e) {
          print('Error migrating tasks from key $key: $e');
        }
      }
    }
  }

  Task _convertTask(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? json['name'] ?? 'Unnamed Task',
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : DateTime.now().add(const Duration(days: 7)),
      assignedTo: json['assignedTo'] ?? json['userId'] ?? 'unassigned',
      priority: json['priority'] ?? 'medium',
      metadata: json['metadata'],
    );
  }

  Future<void> _migrateAppSettings(SharedPreferences prefs) async {
    // Migrate common app settings
    final settingsKeys = [
      'theme_mode',
      'language',
      'notifications_enabled',
      'location_tracking_enabled',
      'sync_interval',
      'last_sync_time',
      'user_preferences'
    ];

    for (final key in settingsKeys) {
      final value = prefs.get(key);
      if (value != null) {
        await _localStorage.saveAppSetting(key, value);
        print('Migrated setting: $key = $value');
      }
    }
  }

  /// Force re-migration (useful for testing or fixing migration issues)
  Future<void> forceMigrate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('migration_completed', false);
    await migrateAllData();
  }

  /// Check if migration has been completed
  Future<bool> isMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('migration_completed') ?? false;
  }

  /// Clear migrated data (useful for testing)
  Future<void> clearMigratedData() async {
    // This would clear all Hive boxes - use with caution
    await Hive.deleteFromDisk();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('migration_completed', false);
    print('Cleared all migrated data');
  }
}