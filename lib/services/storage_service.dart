import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final supabase = Supabase.instance.client;

  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Upload file
  Future<String> uploadFile(File file, String bucket, {String? folder}) async {
    try {
      final fileName = path.basename(file.path);
      final filePath = folder != null ? '$folder/$fileName' : fileName;

      await supabase.storage.from(bucket).upload(
            filePath,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      final String publicUrl =
          supabase.storage.from(bucket).getPublicUrl(filePath);
      return publicUrl;
    } on StorageException catch (e) {
      if (kDebugMode) {
        print('Storage error: ${e.message}');
      }
      throw StorageException('Failed to upload file: ${e.message}');
    } catch (e) {
      throw StorageException('An unexpected error occurred while uploading');
    }
  }

  // Download file
  Future<File> downloadFile(
      String path, String bucket, String destinationPath) async {
    try {
      final bytes = await supabase.storage.from(bucket).download(path);
      final file = File(destinationPath);
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      throw StorageException('Failed to download file');
    }
  }

  // Delete file
  Future<void> deleteFile(String path, String bucket) async {
    try {
      await supabase.storage.from(bucket).remove([path]);
    } catch (e) {
      throw StorageException('Failed to delete file');
    }
  }

  // List files in a bucket/folder
  Future<List<FileObject>> listFiles(String bucket, {String? folder}) async {
    try {
      final List<FileObject> files =
          await supabase.storage.from(bucket).list(path: folder);
      return files;
    } catch (e) {
      throw StorageException('Failed to list files');
    }
  }
}
