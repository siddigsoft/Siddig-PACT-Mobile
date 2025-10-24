import 'package:hive/hive.dart';
import '../models/task.dart';
import '../models/equipment.dart';
import '../models/safety_report.dart';
import '../models/user_profile.dart';

class LocalStorageService {
  static const String tasksBox = 'tasks';
  static const String equipmentsBox = 'equipments';
  static const String safetyReportsBox = 'safetyReports';
  static const String userProfilesBox = 'userProfiles';
  static const String appSettingsBox = 'appSettings';
  static const String mapDataBox = 'mapData';

  // Tasks CRUD
  Future<void> saveTask(Task task) async {
    final box = Hive.box(tasksBox);
    await box.put(task.id, task.toJson());
  }

  Task? getTask(String id) {
    final box = Hive.box(tasksBox);
    final json = box.get(id);
    return json != null ? Task.fromJson(json) : null;
  }

  List<Task> getAllTasks() {
    final box = Hive.box(tasksBox);
    return box.values.map((json) => Task.fromJson(json)).toList();
  }

  Future<void> deleteTask(String id) async {
    final box = Hive.box(tasksBox);
    await box.delete(id);
  }

  // Equipments CRUD
  Future<void> saveEquipment(Equipment equipment) async {
    final box = Hive.box(equipmentsBox);
    await box.put(equipment.id, equipment.toJson());
  }

  Equipment? getEquipment(String id) {
    final box = Hive.box(equipmentsBox);
    final json = box.get(id);
    return json != null ? Equipment.fromJson(json) : null;
  }

  List<Equipment> getAllEquipments() {
    final box = Hive.box(equipmentsBox);
    return box.values.map((json) => Equipment.fromJson(json)).toList();
  }

  Future<void> deleteEquipment(String id) async {
    final box = Hive.box(equipmentsBox);
    await box.delete(id);
  }

  // Safety Reports CRUD
  Future<void> saveSafetyReport(SafetyReport report) async {
    final box = Hive.box(safetyReportsBox);
    await box.put(report.id, report.toJson());
  }

  SafetyReport? getSafetyReport(String id) {
    final box = Hive.box(safetyReportsBox);
    final json = box.get(id);
    return json != null ? SafetyReport.fromJson(json) : null;
  }

  List<SafetyReport> getAllSafetyReports() {
    final box = Hive.box(safetyReportsBox);
    return box.values.map((json) => SafetyReport.fromJson(json)).toList();
  }

  Future<void> deleteSafetyReport(String id) async {
    final box = Hive.box(safetyReportsBox);
    await box.delete(id);
  }

  // User Profile CRUD
  Future<void> saveUserProfile(UserProfile profile) async {
    final box = Hive.box(userProfilesBox);
    await box.put(profile.userId, profile.toJson());
  }

  UserProfile? getUserProfile(String userId) {
    final box = Hive.box(userProfilesBox);
    final json = box.get(userId);
    return json != null ? UserProfile.fromJson(json) : null;
  }

  Future<void> deleteUserProfile(String userId) async {
    final box = Hive.box(userProfilesBox);
    await box.delete(userId);
  }

  // App Settings
  Future<void> saveAppSetting(String key, dynamic value) async {
    final box = Hive.box(appSettingsBox);
    await box.put(key, value);
  }

  dynamic getAppSetting(String key) {
    final box = Hive.box(appSettingsBox);
    return box.get(key);
  }

  // Map Data (for offline map caching)
  Future<void> saveMapData(String key, dynamic data) async {
    final box = Hive.box(mapDataBox);
    await box.put(key, data);
  }

  dynamic getMapData(String key) {
    final box = Hive.box(mapDataBox);
    return box.get(key);
  }

  // Sync status tracking
  Future<void> markAsSynced(String boxName, String id) async {
    final box = Hive.box('${boxName}_sync');
    await box.put(id, true);
  }

  bool isSynced(String boxName, String id) {
    final box = Hive.box('${boxName}_sync');
    return box.get(id, defaultValue: false);
  }

  // Bulk operations for sync
  Future<void> saveMultipleTasks(List<Task> tasks) async {
    final box = Hive.box(tasksBox);
    final Map<String, Map<String, dynamic>> taskMap = {for (var task in tasks) task.id: task.toJson()};
    await box.putAll(taskMap);
  }

  Future<void> saveMultipleEquipments(List<Equipment> equipments) async {
    final box = Hive.box(equipmentsBox);
    final Map<String, Map<String, dynamic>> equipmentMap = {for (var eq in equipments) eq.id: eq.toJson()};
    await box.putAll(equipmentMap);
  }

  Future<void> saveMultipleSafetyReports(List<SafetyReport> reports) async {
    final box = Hive.box(safetyReportsBox);
    final Map<String, Map<String, dynamic>> reportMap = {for (var report in reports) report.id: report.toJson()};
    await box.putAll(reportMap);
  }
}