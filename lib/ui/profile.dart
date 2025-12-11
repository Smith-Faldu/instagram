// lib/pages/profile.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_gate.dart'; // your signOut is here
import '../services/profile_services.dart';
import 'package:instagram/models/profile_model.dart';
import 'common_widget.dart';

// New import for chat screen
import 'chat_screen.dart';

class ProfilePage extends StatefulWidget {
  /// `userId` is the auth_id of the user to view.
  /// If null, we show the currently logged-in user's profile.
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final Future<ProfileData> _profileFuture;

  /// True when this page is showing the logged-in user's own profile.
  late final bool _isSelfProfile;

  /// auth_id of logged-in user (viewer)
  String? _currentUserId;

  /// auth_id of profile being viewed
  late final String? _profileOwnerId;

  @override
  void initState() {
    super.initState();

    final client = Supabase.instance.client;
    final authUser = client.auth.currentUser;
    _currentUserId = authUser?.id;

    debugPrint(
        '[ProfilePage:init] widget.userId=${widget.userId}, authUser=${authUser?.id}');

    if (authUser == null) {
      // Not logged in at all
      debugPrint('[ProfilePage:init] No auth user, treating as not logged in');
      _isSelfProfile = false;
      _profileOwnerId = widget.userId;

      if (widget.userId != null) {
        _profileFuture =
            ProfileService.instance.getProfileByAuthId(widget.userId!);
      } else {
        _profileFuture = Future.error('Not logged in');
      }
      return;
    }

    // Determine if this is our own profile or someone else's
    if (widget.userId == null || widget.userId == authUser.id) {
      // No userId passed OR userId matches current user → self profile
      _isSelfProfile = true;
      _profileOwnerId = authUser.id;
      debugPrint('[ProfilePage:init] Self profile. ownerId=$_profileOwnerId');
      _profileFuture =
          ProfileService.instance.getProfileByAuthId(authUser.id);
    } else {
      // Viewing someone else
      _isSelfProfile = false;
      _profileOwnerId = widget.userId;
      debugPrint(
          '[ProfilePage:init] Other profile. ownerId=$_profileOwnerId, current=$_currentUserId');
      _profileFuture =
          ProfileService.instance.getProfileByAuthId(widget.userId!);
    }
  }

  Future<void> _toggleFollowFromStream(bool isFollowing) async {
    if (_currentUserId == null || _profileOwnerId == null) return;

    try {
      if (isFollowing) {
        await ProfileService.instance.unfollowUser(
          currentUserId: _currentUserId!,
          targetUserId: _profileOwnerId!,
        );
      } else {
        await ProfileService.instance.followUser(
          currentUserId: _currentUserId!,
          targetUserId: _profileOwnerId!,
        );
      }
      // No setState here — the stream will update UI.
    } catch (e, st) {
      debugPrint('[ProfilePage._toggleFollowFromStream] error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update follow status')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _isSelfProfile
            ? null
            : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: FutureBuilder<ProfileData>(
          future: _profileFuture,
          builder: (context, snapshot) {
            final username =
            snapshot.hasData ? snapshot.data!.user.username : 'Profile';
            return Text(
              username,
              style: const TextStyle(fontWeight: FontWeight.w700),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
          ),
        ],
      ),
      body: FutureBuilder<ProfileData>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load profile\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final profile = snapshot.data!;
          final user = profile.user;
          final posts = profile.posts;
          final highlights = profile.highlights;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundImage: user.profilePicUrl.isNotEmpty
                                ? NetworkImage(user.profilePicUrl)
                                : null,
                            child: user.profilePicUrl.isEmpty
                                ? const Icon(Icons.person, size: 42)
                                : null,
                          ),
                          const SizedBox(width: 24),
                          _Stat(
                            label: 'Posts',
                            valueWidget: Text(user.postsCount.toString()),
                          ),
                          // Followers: use live stream if viewing a real profile owner id
                          _Stat(
                            label: 'Followers',
                            valueWidget: _isSelfProfile || _profileOwnerId == null
                                ? Text(_formatCount(user.followersCount))
                                : StreamBuilder<int>(
                              stream: ProfileService.instance
                                  .followersCountStream(
                                  targetUserId: _profileOwnerId!),
                              initialData: user.followersCount,
                              builder: (context, snap) {
                                final count = snap.data ?? 0;
                                return Text(_formatCount(count));
                              },
                            ),
                          ),
                          _Stat(
                            label: 'Following',
                            valueWidget: Text(_formatCount(user.followingCount)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.fullName.isNotEmpty ? user.fullName : user.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (user.bio.isNotEmpty)
                        Text(
                          user.bio,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      const SizedBox(height: 12),

                      // Action buttons differ for self vs other profile
                      Row(
                        children: [
                          Expanded(
                            child: _isSelfProfile
                                ? ElevatedButton(
                              onPressed: () {
                                // lightweight placeholder Edit profile screen (won't crash)
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      appBar: AppBar(title: const Text('Edit profile')),
                                      body: const Center(child: Text('Edit profile: TODO')),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black,
                                elevation: 0,
                              ),
                              child: const Text('Edit profile'),
                            )
                                : _profileOwnerId == null || _currentUserId == null
                                ? ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black,
                                elevation: 0,
                              ),
                              child: const Text('...'),
                            )
                                : StreamBuilder<bool>(
                              stream: ProfileService.instance.isFollowingStream(
                                currentUserId: _currentUserId!,
                                targetUserId: _profileOwnerId!,
                              ),
                              builder: (context, snap) {
                                // While the stream connects show a neutral disabled button
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return ElevatedButton(
                                    onPressed: null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[300],
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                    ),
                                    child: const Text('...'),
                                  );
                                }

                                final isFollowing = snap.data ?? false;

                                return ElevatedButton(
                                  onPressed: () =>
                                      _toggleFollowFromStream(isFollowing),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFollowing
                                        ? Colors.grey[300]
                                        : Colors.blue,
                                    foregroundColor: isFollowing
                                        ? Colors.black
                                        : Colors.white,
                                    elevation: 0,
                                  ),
                                  child:
                                  Text(isFollowing ? 'Following' : 'Follow'),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),

                          if (_isSelfProfile)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await AuthService.instance.signOut();
                                  if (!context.mounted) return;
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/login',
                                        (route) => false,
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.grey),
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text('Log out'),
                              ),
                            )
                          else
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  // Open chat screen with the profile owner
                                  if (_currentUserId == null || _profileOwnerId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not open chat')),
                                    );
                                    return;
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        meId: _currentUserId!,
                                        otherId: _profileOwnerId!,
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.grey),
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text('Message'),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        'Highlights',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 90,
                        child: highlights.isEmpty
                            ? const Center(
                          child: Text(
                            'No highlights yet',
                            style: TextStyle(fontSize: 12),
                          ),
                        )
                            : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: highlights.length,
                          itemBuilder: (_, index) {
                            final h = highlights[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundImage: h.previewUrl.isNotEmpty
                                        ? NetworkImage(
                                      h.previewUrl,
                                    )
                                        : null,
                                    child: h.previewUrl.isEmpty
                                        ? const Icon(Icons.photo)
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    h.caption.isNotEmpty ? h.caption : 'Highlight ${index + 1}',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: posts.isEmpty
                    ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No posts yet'),
                    ),
                  ),
                )
                    : SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (_, index) {
                      final post = posts[index];
                      return post.previewUrl.isNotEmpty
                          ? Image.network(
                        post.previewUrl,
                        fit: BoxFit.cover,
                      )
                          : const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.photo),
                      );
                    },
                    childCount: posts.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 4),
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final Widget valueWidget;

  const _Stat({
    required this.label,
    required this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          DefaultTextStyle(
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            child: valueWidget,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
