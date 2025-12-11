// lib/ui/home.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/feed_service.dart';
import '../services/post_service.dart';
import 'common_widget.dart';
import 'package:instagram/ui/comments_sheet.dart';
import '../utils/responsive.dart';

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

    final p = widget.feedPost.post;
    _likesCount = p.likesCount;
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

    // Save previous state for safe rollback
    final prevLiked = _isLiked;
    final prevCount = _likesCount;

    // optimistic update
    setState(() {
      _inFlight = true;
      _isLiked = !_isLiked;
      _likesCount = _isLiked ? _likesCount + 1 : (_likesCount - 1 >= 0 ? _likesCount - 1 : 0);
    });

    try {
      final action = await PostService.instance.toggleLikeRpc(postId: widget.feedPost.post.id);

      if (action == null) {
        // rollback
        if (!mounted) return;
        setState(() {
          _isLiked = prevLiked;
          _likesCount = prevCount;
          _inFlight = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update like. Please try again.')),
        );
        return;
      }

      // Reconcile with server response (ensure consistent state)
      if (!mounted) return;
      setState(() {
        if (action == 'liked') {
          _isLiked = true;
        } else if (action == 'unliked') {
          _isLiked = false;
        }
        // don't try to infer exact count from RPC; keep optimistic count (server eventual consistency)
        if (_likesCount < 0) _likesCount = 0;
        _inFlight = false;
      });
    } catch (e) {
      // rollback on unexpected error
      if (!mounted) return;
      setState(() {
        _isLiked = prevLiked;
        _likesCount = prevCount;
        _inFlight = false;
      });
      if (kDebugMode) debugPrint('toggle like error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update like. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedPost = widget.feedPost;
    final p = feedPost.post;
    final u = feedPost.user;
    final preview = p.media.isNotEmpty ? p.media : '';

    final R = Responsive(context);
    final avatarRadius = R.avatarSize() / 2;
    final horizontalPadding = R.isDesktop ? 24.0 : 12.0;
    final imageAspect = R.isDesktop ? (16 / 9) : (4 / 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
          EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundImage:
                u.profilePicUrl.isNotEmpty ? NetworkImage(u.profilePicUrl) : null,
                child: u.profilePicUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              SizedBox(width: R.wp(3)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.username.isNotEmpty ? u.username : u.fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: R.scaledText(16),
                      ),
                    ),
                    if (u.fullName.isNotEmpty && u.username.isNotEmpty)
                      Text(
                        u.fullName,
                        style: TextStyle(
                          fontSize: R.scaledText(13),
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert, size: R.scaledText(20)),
                onPressed: () {},
              ),
            ],
          ),
        ),
        AspectRatio(
          aspectRatio: imageAspect,
          child: preview.isNotEmpty
              ? Image.network(
            preview,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12),
          )
              : const ColoredBox(color: Colors.black12),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: _inFlight
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : Colors.black),
                onPressed: _onLikeTap,
              ),
              IconButton(
                icon: Icon(Icons.mode_comment_outlined, size: R.scaledText(22)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => Padding(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                      child: CommentsSheet(postId: widget.feedPost.post.id),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.send_outlined, size: R.scaledText(22)),
                onPressed: () {},
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.bookmark_border, size: R.scaledText(22)),
                onPressed: () {},
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Text(
            "$_likesCount likes",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.scaledText(14)),
          ),
        ),
        SizedBox(height: R.hp(0.4)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.black, fontSize: R.scaledText(14)),
              children: [
                TextSpan(
                  text: "${u.username.isNotEmpty ? u.username : u.fullName} ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: p.caption),
              ],
            ),
          ),
        ),
        SizedBox(height: R.hp(0.4)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Text(
            "View comments",
            style: TextStyle(color: Colors.grey, fontSize: R.scaledText(14)),
          ),
        ),
        SizedBox(height: R.hp(0.4)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Text(
            _timeAgo(feedPost.createdAt),
            style: TextStyle(color: Colors.grey, fontSize: R.scaledText(13)),
          ),
        ),
        SizedBox(height: R.hp(2)),
      ],
    );
  }
}

// StoryCircleWidget and HomePage remain unchanged from your original file,
// except they now use Responsive where PostCardWidget expects it to exist.

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
    final R = Responsive(context);
    final radius = R.isDesktop ? 40.0 : 32.0;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: R.wp(2.5), vertical: R.hp(0.8)),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(R.wp(0.8)),
              decoration: BoxDecoration(
                gradient: hasUnseen ? const LinearGradient(colors: [Colors.orange, Colors.pink]) : null,
                color: hasUnseen ? null : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(radius + 6),
              ),
              child: CircleAvatar(
                radius: radius,
                backgroundImage: user.profilePicUrl.isNotEmpty ? NetworkImage(user.profilePicUrl) : null,
                child: user.profilePicUrl.isEmpty ? Icon(Icons.person, size: R.scaledText(18)) : null,
              ),
            ),
            SizedBox(height: R.hp(0.6)),
            SizedBox(
              width: 70,
              child: Text(
                user.username.isNotEmpty ? user.username : user.fullName,
                style: TextStyle(fontSize: R.scaledText(12)),
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
    final R = Responsive(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Instagram",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: R.scaledText(18)),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.notifications_none, size: R.scaledText(22)),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
          IconButton(
            icon: Icon(Icons.messenger_outline, size: R.scaledText(22)),
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
                    return SizedBox(height: R.hp(16), child: const Center(child: CircularProgressIndicator()));
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
                    height: R.hp(16),
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

            SliverList(
              delegate: SliverChildListDelegate.fixed([
                FutureBuilder<List<FeedPost>>(
                  future: _feedFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: EdgeInsets.only(top: R.hp(4)),
                        child: const Center(child: CircularProgressIndicator()),
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
                      return Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No posts yet. Follow someone or post something.', style: TextStyle(fontSize: R.scaledText(14)))),
                      );
                    }

                    return Column(
                      children: posts.map((p) => PostCardWidget(feedPost: p)).toList(),
                    );
                  },
                ),
                SizedBox(height: R.hp(6)),
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}
