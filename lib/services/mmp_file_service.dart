import 'package:supabase_flutter/supabase_flutter.dart';
import 'security/logger_service.dart';

class MMPFileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMMPFiles() async {
    try {
      LoggerService.log('Fetching MMP files');

      // Check authentication status
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }
      LoggerService.log('User authenticated successfully');

      final response = await _supabase
          .from('mmp_files')
          .select()
          .order('created_at', ascending: false);

      LoggerService.log('Processing Supabase response');

      if (response is List) {
        final files = response.map((item) {
          if (item is! Map<String, dynamic>) {
            LoggerService.log('Converting non-Map item to Map format');
            return Map<String, dynamic>.from(item as Map);
          }
          return item;
        }).toList();

        LoggerService.log('MMP files fetch completed');
        return files;
      }

      throw Exception('Invalid response format from server');
    } catch (e, stackTrace) {
      LoggerService.log('Failed to fetch MMP files: ${e.toString()}', level: LogLevel.error);
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
