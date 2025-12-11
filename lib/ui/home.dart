// lib/ui/home.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/feed_service.dart';
import '../services/post_service.dart';
// import '../models/post_model.dart';
import 'common_widget.dart';

class PostCardWidget extends StatefulWidget {
  final FeedPost feedPost;

  const PostCardWidget({super.key, required this.feedPost});

  @override
  State<PostCardWidget> createState() => _PostCardWidgetState();
}

class _PostCardWidgetState extends State<PostCardWidget> {
  late bool _isLiked;
  late int _likesCount;
  bool _inFlight = false;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();

    // Seed values from FeedPost model (Post has likesCount)
    final p = widget.feedPost.post;
    _likesCount = p.likesCount;

    // We don't have likedBy in Post model, so start as not liked.
    // If you later add a liked_by column to the returned payload, you can
    // set initial liked state here by checking that array.
    _isLiked = false;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.yMMMd().format(dt);
  }

  Future<void> _onLikeTap() async {
    final cur = _currentUserId;
    if (cur == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like posts')),
      );
      return;
    }

    if (_inFlight) return;

    // optimistic update
    setState(() {
      _inFlight = true;
      _isLiked = !_isLiked;
      _likesCount = _isLiked ? _likesCount + 1 : (_likesCount - 1 >= 0 ? _likesCount - 1 : 0);
    });

    final action = await PostService.instance.toggleLikeRpc(postId: widget.feedPost.post.id);

    if (action == null) {
      // rollback on error
      if (!mounted) return;
      setState(() {
        _isLiked = !_isLiked;
        _likesCount = _isLiked ? _likesCount + 1 : (_likesCount - 1 >= 0 ? _likesCount - 1 : 0);
        _inFlight = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update like. Please try again.')),
      );
      return;
    }

    // Server says 'liked' or 'unliked'. Reconcile minimal state.
    if (!mounted) return;
    setState(() {
      if (action == 'liked') {
        _isLiked = true;
      } else if (action == 'unliked') {
        _isLiked = false;
        // ensure no negative counts
        if (_likesCount < 0) _likesCount = 0;
      }
      _inFlight = false;
    });

    // If you want authoritative counts, subscribe to realtime post stream or re-fetch the post.
  }

  @override
  Widget build(BuildContext context) {
    final feedPost = widget.feedPost;
    final p = feedPost.post;
    final u = feedPost.user;
    final preview = p.media.isNotEmpty ? p.media : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage:
                u.profilePicUrl.isNotEmpty ? NetworkImage(u.profilePicUrl) : null,
                child: u.profilePicUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.username.isNotEmpty ? u.username : u.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (u.fullName.isNotEmpty && u.username.isNotEmpty)
                      Text(
                        u.fullName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {},
              ),
            ],
          ),
        ),
        AspectRatio(
          aspectRatio: 4 / 5,
          child: preview.isNotEmpty
              ? Image.network(preview, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12))
              : const ColoredBox(color: Colors.black12),
        ),
        Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
          child: Row(
            children: [
              // Like button wired up
              IconButton(
                icon: _inFlight
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : Colors.black),
                onPressed: _onLikeTap,
              ),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.send_outlined),
                onPressed: () {},
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                onPressed: () {},
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            "$_likesCount likes",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black),
              children: [
                TextSpan(
                  text: "${u.username.isNotEmpty ? u.username : u.fullName} ",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: p.caption),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            "View comments",
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            _timeAgo(feedPost.createdAt),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// StoryCircleWidget and HomePage remain unchanged from your original file.
// (I left them as-is — only PostCardWidget swapped to stateful + like logic)

class StoryCircleWidget extends StatelessWidget {
  final FeedUser user;
  final bool hasUnseen;
  final VoidCallback onTap;

  const StoryCircleWidget({
    super.key,
    required this.user,
    required this.onTap,
    this.hasUnseen = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: hasUnseen
                    ? const LinearGradient(colors: [Colors.orange, Colors.pink])
                    : null,
                color: hasUnseen ? null : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(38),
              ),
              child: CircleAvatar(
                radius: 32,
                backgroundImage:
                user.profilePicUrl.isNotEmpty ? NetworkImage(user.profilePicUrl) : null,
                child: user.profilePicUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 70,
              child: Text(
                user.username.isNotEmpty ? user.username : user.fullName,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// HomePage unchanged — it will render the updated PostCardWidget.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<FeedPost>> _feedFuture;
  late Future<List<StoryGroup>> _storiesFuture;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    _feedFuture = FeedService.instance.getHomeFeed(limit: 50);
    _storiesFuture = FeedService.instance.getStories(limitPerUser: 10);
  }

  Future<void> _refresh() async {
    setState(() {
      _loadAll();
    });
    await Future.wait([_feedFuture, _storiesFuture]);
  }

  void _openStoryGroup(StoryGroup group) async {
    for (final p in group.stories) {
      try {
        await FeedService.instance.markStorySeen(postId: p.id);
      } catch (_) {}
    }

    if (group.stories.isEmpty) return;
    final first = group.stories.first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(group.user.username)),
          body: Center(
            child: first.media.isNotEmpty
                ? Image.network(first.media, fit: BoxFit.contain)
                : const Text('No story media'),
          ),
        ),
      ),
    );
    setState(() {
      _storiesFuture = FeedService.instance.getStories(limitPerUser: 10);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Instagram",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
          IconButton(
            icon: const Icon(Icons.messenger_outline),
            onPressed: () {
              Navigator.pushNamed(context, '/messages');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: FutureBuilder<List<StoryGroup>>(
                future: _storiesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 126, child: Center(child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Failed to load stories: ${snapshot.error}'),
                    );
                  }
                  final groups = snapshot.data ?? [];
                  if (groups.isEmpty) return const SizedBox.shrink();

                  return SizedBox(
                    height: 126,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final g = groups[index];
                        final hasUnseen = true;
                        return StoryCircleWidget(
                          user: g.user,
                          hasUnseen: hasUnseen,
                          onTap: () => _openStoryGroup(g),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Feed posts
            SliverList(
              delegate: SliverChildListDelegate.fixed([
                FutureBuilder<List<FeedPost>>(
                  future: _feedFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Failed to load feed: ${snapshot.error}'),
                      );
                    }
                    final posts = snapshot.data ?? [];
                    if (posts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No posts yet. Follow someone or post something.')),
                      );
                    }

                    return Column(
                      children: posts.map((p) => PostCardWidget(feedPost: p)).toList(),
                    );
                  },
                ),
                const SizedBox(height: 48),
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}
