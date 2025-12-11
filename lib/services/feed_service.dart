// lib/services/feed_service.dart
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';

import '../models/post_model.dart';

class FeedService {
  FeedService._();
  static final instance = FeedService._();

  final SupabaseClient _client = Supabase.instance.client;

  /// How far back a "story" should be considered valid.
  /// Default: 24 hours.
  Duration storyWindow = const Duration(hours: 24);

  /// Fetch home feed posts (excludes stories: post_type == 2)
  Future<List<FeedPost>> getHomeFeed({int limit = 50}) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw Exception('Not logged in');

    final authId = authUser.id;

    final followingIds = await _getFollowingIds(authId);

    if (!followingIds.contains(authId)) followingIds.add(authId);

    if (followingIds.isEmpty) return [];

    final postsRes = await _client
        .from('post')
        .select('''
          id,
          post_date_time,
          media,
          caption,
          likes_count,
          comment_count,
          share_count,
          post_for,
          post_type,
          post_as,
          is_saved,
          status,
          user_id,
          user:user_id (
            auth_id,
            username,
            full_name,
            profile_pic
          )
        ''')
        .inFilter('user_id', followingIds)
        .neq('post_type', 2) // exclude stories
        .eq('status', true)
        .order('post_date_time', ascending: false) // use post_date_time
        .limit(limit);

    if (postsRes == null) return [];

    final posts = (postsRes as List<dynamic>).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final userMap = (map['user'] as Map?)?.map((k, v) => MapEntry(k.toString(), v));
      final post = Post.fromMap(map);
      final feedUser = FeedUser(
        authId: (userMap?['auth_id'] ?? '') as String,
        username: (userMap?['username'] ?? '') as String,
        fullName: (userMap?['full_name'] ?? '') as String,
        profilePicUrl: (userMap?['profile_pic'] ?? '') as String,
      );

      // Use post.postDateTime (canonical) for feed ordering/time
      return FeedPost(post: post, user: feedUser, createdAt: post.postDateTime);
    }).toList();

    return posts;
  }

  /// Fetch stories (post_type == 2). Stories are posts within [storyWindow].
  Future<List<StoryGroup>> getStories({int limitPerUser = 20}) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw Exception('Not logged in');

    final authId = authUser.id;

    final followingIds = await _getFollowingIds(authId);
    if (!followingIds.contains(authId)) followingIds.add(authId);

    if (followingIds.isEmpty) return [];

    // cutoff based on post_date_time (canonical)
    final cutoff = DateTime.now().subtract(storyWindow).toUtc().toIso8601String();

    final storiesRes = await _client
        .from('post')
        .select('''
          id,
          post_date_time,
          media,
          caption,
          post_type,
          user_id,
          user:user_id (
            auth_id,
            username,
            full_name,
            profile_pic
          )
        ''')
        .inFilter('user_id', followingIds)
        .eq('post_type', 2) // stories only
        .gte('post_date_time', cutoff) // recent only using post_date_time
        .order('post_date_time', ascending: false)
        .limit(1000);

    if (storiesRes == null) return [];

    final rows = (storiesRes as List<dynamic>).map((r) => Map<String, dynamic>.from(r as Map)).toList();

    final items = rows.map((map) {
      final post = Post.fromMap(map); // expects post_date_time present
      final userMap = (map['user'] as Map?)?.map((k, v) => MapEntry(k.toString(), v));
      final feedUser = FeedUser(
        authId: (userMap?['auth_id'] ?? '') as String,
        username: (userMap?['username'] ?? '') as String,
        fullName: (userMap?['full_name'] ?? '') as String,
        profilePicUrl: (userMap?['profile_pic'] ?? '') as String,
      );

      return StoryItem(post: post, user: feedUser, createdAt: post.postDateTime);
    }).toList();

    // Group by user auth id
    final grouped = groupBy<StoryItem, String>(items, (it) => it.user.authId);

    final storyGroups = grouped.entries.map((entry) {
      final list = entry.value;
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // newest first
      return StoryGroup(
        user: list.first.user,
        stories: list.take(limitPerUser).map((s) => s.post).toList(),
        latestAt: list.first.createdAt,
      );
    }).toList();

    // order by latest story time desc
    storyGroups.sort((a, b) => b.latestAt.compareTo(a.latestAt));

    return storyGroups;
  }

  /// Optional: mark story seen (requires story_views table).
  Future<void> markStorySeen({required int postId}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    try {
      await _client.from('story_views').insert({
        'viewer_id': user.id,
        'post_id': postId,
      });
    } catch (e) {
      // Probably a duplicate key (viewer_id, post_id) -> already seen.
      // Ignore it. If you want, log e somewhere.
    }
  }

  Future<List<String>> _getFollowingIds(String authId) async {
    final res = await _client
        .from('following')
        .select('following_id')
        .eq('user_id', authId)
        .eq('status', true);

    if (res == null) return [];

    return (res as List<dynamic>)
        .map((r) => r['following_id'] as String)
        .toList();
  }
}


/// small models

class FeedUser {
  final String authId;
  final String username;
  final String fullName;
  final String profilePicUrl;

  FeedUser({
    required this.authId,
    required this.username,
    required this.fullName,
    required this.profilePicUrl,
  });
}

class FeedPost {
  final Post post;
  final FeedUser user;
  final DateTime createdAt;

  FeedPost({
    required this.post,
    required this.user,
    required this.createdAt,
  });
}

/// Story models

class StoryItem {
  final Post post;
  final FeedUser user;
  final DateTime createdAt;

  StoryItem({
    required this.post,
    required this.user,
    required this.createdAt,
  });
}

class StoryGroup {
  final FeedUser user;
  final List<Post> stories;
  final DateTime latestAt;

  StoryGroup({
    required this.user,
    required this.stories,
    required this.latestAt,
  });
}
