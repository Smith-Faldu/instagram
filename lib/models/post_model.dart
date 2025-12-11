// lib/models/post_model.dart
class Post {
  final int id;
  final String userId; // auth_id (uuid)
  final DateTime postDateTime;
  final String media;
  final String caption;
  final int likesCount;
  final int commentCount;
  final int shareCount;
  final int postFor;
  final int postType;
  final int postAs;
  final bool isSaved;
  final bool status;

  Post({
    required this.id,
    required this.userId,
    required this.postDateTime,
    required this.media,
    required this.caption,
    required this.likesCount,
    required this.commentCount,
    required this.shareCount,
    required this.postFor,
    required this.postType,
    required this.postAs,
    required this.isSaved,
    required this.status,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    // handle both String and DateTime from Supabase
    final rawDate = map['post_date_time'];
    late final DateTime postDateTime;
    if (rawDate is String) {
      postDateTime = DateTime.parse(rawDate);
    } else if (rawDate is DateTime) {
      postDateTime = rawDate;
    } else {
      // fallback to now if DB didn't give a value
      postDateTime = DateTime.now();
    }
    // parse ints with fallbacks
    int parseInt(dynamic v, int fallback) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is String) {
        return int.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    bool parseBool(dynamic v, bool fallback) {
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is String) return v.toLowerCase() == 'true';
      return fallback;
    }

    return Post(
      id: parseInt(map['id'], 0),
      userId: (map['user_id'] ?? '') as String,
      postDateTime: postDateTime,
      media: map['media'] as String? ?? '',
      caption: (map['caption'] ?? '') as String,
      likesCount: parseInt(map['likes_count'], 0),
      commentCount: parseInt(map['comment_count'], 0),
      shareCount: parseInt(map['share_count'], 0),
      postFor: parseInt(map['post_for'], 1),
      postType: parseInt(map['post_type'], 1),
      postAs: parseInt(map['post_as'], 1),
      isSaved: parseBool(map['is_saved'], false),
      status: parseBool(map['status'], true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'post_date_time': postDateTime.toIso8601String(),
      'media': media,
      'caption': caption,
      'likes_count': likesCount,
      'comment_count': commentCount,
      'share_count': shareCount,
      'post_for': postFor,
      'post_type': postType,
      'post_as': postAs,
      'is_saved': isSaved,
      'status': status,
    };
  }
}
