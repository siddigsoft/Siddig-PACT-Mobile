import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_file/open_file.dart';
import 'security/logger_service.dart';

class MMPFileService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _newFilesController = StreamController<List<Map<String, dynamic>>>.broadcast();
  StreamSubscription? _subscription;

  Stream<List<Map<String, dynamic>>> get onNewFiles => _newFilesController.stream;

  MMPFileService() {
    _initializeRealtimeSubscription();
  }

  void _initializeRealtimeSubscription() {
    _subscription = _supabase
      .from('mmp_files')
      .stream(primaryKey: ['id'])
      .listen((List<Map<String, dynamic>> data) {
        if (data.isNotEmpty) {
          _newFilesController.add(data);
        }
      });
  }

  Future<List<Map<String, dynamic>>> getMMPFiles() async {
    try {
      LoggerService.log('Fetching MMP files');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }

      final response = await _supabase
          .from('mmp_files')
          .select()
          .order('created_at', ascending: false);

      if (response is List) {
        return response.map((item) => Map<String, dynamic>.from(item)).toList();
      }

      return [];
    } catch (e) {
      LoggerService.log('Failed to fetch MMP files: ${e.toString()}', level: LogLevel.error);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMMPFileDetails(String fileId) async {
    try {
      final response = await _supabase
          .from('mmp_files')
          .select()
          .eq('id', fileId)
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      LoggerService.log('Failed to fetch MMP file details: ${e.toString()}', level: LogLevel.error);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingMMPFiles() async {
    try {
      final response = await _supabase
          .from('mmp_files')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List).map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      LoggerService.log('Failed to fetch pending MMP files: ${e.toString()}', level: LogLevel.error);
      rethrow;
    }
  }

  Future<void> downloadAndOpenFile(String fileId, String fileName) async {
    try {
      LoggerService.log('Starting file download: $fileName');
      
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
      }
      
      final bytes = await _supabase.storage.from('mmp_files').download(fileId);
      await file.writeAsBytes(bytes);
      
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
    } catch (e) {
      LoggerService.log('Error downloading/opening file: ${e.toString()}', level: LogLevel.error);
      rethrow;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _newFilesController.close();
  }
}
