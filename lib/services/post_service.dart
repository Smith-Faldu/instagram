// lib/services/post_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';

















class PostService {
  PostService._();
  static final instance = PostService._();

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
    if (kDebugMode) print('PostService.createPost -> inserting: $insertData');

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
    if (kDebugMode) print('Uploading media to: $filePath');

    final resp = await bucket.uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(
        contentType: 'image/jpeg',
        upsert: false,
      ),
    );

    if (kDebugMode) print('Uploaded media path: $filePath (upload response: $resp)');

    // If your bucket is private and you need signed url, change this to createSignedUrl
    final public = bucket.getPublicUrl(filePath);
    return public;
  }

  // -------------------------
  // Likes RPC
  // -------------------------

  /// Calls the RPC toggle_like_rpc(p_post_id) which toggles like for the
  /// currently authenticated user. Server reads auth.uid().
  ///
  /// Returns 'liked' or 'unliked' on success, null on error.
  Future<String?> toggleLikeRpc({ required int postId }) async {
    try {
      // Call RPC. Different SDK versions return different shapes:
      // - Map<String,dynamic>
      // - List<Map<String,dynamic>> with one element
      // - sometimes a raw JSON string
      final rpcRaw = await _client.rpc('toggle_like_rpc', params: {'p_post_id': postId});

      dynamic payload = rpcRaw;
      if (rpcRaw is List && rpcRaw.isNotEmpty) {
        payload = rpcRaw.first;
      }

      if (payload == null) return null;

      if (payload is Map<String, dynamic>) {
        final action = payload['action'];
        if (action is String) return action;
        // sometimes jsonb comes back as nested map under 'toggle_like_rpc' key; try to find
        for (final v in payload.values) {
          if (v is Map && v.containsKey('action')) {
            final a = v['action'];
            if (a is String) return a;
          }
        }
        return null;
      }

      if (payload is String) {
        // attempt to parse JSON string
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map && decoded['action'] is String) {
            return decoded['action'] as String;
          }
        } catch (_) {
          return null;
        }
      }

      return null;
    } catch (e, st) {
      if (kDebugMode) {
        print('[PostService.toggleLikeRpc] error: $e\n$st');
      }
      return null;
    }
  }
// -------------------------
// Comments (minimal helpers)
// -------------------------

  /// Returns list of comments for the post ordered by created_at ascending.
  Future<List<Map<String, dynamic>>> getComments({ required int postId }) async {
    try {
      final res = await _client
          .from('comments')
      // return basic comment fields + commenter info using foreign select
          .select('id, comment, created_at, commenter_id, commenter:commenter_id(username, profile_pic)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      if (res == null) return [];
      // res is List<dynamic> of maps
      return (res as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      if (kDebugMode) print('[PostService.getComments] error: $e');
      return [];
    }
  }

  /// Inserts a comment row and returns the inserted row map (or null on failure).
  Future<Map<String, dynamic>?> addComment({ required int postId, required String text }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    if (text.trim().isEmpty) return null;

    try {
      final payload = {
        'post_id': postId,
        'comment': text.trim(),
        'commenter_id': user.id,
      };

      final res = await _client
          .from('comments')
          .insert(payload)
          .select('id, comment, created_at, commenter_id, commenter:commenter_id(username, profile_pic)')
          .maybeSingle();

      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      if (kDebugMode) print('[PostService.addComment] error: $e');
      rethrow;
    }
  }

}
