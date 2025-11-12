import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'security/logger_service.dart';

class MMPFileService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _newFilesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  StreamSubscription? _subscription;

  Stream<List<Map<String, dynamic>>> get onNewFiles =>
      _newFilesController.stream;

  MMPFileService() {
    _initializeRealtimeSubscription();
  }

  void _initializeRealtimeSubscription() {
    _subscription = _supabase
        .from('mmp_files')
        .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
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

      return response.map((item) => Map<String, dynamic>.from(item)).toList();

      return [];
    } catch (e) {
      LoggerService.log('Failed to fetch MMP files: ${e.toString()}',
          level: LogLevel.error);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMMPFileDetails(String fileId) async {
    try {
      final response =
          await _supabase.from('mmp_files').select().eq('id', fileId).single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      LoggerService.log('Failed to fetch MMP file details: ${e.toString()}',
          level: LogLevel.error);
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

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      LoggerService.log('Failed to fetch pending MMP files: ${e.toString()}',
          level: LogLevel.error);
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
      LoggerService.log('Error downloading/opening file: ${e.toString()}',
          level: LogLevel.error);
      rethrow;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _newFilesController.close();
  }

  // ===== LOCAL STORAGE METHODS =====

  /// Initialize Hive boxes for local storage
  static Future<void> initializeLocalStorage() async {
    await Hive.initFlutter();
  }

  /// Get MMP files cache box
  Future<Box> _getMMPFilesCacheBox() async {
    return await Hive.openBox('mmp_files_cache');
  }

  /// Get download queue box
  Future<Box> _getDownloadQueueBox() async {
    return await Hive.openBox('mmp_download_queue');
  }

  /// Get local files box
  Future<Box> _getLocalFilesBox() async {
    return await Hive.openBox('mmp_local_files');
  }

  /// Cache MMP files metadata locally
  Future<void> cacheMMPFilesLocally(List<Map<String, dynamic>> files) async {
    try {
      final box = await _getMMPFilesCacheBox();

      for (final file in files) {
        final fileId = file['id'];
        await box.put('file_$fileId', {
          'data': file,
          'cached_at': DateTime.now().toIso8601String(),
          'expires_at':
              DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        });
      }

      LoggerService.log('Cached ${files.length} MMP files locally');
    } catch (e) {
      LoggerService.log('Error caching MMP files locally: $e',
          level: LogLevel.error);
    }
  }

  /// Get cached MMP files
  Future<List<Map<String, dynamic>>> getCachedMMPFiles() async {
    try {
      final box = await _getMMPFilesCacheBox();
      final cachedFiles = <Map<String, dynamic>>[];

      for (final key in box.keys) {
        final cached = box.get(key);
        if (cached != null) {
          // Check if cache is expired
          final expiresAt = DateTime.parse(cached['expires_at']);
          if (DateTime.now().isAfter(expiresAt)) {
            await box.delete(key);
            continue;
          }

          cachedFiles.add(cached['data']);
        }
      }

      return cachedFiles;
    } catch (e) {
      LoggerService.log('Error getting cached MMP files: $e',
          level: LogLevel.error);
      return [];
    }
  }

  /// Get MMP files with local caching
  Future<List<Map<String, dynamic>>> getMMPFilesCached() async {
    try {
      // Try remote fetch first
      final remoteFiles = await getMMPFiles();

      // Cache the results
      await cacheMMPFilesLocally(remoteFiles);

      return remoteFiles;
    } catch (e) {
      // Fall back to cached data
      LoggerService.log('Remote MMP files fetch failed, using cache: $e',
          level: LogLevel.warning);
      return await getCachedMMPFiles();
    }
  }

  /// Cache individual file details
  Future<void> cacheFileDetailsLocally(
      String fileId, Map<String, dynamic> fileData) async {
    try {
      final box = await _getMMPFilesCacheBox();

      await box.put('file_$fileId', {
        'data': fileData,
        'cached_at': DateTime.now().toIso8601String(),
        'expires_at':
            DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      });
    } catch (e) {
      LoggerService.log('Error caching file details locally: $e',
          level: LogLevel.error);
    }
  }

  /// Get cached file details
  Future<Map<String, dynamic>?> getCachedFileDetails(String fileId) async {
    try {
      final box = await _getMMPFilesCacheBox();
      final cached = box.get('file_$fileId');

      if (cached == null) return null;

      // Check if cache is expired
      final expiresAt = DateTime.parse(cached['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) {
        await box.delete('file_$fileId');
        return null;
      }

      return cached['data'];
    } catch (e) {
      LoggerService.log('Error getting cached file details: $e',
          level: LogLevel.error);
      return null;
    }
  }

  /// Get file details with caching
  Future<Map<String, dynamic>> getMMPFileDetailsCached(String fileId) async {
    try {
      // Try remote fetch first
      final remoteData = await getMMPFileDetails(fileId);

      // Cache the result
      await cacheFileDetailsLocally(fileId, remoteData);

      return remoteData;
    } catch (e) {
      // Fall back to cached data
      final cachedData = await getCachedFileDetails(fileId);
      if (cachedData != null) {
        LoggerService.log('Using cached file details for: $fileId',
            level: LogLevel.info);
        return cachedData;
      }

      throw Exception('File details not available offline');
    }
  }

  /// Queue file download for later
  Future<void> queueFileDownload(String fileId, String fileName) async {
    try {
      final box = await _getDownloadQueueBox();

      await box.put('download_$fileId', {
        'file_id': fileId,
        'file_name': fileName,
        'queued_at': DateTime.now().toIso8601String(),
        'status': 'pending',
        'retry_count': 0,
      });

      LoggerService.log('Queued download for file: $fileName');
    } catch (e) {
      LoggerService.log('Error queuing file download: $e',
          level: LogLevel.error);
    }
  }

  /// Get pending downloads
  Future<List<Map<String, dynamic>>> getPendingDownloads() async {
    try {
      final box = await _getDownloadQueueBox();
      final pending = <Map<String, dynamic>>[];

      for (final key in box.keys) {
        final download = box.get(key);
        if (download != null && download['status'] == 'pending') {
          pending.add(download);
        }
      }

      return pending;
    } catch (e) {
      LoggerService.log('Error getting pending downloads: $e',
          level: LogLevel.error);
      return [];
    }
  }

  /// Process download queue
  Future<void> processDownloadQueue() async {
    try {
      final pendingDownloads = await getPendingDownloads();

      for (final download in pendingDownloads) {
        try {
          await downloadAndOpenFile(download['file_id'], download['file_name']);

          // Mark as completed
          final box = await _getDownloadQueueBox();
          await box.delete('download_${download['file_id']}');

          LoggerService.log(
              'Successfully downloaded queued file: ${download['file_name']}');
        } catch (e) {
          // Increment retry count
          final box = await _getDownloadQueueBox();
          download['retry_count'] = (download['retry_count'] ?? 0) + 1;

          if (download['retry_count'] > 3) {
            download['status'] = 'failed';
            LoggerService.log(
                'Download failed permanently for: ${download['file_name']}',
                level: LogLevel.error);
          } else {
            download['status'] = 'pending';
            LoggerService.log(
                'Download retry ${download['retry_count']} for: ${download['file_name']}',
                level: LogLevel.warning);
          }

          await box.put('download_${download['file_id']}', download);
        }
      }
    } catch (e) {
      LoggerService.log('Error processing download queue: $e',
          level: LogLevel.error);
    }
  }

  /// Download and cache file locally
  Future<String> downloadAndCacheFile(String fileId, String fileName) async {
    try {
      LoggerService.log('Downloading and caching file: $fileName');

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // Download file
      final bytes = await _supabase.storage.from('mmp_files').download(fileId);
      await file.writeAsBytes(bytes);

      // Cache file metadata
      final localFilesBox = await _getLocalFilesBox();
      await localFilesBox.put('local_$fileId', {
        'file_id': fileId,
        'file_name': fileName,
        'local_path': filePath,
        'file_size': bytes.length,
        'downloaded_at': DateTime.now().toIso8601String(),
        'last_accessed': DateTime.now().toIso8601String(),
      });

      LoggerService.log('File cached locally: $filePath');

      return filePath;
    } catch (e) {
      LoggerService.log('Error downloading and caching file: $e',
          level: LogLevel.error);
      rethrow;
    }
  }

  /// Open cached file if available
  Future<bool> openCachedFile(String fileId) async {
    try {
      final localFilesBox = await _getLocalFilesBox();
      final cachedFile = localFilesBox.get('local_$fileId');

      if (cachedFile != null) {
        final filePath = cachedFile['local_path'];
        final file = File(filePath);

        if (await file.exists()) {
          final result = await OpenFile.open(filePath);
          if (result.type == ResultType.done) {
            // Update last accessed time
            cachedFile['last_accessed'] = DateTime.now().toIso8601String();
            await localFilesBox.put('local_$fileId', cachedFile);

            LoggerService.log('Opened cached file: $filePath');
            return true;
          }
        } else {
          // File doesn't exist, remove from cache
          await localFilesBox.delete('local_$fileId');
        }
      }

      return false;
    } catch (e) {
      LoggerService.log('Error opening cached file: $e', level: LogLevel.error);
      return false;
    }
  }

  /// Download and open file with local caching
  Future<void> downloadAndOpenFileCached(String fileId, String fileName) async {
    try {
      // Try to open cached file first
      final openedFromCache = await openCachedFile(fileId);
      if (openedFromCache) {
        return;
      }

      // Not cached, download and cache
      await downloadAndCacheFile(fileId, fileName);

      // Now open it
      final opened = await openCachedFile(fileId);
      if (!opened) {
        throw Exception('Failed to open downloaded file');
      }
    } catch (e) {
      LoggerService.log('Error in cached download/open: $e',
          level: LogLevel.error);
      // Fall back to regular download
      await downloadAndOpenFile(fileId, fileName);
    }
  }

  /// Get locally cached files
  Future<List<Map<String, dynamic>>> getLocallyCachedFiles() async {
    try {
      final box = await _getLocalFilesBox();
      final cachedFiles = <Map<String, dynamic>>[];

      for (final key in box.keys) {
        final fileData = box.get(key);
        if (fileData != null) {
          cachedFiles.add(fileData);
        }
      }

      return cachedFiles;
    } catch (e) {
      LoggerService.log('Error getting locally cached files: $e',
          level: LogLevel.error);
      return [];
    }
  }

  /// Clear cached file data
  Future<void> clearFileCache() async {
    try {
      final cacheBox = await _getMMPFilesCacheBox();
      final queueBox = await _getDownloadQueueBox();
      final localBox = await _getLocalFilesBox();

      await cacheBox.clear();
      await queueBox.clear();

      // Optionally clear local files (be careful with this)
      // await localBox.clear();

      LoggerService.log('Cleared MMP file cache');
    } catch (e) {
      LoggerService.log('Error clearing file cache: $e', level: LogLevel.error);
    }
  }

  /// Get file cache statistics
  Future<Map<String, dynamic>> getFileCacheStats() async {
    try {
      final cacheBox = await _getMMPFilesCacheBox();
      final queueBox = await _getDownloadQueueBox();
      final localBox = await _getLocalFilesBox();

      final pendingDownloads = queueBox.keys.where((key) {
        final item = queueBox.get(key);
        return item != null && item['status'] == 'pending';
      }).length;

      final failedDownloads = queueBox.keys.where((key) {
        final item = queueBox.get(key);
        return item != null && item['status'] == 'failed';
      }).length;

      return {
        'cached_file_metadata': cacheBox.length,
        'pending_downloads': pendingDownloads,
        'failed_downloads': failedDownloads,
        'locally_cached_files': localBox.length,
      };
    } catch (e) {
      LoggerService.log('Error getting file cache stats: $e',
          level: LogLevel.error);
      return {};
    }
  }
}
