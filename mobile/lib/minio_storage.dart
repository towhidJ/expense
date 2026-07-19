import 'dart:convert';
import 'app_state.dart' show supabase;

/// Client for the `minio-storage` edge function — uploads/deletes go through
/// it so the MinIO secret key never lives on the device. Same base64-in-JSON
/// shape ai_service.dart already uses for images, so no extra `http`
/// dependency is needed; downloads stay plain public URLs (see the function).
class MinioStorage {
  static Future<String> upload({
    required String bucket,
    required String path,
    required List<int> bytes,
    required String contentType,
  }) async {
    final res = await supabase.functions.invoke(
      'minio-storage',
      body: {
        'action': 'upload',
        'bucket': bucket,
        'path': path,
        'contentType': contentType,
        'base64': base64Encode(bytes),
      },
    );
    final data = res.data;
    if (data is Map && data['error'] != null) throw Exception(data['error']);
    if (data is Map && data['publicUrl'] is String) return data['publicUrl'] as String;
    throw Exception('Unexpected upload response');
  }

  static Future<void> remove(String bucket, List<String> paths) async {
    final res = await supabase.functions.invoke(
      'minio-storage',
      body: {'action': 'delete', 'bucket': bucket, 'paths': paths},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) throw Exception(data['error']);
  }
}
