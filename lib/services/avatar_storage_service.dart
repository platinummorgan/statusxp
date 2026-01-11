import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for downloading external avatars and storing them in Supabase Storage
/// This avoids CORS issues when displaying avatars on web
class AvatarStorageService {
  final SupabaseClient _client;
  static const String _bucketName = 'avatars';

  AvatarStorageService(this._client);

  /// Downloads an avatar from an external URL and uploads it to Supabase Storage
  /// Returns the public URL of the uploaded avatar, or null if failed
  Future<String?> uploadExternalAvatar({
    required String externalUrl,
    required String userId,
    required String platform, // 'psn', 'xbox', 'steam'
  }) async {
    try {
      print('Downloading avatar from: $externalUrl');
      
      // Download the image
      final response = await http.get(Uri.parse(externalUrl));
      if (response.statusCode != 200) {
        print('Failed to download avatar: ${response.statusCode}');
        return null;
      }

      final imageBytes = response.bodyBytes;
      
      // Determine file extension from URL or content type
      String extension = 'png';
      final contentType = response.headers['content-type'];
      if (contentType?.contains('jpeg') ?? false) {
        extension = 'jpg';
      } else if (contentType?.contains('png') ?? false) {
        extension = 'png';
      }

      // Create a unique filename
      final filename = '${userId}_${platform}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final path = '$platform/$filename';

      print('Uploading avatar to Supabase Storage: $path');

      // Upload to Supabase Storage
      await _client.storage.from(_bucketName).uploadBinary(
        path,
        imageBytes,
        fileOptions: FileOptions(
          contentType: contentType ?? 'image/$extension',
          upsert: true, // Overwrite if exists
        ),
      );

      // Get the public URL
      final publicUrl = _client.storage.from(_bucketName).getPublicUrl(path);
      
      print('Avatar uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e, stackTrace) {
      print('Error uploading avatar: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Deletes an old avatar from storage
  Future<void> deleteAvatar(String publicUrl) async {
    try {
      // Extract path from public URL
      final uri = Uri.parse(publicUrl);
      final pathSegments = uri.pathSegments;
      
      // Find the bucket name in the path and extract everything after it
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        print('Could not extract path from URL: $publicUrl');
        return;
      }
      
      final path = pathSegments.sublist(bucketIndex + 1).join('/');
      
      print('Deleting avatar: $path');
      await _client.storage.from(_bucketName).remove([path]);
      print('Avatar deleted successfully');
    } catch (e) {
      print('Error deleting avatar: $e');
      // Don't throw - deletion failure shouldn't block the operation
    }
  }
}
