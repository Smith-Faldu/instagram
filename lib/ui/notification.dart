// lib/NotificationsPage.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'common_widget.dart';
import '../services/profile_services.dart';

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
      } catch (_) {}
    }

    return _Notif(
      id: (m['id'] is int) ? m['id'] : int.tryParse('${m['id'] ?? 0}') ?? 0,
      userId: m['user_id'] ?? '',
      actorId: m['actor_id'],
      actorUsername: m['actor_username'],
      actorPic: m['actor_pic'],
      type: m['type'] ?? '',
      payload: payload,
      isRead: m['is_read'] == true,
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
  StreamSubscription? _realtimeSub;

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
      });
      return;
    }

    await _fetchInitial();
    _subscribeRealtime();
  }

  Future<void> _fetchInitial() async {
    try {
      final cur = _currentUserId!;
      final res = await _client
          .from('notifications')
          .select()
          .eq('user_id', cur)
          .order('created_at', ascending: false)
          .limit(50);

      if (!mounted) return;

      final List<_Notif> notifs = [];
      if (res is List) {
        for (final e in res) {
          if (e is Map) {
            notifs.add(_Notif.fromMap(Map<String, dynamic>.from(e)));
          }
        }
      }

      setState(() {
        _items = notifs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _items = [];
        _loading = false;
      });
    }
  }

  // ⛔ FIXED REALTIME HANDLER
  void _subscribeRealtime() {
    if (_currentUserId == null) return;

    final stream = _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', _currentUserId!);

    _realtimeSub = stream.listen((event) {
      try {
        final rows = _extractRows(event);
        if (rows.isEmpty) return;

        final parsed = rows
            .map((e) => _Notif.fromMap(e))
            .toList();

        final map = {for (var x in _items) x.id: x};
        for (final n in parsed) map[n.id] = n;

        final merged = map.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        setState(() {
          _items = merged;
        });
      } catch (e) {
        debugPrint("Realtime parse error: $e");
      }
    });
  }

  // ⛔ UNIVERSAL PAYLOAD EXTRACTOR
  List<Map<String, dynamic>> _extractRows(dynamic event) {
    final List<Map<String, dynamic>> out = [];

    if (event == null) return out;

    if (event is List) {
      for (final e in event) {
        if (e is Map) out.add(Map<String, dynamic>.from(e));
      }
      return out;
    }

    if (event is Map) {
      out.add(Map<String, dynamic>.from(event));
      return out;
    }

    // Handle SupabaseStreamEvent
    try {
      final dynamic rec = event.newRecord ?? event.record ?? event.payload;
      if (rec != null) {
        if (rec is Map) out.add(Map<String, dynamic>.from(rec));
        if (rec is List) {
          for (final e in rec) {
            if (e is Map) out.add(Map<String, dynamic>.from(e));
          }
        }
      }
    } catch (_) {}

    return out;
  }

  Future<void> _markRead(int id) async {
    try {
      await _client.from('notifications').update({'is_read': true}).eq('id', id);

      final idx = _items.indexWhere((e) => e.id == id);
      if (idx != -1) {
        final n = _items[idx];
        _items[idx] = _Notif(
          id: n.id,
          userId: n.userId,
          actorId: n.actorId,
          actorUsername: n.actorUsername,
          actorPic: n.actorPic,
          type: n.type,
          payload: n.payload,
          isRead: true,
          createdAt: n.createdAt,
        );
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const Center(child: Text("No notifications yet"));
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, i) => _buildRow(_items[i]),
    );
  }

  Widget _buildRow(_Notif n) {
    // Show follow-back button only for follow notifications with a valid actorId
    final Widget? trailingWidget = (n.type.toLowerCase() == 'follow' && n.actorId != null)
        ? FollowBackButton(actorId: n.actorId!)
        : null;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
        n.actorPic != null ? NetworkImage(n.actorPic!) : null,
        child: n.actorPic == null ? const Icon(Icons.person) : null,
      ),
      title: Text(n.actorUsername ?? "Someone"),
      subtitle: Text(n.type),
      onTap: () => _markRead(n.id),
      trailing: trailingWidget,
    );
  }
}

class FollowBackButton extends StatefulWidget {
  final String actorId;
  const FollowBackButton({super.key, required this.actorId});

  @override
  State<FollowBackButton> createState() => _FollowBackButtonState();
}

class _FollowBackButtonState extends State<FollowBackButton> {
  final SupabaseClient _client = Supabase.instance.client;
  String? _me;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _me = _client.auth.currentUser?.id;
  }

  @override
  Widget build(BuildContext context) {
    if (_me == null || widget.actorId == _me) return const SizedBox();

    return StreamBuilder<bool?>(
      stream: ProfileService.instance.isFollowingStream(
        currentUserId: _me!,
        targetUserId: widget.actorId,
      ),
      builder: (context, snap) {
        final following = snap.data;

        return ElevatedButton(
          onPressed: _loading
              ? null
              : () async {
            setState(() => _loading = true);
            try {
              if (following == true) {
                await ProfileService.instance.unfollowUser(
                  currentUserId: _me!,
                  targetUserId: widget.actorId,
                );
              } else {
                await ProfileService.instance.followUser(
                  currentUserId: _me!,
                  targetUserId: widget.actorId,
                );
              }
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          child: Text(following == true ? "Following" : "Follow"),
        );
      },
    );
  }
}
