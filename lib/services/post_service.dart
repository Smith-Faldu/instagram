// lib/services/post_service.dart
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';

class PostService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Creates a post:
  /// - uses current auth user (auth_id)
  /// - uploads media to Storage bucket "posts"
  /// - inserts row into `public.post`
  /// - returns Post model
  Future<Post> createPost({
    required Uint8List mediaBytes,
    String? caption,
    int? postFor,
    int? postType,
    int? postAs,
    bool? isSaved,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    // Upload to Storage using auth_id as folder
    final mediaUrl = await _uploadMediaToStorage(
      userId: user.id,
      bytes: mediaBytes,
    );

    // Build media JSON (matches your `media jsonb` column)
    final mediaJ = mediaUrl;

    // use sensible defaults if caller passed nulls
    final safePostFor = postFor ?? 1;
    final safePostType = postType ?? 1;
    final safePostAs = postAs ?? 1;
    final safeIsSaved = isSaved ?? false;

    final insertData = {
      'user_id': user.id, // FK -> "user".auth_id
      'media': mediaJ,
      'caption': caption ?? '',
      'post_for': safePostFor,
      'post_type': safePostType,
      'post_as': safePostAs,
      'is_saved': safeIsSaved,
      // likes_count, comment_count, share_count, post_date_time, status
      // should use DB defaults where configured
    };

    // debug log so you can inspect
    print('PostService.createPost -> inserting: $insertData');

    final res = await _client
        .from('post')
        .insert(insertData)
        .select()
        .maybeSingle();

    if (res == null) {
      throw Exception('Failed to insert post (null response)');
    }
    return Post.fromMap(res);
  }

  /// Uploads file to Supabase Storage bucket "posts" and returns public URL
  Future<String> _uploadMediaToStorage({
    required String userId,
    required Uint8List bytes,
  }) async {
    final bucket = _client.storage.from('posts');

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = '$userId/$fileName'; // posts/<userId>/file.ext
    print('Uploading media to: $filePath');

    final resp = await bucket.uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(
        contentType: 'image/jpeg',
        upsert: false,
      ),
    );

    // uploadBinary either throws on failure or returns success response
    print('Uploaded media path: $filePath (upload response: $resp)');

    // If your bucket is private and you need signed url, change this to createSignedUrl
    final public = bucket.getPublicUrl(filePath);
    return public;
  }
}
