
class ProfileData {
  final UserProfileData user;
  final List<PostThumbData> posts;
  final List<HighlightData> highlights;

  ProfileData({
    required this.user,
    required this.posts,
    required this.highlights,
  });
}

class UserProfileData {
  final String authId;
  final String username;
  final String fullName;
  final String bio;
  final String profilePicUrl;
  final int postsCount;
  final int followersCount;
  final int followingCount;

  UserProfileData({
    required this.authId,
    required this.username,
    required this.fullName,
    required this.bio,
    required this.profilePicUrl,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
  });
}

class PostThumbData {
  final int id;
  final String previewUrl;

  PostThumbData({
    required this.id,
    required this.previewUrl,
  });
}

class HighlightData {
  final int id;
  final String caption;
  final String previewUrl;

  HighlightData({
    required this.id,
    required this.caption,
    required this.previewUrl,
  });
}