import 'package:supabase_flutter/supabase_flutter.dart';

class MMPFileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMMPFiles() async {
    final response = await _supabase
        .from('mmp_files')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> getMMPFileDetails(String fileId) async {
    final response = await _supabase
        .from('mmp_files')
        .select()
        .eq('id', fileId)
        .single();

    return response;
  }

  Future<List<Map<String, dynamic>>> getPendingMMPFiles() async {
    final response = await _supabase
        .from('mmp_files')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
