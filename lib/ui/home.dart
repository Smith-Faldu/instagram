// lib/ui/home.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/feed_service.dart';
// import '../models/post_model.dart';
import 'common_widget.dart';

// Reuse your PostCard and StoryCircle widgets but modified to accept models.
// For clarity I keep small copies here adapted for FeedPost/StoryGroup usage.
// You can replace these with your existing ones if you want.

class PostCardWidget extends StatelessWidget {
  final FeedPost feedPost;

  const PostCardWidget({super.key, required this.feedPost});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.yMMMd().format(dt);
  }

  @override
  Widget build(BuildContext context) {
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
                    // optional: show full name or nothing
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
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {},
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
            "${p.likesCount} likes",
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
    // mark all posts in this story group as seen (best-effort)
    for (final p in group.stories) {
      try {
        await FeedService.instance.markStorySeen(postId: p.id);
      } catch (_) {}
    }

    // For now just show a simple page that displays the first story image
    // You can replace this with a true story viewer (timers, swiping).
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
    // After return, refresh stories to update seen state
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
                        // Determine unseen state: naive, you can improve by using story_views
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
