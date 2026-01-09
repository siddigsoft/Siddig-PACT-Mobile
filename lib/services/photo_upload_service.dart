// lib/services/photo_upload_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class PhotoUploadService {
  static Future<List<String>> uploadPhotos(
    String siteId,
    List<File> photos,
  ) async {
    final uploadedUrls = <String>[];

    for (final photo in photos) {
      try {
        final fileName = 'visit-photos/$siteId/${DateTime.now().millisecondsSinceEpoch}-${path.basename(photo.path)}';
        
        final bytes = await photo.readAsBytes();
        
        // Try site-visit-photos first, fallback to site-visit-media
        try {
          await Supabase.instance.client.storage
              .from('site-visit-photos')
              .uploadBinary(fileName, bytes);

          final publicUrl = Supabase.instance.client.storage
              .from('site-visit-photos')
              .getPublicUrl(fileName);
          uploadedUrls.add(publicUrl);
        } catch (e) {
          // Fallback to site-visit-media bucket
          await Supabase.instance.client.storage
              .from('site-visit-media')
              .uploadBinary(fileName, bytes);

          final publicUrl = Supabase.instance.client.storage
              .from('site-visit-media')
              .getPublicUrl(fileName);
          uploadedUrls.add(publicUrl);
        }

      } catch (e) {
        debugPrint('Error uploading photo: $e');
        // Continue with other photos
      }
    }

    return uploadedUrls;
  }
}

