// lib/services/profile_services.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instagram/models/profile_model.dart';
import 'package:instagram/models/search_model.dart';

class ProfileService {
  ProfileService._();
  static final instance = ProfileService._();

  final SupabaseClient _client = Supabase.instance.client;

  // ----------------------------------------------------------
  // FOLLOW SYSTEM
  // followers table:
  //   follower_id (uuid) = current user
  //   my_id       (uuid) = profile owner
  // ----------------------------------------------------------

  Future<bool> isFollowing({
    required String currentUserId,
    required String targetUserId,
  }) async {
    debugPrint(
        '[ProfileService.isFollowing] current=$currentUserId, target=$targetUserId');

    final res = await _client
        .from('followers')
        .select('id')
        .eq('follower_id', currentUserId)
        .eq('my_id', targetUserId)
        .maybeSingle();

    debugPrint('[ProfileService.isFollowing] result row=$res');
    return res != null;
  }

  /// Emits true when follower row exists for currentUser -> targetUser.
  /// We subscribe to the full table stream and filter in Dart for max compatibility.
  Stream<bool> isFollowingStream({
    required String currentUserId,
    required String targetUserId,
  }) {
    final baseStream = _client.from('followers').stream(primaryKey: ['id']);

    return baseStream.map((payload) {
      try {
        final rows = (payload as List).cast<Map<String, dynamic>>();
        final found = rows.any((r) =>
        r['follower_id']?.toString() == currentUserId &&
            r['my_id']?.toString() == targetUserId);
        return found;
      } catch (e, st) {
        debugPrint('[ProfileService.isFollowingStream] parsing error: $e\n$st');
        return false;
      }
    });
  }

  /// Emits the current follower count (number of rows where my_id == targetUserId).
  Stream<int> followersCountStream({required String targetUserId}) {
    final baseStream = _client.from('followers').stream(primaryKey: ['id']);

    return baseStream.map((payload) {
      try {
        final rows = (payload as List).cast<Map<String, dynamic>>();
        final count = rows.where((r) => r['my_id']?.toString() == targetUserId).length;
        return count;
      } catch (e, st) {
        debugPrint(
            '[ProfileService.followersCountStream] parsing error: $e\n$st');
        return 0;
      }
    });
  }

  // --- follow user (use upsert + select for modern API) ---
  Future<bool> followUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    debugPrint(
      '[ProfileService.followUser] current=$currentUserId -> target=$targetUserId',
    );

    try {
      // upsert will insert or update on conflict; use select() to return rows if needed
      await _client
          .from('followers')
          .upsert({
        'follower_id': currentUserId,
        'my_id': targetUserId,
      })
          .select();
      debugPrint('[ProfileService.followUser] success');
      return true;
    } catch (e, st) {
      debugPrint('[ProfileService.followUser] error: $e\n$st');
      return false;
    }
  }

  // --- unfollow user (await delete chain directly, no .execute()) ---
  Future<bool> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    debugPrint(
      '[ProfileService.unfollowUser] current=$currentUserId X target=$targetUserId',
    );

    try {
      await _client
          .from('followers')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('my_id', targetUserId);
      debugPrint('[ProfileService.unfollowUser] success');
      return true;
    } catch (e, st) {
      debugPrint('[ProfileService.unfollowUser] error: $e\n$st');
      return false;
    }
  }

  // ----------------------------------------------------------
  // SEARCH USERS
  // ----------------------------------------------------------

  Future<List<UserSearchResult>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final q = query.trim();

    final res = await _client
        .from('user')
        .select('auth_id, username, full_name, profile_pic')
        .or('username.ilike.%$q%')
        .limit(100);

    debugPrint('DEBUG searchUsers raw: $res');

    final list = (res as List<dynamic>).map((row) {
      return UserSearchResult(
        authId: row['auth_id'] as String,
        username: (row['username'] ?? '') as String,
        fullName: (row['full_name'] ?? '') as String,
        profilePicUrl: (row['profile_pic'] ?? '') as String,
      );
    }).toList();

    return list;
  }

  // ----------------------------------------------------------
  // PROFILE DATA
  // ----------------------------------------------------------

  Future<ProfileData> getProfileByAuthId(String authId) async {
    // 1) USER
    final userRes = await _client
        .from('user')
        .select('''
          auth_id,
          username,
          full_name,
          bio,
          profile_pic,
          post_count,
          followers_count,
          following_count
        ''')
        .eq('auth_id', authId)
        .maybeSingle();

    if (userRes == null) {
      throw Exception('User not found');
    }

    final user = UserProfileData(
      authId: userRes['auth_id'] as String,
      username: (userRes['username'] ?? '') as String,
      fullName: (userRes['full_name'] ?? '') as String,
      bio: (userRes['bio'] ?? '') as String,
      profilePicUrl: (userRes['profile_pic'] ?? '') as String,
      postsCount: (userRes['post_count'] ?? 0) as int,
      followersCount: (userRes['followers_count'] ?? 0) as int,
      followingCount: (userRes['following_count'] ?? 0) as int,
    );

    // 2) POSTS of that user
    final postsRes = await _client
        .from('post')
        .select('id, media')
        .eq('user_id', authId)
        .neq('post_type', 2)
        .order('created_at', ascending: false);

    final posts = (postsRes as List<dynamic>).map((row) {
      return PostThumbData(
        id: row['id'] as int,
        previewUrl: _extractPreviewUrl(row['media']),
      );
    }).toList();

    // 3) HIGHLIGHTS (need caption + related post media)
    final highlightsRes = await _client
        .from('highlights')
        .select('id, caption, post_id')
        .eq('user_id', authId)
        .order('created_at', ascending: false);

    final highlightRows = highlightsRes as List<dynamic>;
    final postIds =
    highlightRows.map((e) => e['post_id']).whereType<int>().toList();

    Map<int, String> mediaByPostId = {};

    if (postIds.isNotEmpty) {
      final highlightPostsRes = await _client
          .from('post')
          .select('id, media')
          .inFilter('id', postIds)
          .eq('user_id', authId);

      for (final row in highlightPostsRes as List<dynamic>) {
        mediaByPostId[row['id'] as int] = row['media'] as String;
      }
    }

    final highlights = highlightRows.map((row) {
      final postId = row['post_id'] as int?;
      final media = postId != null ? mediaByPostId[postId] : null;

      return HighlightData(
        id: row['id'] as int,
        caption: (row['caption'] ?? '') as String,
        previewUrl: _extractPreviewUrl(media),
      );
    }).toList();

    return ProfileData(
      user: user,
      posts: posts,
      highlights: highlights,
    );
  }

  Future<ProfileData> getCurrentUserProfile() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Not logged in');
    }
    return getProfileByAuthId(currentUser.id);
  }

  /// media column is a string that may be:
  /// - a single URL
  /// - a JSON array of URLs (index 0 is preview)
  /// - a JSON array of objects with `url`
  String _extractPreviewUrl(dynamic media) {
    if (media == null) return '';
    if (media is! String) return '';

    final value = media.trim();
    if (value.isEmpty) return '';

    // Try parse JSON
    try {
      final decoded = jsonDecode(value);
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is String) return first;
        if (first is Map && first['url'] is String) return first['url'] as String;
      }
    } catch (_) {
      // not JSON, just fall-through and treat as plain URL
    }

    // assume direct URL
    return value;
  }
// -------------------------
// ADDED: Helpers required by EditProfilePage
// -------------------------

  /// Returns the raw user row for the currently authenticated user, or null.
  Future<Map<String, dynamic>?> getCurrentUserRow() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final res = await _client
        .from('user')
        .select()
        .eq('auth_id', user.id)
        .maybeSingle();

    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  /// Uploads avatar image to 'avatar' bucket and returns public URL (or null on error).
  Future<String?> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    String ext = 'jpg',
  }) async {
    try {
      // IMPORTANT: your bucket name is "avatar", not "avatars".
      final bucket = _client.storage.from('avatar');

      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '$userId/$fileName';

      if (kDebugMode) {
        print('[ProfileService.uploadAvatar] uploading -> $path');
      }

      // Upload
      await bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$ext',
          upsert: true,
        ),
      );

      // Get public URL
      final publicUrl = bucket.getPublicUrl(path);

      if (kDebugMode) {
        print('[ProfileService.uploadAvatar] publicUrl -> $publicUrl');
      }

      return publicUrl;
    } catch (e, st) {
      debugPrint('[ProfileService.uploadAvatar] error: $e\n$st');
      return null;
    }
  }

  /// Update profile fields in the `user` table. Returns updated row or null.
  Future<Map<String, dynamic>?> updateProfile({
    required Map<String, dynamic> fields,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Prevent accidental password updates
    fields.remove('password');

    final res = await _client
        .from('user')
        .update(fields)
        .eq('auth_id', user.id)
        .select()
        .maybeSingle();

    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

} // end ProfileService

/// Alias class so existing code using `ProfileServices.instance` keeps working.
/// This simply reuses the same singleton instance above.
class ProfileServices {
  ProfileServices._();
  static final instance = ProfileService.instance;
}
