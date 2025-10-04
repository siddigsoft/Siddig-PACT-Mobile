import 'package:supabase_flutter/supabase_flutter.dart';

class MMPFileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMMPFiles() async {
    try {
      final response = await _supabase
          .from('mmp_files')
          .select()
          .order('created_at', ascending: false);

      if (response is List) {
        return response.map((item) {
          if (item is! Map<String, dynamic>) {
            // Convert the item to Map<String, dynamic>
            return Map<String, dynamic>.from(item as Map);
          }
          return item;
        }).toList();
      }

      throw Exception('Unexpected response format from Supabase');
    } catch (e, stackTrace) {
      print('Error fetching MMP files: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
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
