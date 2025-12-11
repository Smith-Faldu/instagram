// lib/NotificationsPage.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'common_widget.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
                (route) => false,
          ),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: const NotificationsList(),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }
}

/// Local simple model for UI
class _Notif {
  final int id;
  final String userId;
  final String? actorId;
  final String? actorUsername;
  final String? actorPic;
  final String type;
  final Map<String, dynamic>? payload;
  final bool isRead;
  final DateTime createdAt;

  _Notif({
    required this.id,
    required this.userId,
    this.actorId,
    this.actorUsername,
    this.actorPic,
    required this.type,
    this.payload,
    required this.isRead,
    required this.createdAt,
  });

  factory _Notif.fromMap(Map<String, dynamic> m) {
    DateTime dt;
    final raw = m['created_at'];
    if (raw is String) {
      dt = DateTime.tryParse(raw) ?? DateTime.now();
    } else if (raw is DateTime) {
      dt = raw;
    } else {
      dt = DateTime.now();
    }

    Map<String, dynamic>? payload;
    final p = m['payload'];
    if (p is Map) {
      payload = Map<String, dynamic>.from(p);
    } else if (p is String) {
      try {
        final decoded = jsonDecode(p);
        if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        payload = null;
      }
    }

    return _Notif(
      id: (m['id'] is int) ? m['id'] as int : int.tryParse('${m['id'] ?? 0}') ?? 0,
      userId: (m['user_id'] ?? '') as String,
      actorId: (m['actor_id'] ?? '') as String?,
      actorUsername: (m['actor_username'] ?? '') as String?,
      actorPic: (m['actor_pic'] ?? '') as String?,
      type: (m['type'] ?? '') as String,
      payload: payload,
      isRead: (m['is_read'] == true),
      createdAt: dt,
    );
  }
}

class NotificationsList extends StatefulWidget {
  const NotificationsList({super.key});

  @override
  State<NotificationsList> createState() => _NotificationsListState();
}

class _NotificationsListState extends State<NotificationsList> {
  final SupabaseClient _client = Supabase.instance.client;
  String? _currentUserId;
  List<_Notif> _items = [];
  bool _loading = true;
  StreamSubscription<dynamic>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _currentUserId = _client.auth.currentUser?.id;
    _init();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    if (_currentUserId == null) {
      setState(() {
        _loading = false;
        _items = [];
      });
      return;
    }

    await _fetchInitial();
    _subscribeRealtime();
  }

  Future<void> _fetchInitial() async {
    try {
      // _currentUserId is non-null here
      final cur = _currentUserId!;
      final res = await _client
          .from('notifications')
          .select('id, user_id, actor_id, actor_username, actor_pic, type, payload, is_read, created_at')
          .eq('user_id', cur)
          .order('created_at', ascending: false)
          .limit(50);

      if (!mounted) return;

      final list = <_Notif>[];
      if (res is List) {
        for (final e in res) {
          if (e is Map) list.add(_Notif.fromMap(Map<String, dynamic>.from(e)));
        }
      }

      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _items = [];
          _loading = false;
        });
      }
      debugPrint('[Notifications] fetchInitial error: $e\n$st');
    }
  }

  void _subscribeRealtime() {
    if (_currentUserId == null) return;
    final cur = _currentUserId!;

    final stream = _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', cur);

    _realtimeSub = stream.listen((payload) {
      try {
        if (payload == null) return;
        final rows = (payload is List) ? payload.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
        final parsed = rows.map((r) => _Notif.fromMap(Map<String, dynamic>.from(r))).toList();
        parsed.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (!mounted) return;
        setState(() {
          _items = parsed;
        });
      } catch (e, st) {
        debugPrint('[Notifications] realtime parsing error: $e\n$st');
      }
    }, onError: (err) {
      debugPrint('[Notifications] realtime stream error: $err');
    });
  }

  Future<void> _markRead(int id) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);
      final idx = _items.indexWhere((it) => it.id == id);
      if (idx != -1) {
        final old = _items[idx];
        setState(() {
          _items[idx] = _Notif(
            id: old.id,
            userId: old.userId,
            actorId: old.actorId,
            actorUsername: old.actorUsername,
            actorPic: old.actorPic,
            type: old.type,
            payload: old.payload,
            isRead: true,
            createdAt: old.createdAt,
          );
        });
      }
    } catch (e) {
      debugPrint('[Notifications] markRead error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not mark read')));
      }
    }
  }

  String _actionText(_Notif n) {
    switch (n.type) {
      case 'like':
        return 'liked your post.';
      case 'comment':
        return n.payload != null && n.payload!['text'] != null
            ? 'commented: "${n.payload!['text']}"'
            : 'commented on your post.';
      case 'follow':
        return 'started following you.';
      case 'mention':
        return 'mentioned you.';
      default:
        return 'did something.';
    }
  }

  IconData _iconFor(_Notif n) {
    switch (n.type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'mention':
        return Icons.alternate_email;
      default:
        return Icons.notifications;
    }
  }

  Color _iconColorFor(_Notif n) {
    switch (n.type) {
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.blue;
      case 'follow':
        return Colors.green;
      case 'mention':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRow(_Notif n) {
    final avatar = (n.actorPic != null && n.actorPic!.isNotEmpty) ? NetworkImage(n.actorPic!) : null;
    final subtitle = _actionText(n);
    final timeAgo = _timeAgo(n.createdAt);

    return InkWell(
      onTap: () async {
        if (!n.isRead) await _markRead(n.id);

        final pid = n.payload != null && n.payload!['post_id'] != null ? n.payload!['post_id'].toString() : null;
        if (pid != null && pid.isNotEmpty) {
          // navigate if you have route for post
          // Navigator.pushNamed(context, '/post', arguments: {'postId': int.parse(pid)});
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: avatar,
                  child: avatar == null ? const Icon(Icons.person) : null,
                ),
                if (n.type != 'follow')
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _iconColorFor(n),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        _iconFor(n),
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600),
                  children: [
                    TextSpan(
                      text: n.actorUsername ?? (n.actorId != null ? n.actorId!.substring(0,6) : 'Someone'),
                      style: TextStyle(fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w700),
                    ),
                    TextSpan(
                      text: ' $subtitle ',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.normal),
                    ),
                    TextSpan(
                      text: timeAgo,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            if (n.payload != null && n.payload!['post_thumb'] != null)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  image: DecorationImage(
                    image: NetworkImage(n.payload!['post_thumb']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 24),
          Center(child: Text('No notifications yet')),
        ],
      );
    }

    return ListView.builder(
      itemCount: _items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Recent",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }
        final n = _items[index - 1];
        return _buildRow(n);
      },
    );
  }
}
