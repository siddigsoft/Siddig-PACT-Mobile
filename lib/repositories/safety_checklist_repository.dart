import 'package:sqflite/sqflite.dart';
import '../models/safety_checklist.dart';
import '../services/supabase_service.dart';
import 'base_repository.dart';

class SafetyChecklistRepository extends BaseRepository<SafetyChecklist> {
  SafetyChecklistRepository({
    required Database database,
    required SupabaseService supabaseService,
  }) : super(
          database: database,
          supabaseService: supabaseService,
          tableName: 'safety_checklists',
        );

  @override
  Map<String, dynamic> toMap(SafetyChecklist item) => item.toJson();

  @override
  SafetyChecklist fromMap(Map<String, dynamic> map) => SafetyChecklist.fromJson(map);

  Stream<List<SafetyChecklist>> subscribeToUpdates() {
    return supabaseService
        .subscribeToTable(tableName)
        .map((events) => events.map((e) => fromMap(e)).toList());
  }

  Future<List<SafetyChecklist>> getPendingChecklists() async {
    final maps = await database.query(
      tableName,
      where: 'completed = ?',
      whereArgs: [0],
    );
    return maps.map((map) => fromMap(map)).toList();
  }
}