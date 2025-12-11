// lib/pages/conversation_list.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../services/message_service.dart';
import 'chat_screen.dart';
import '../utils/responsive.dart';

class ConversationList extends StatefulWidget {
  const ConversationList({super.key});

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  final svc = MessageService();
  final SupabaseClient _client = Supabase.instance.client;
  String? _me;
  List<Map<String, dynamic>> _rows = [];
  StreamSubscription? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _me = _client.auth.currentUser?.id;
    if (_me != null) {
      _load();
      _sub = svc.subscribeConversations(_me!).listen((_) {
        // simple reload for list updates — cheap but reliable
        _load();
      });
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    if (_me == null) return;
    try {
      final rows = await svc.getConversations(_me!);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      debugPrint('ConversationList.load error: $e');
      if (mounted) setState(() {
        _rows = [];
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _formatDateTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return DateFormat.Hm().format(dt); // 14:35
    } else if (diff.inDays < 7) {
      return DateFormat.E().format(dt); // Mon
    } else {
      return DateFormat('dd MMM').format(dt); // 22 Feb
    }
  }

  @override
  Widget build(BuildContext context) {
    final R = Responsive(context);

    if (_me == null) {
      return const Center(child: Text('Not logged in'));
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rows.isEmpty) {
      return const Center(child: Text('No conversations'));
    }

    return Padding(
      padding: R.pagePadding(),
      child: ListView.separated(
        itemCount: _rows.length,
        separatorBuilder: (_, __) => SizedBox(height: R.hp(0.5)),
        itemBuilder: (context, i) {
          final r = _rows[i];

          // message row may contain either sender_id/reciver_id or other keys depending on your query
          final sender = (r['sender_id'] ?? '') as String;
          final reciver = (r['reciver_id'] ?? '') as String;
          final other = (sender == _me) ? reciver : sender;

          // optional nicer metadata if your query returns them
          final otherUsername = (r['other_username'] ?? r['username'] ?? '') as String;
          final otherPic = (r['other_pic'] ?? r['profile_pic'] ?? r['actor_pic']) as String?;
          final lastMsg = (r['message'] ?? '') as String;
          final lastAt = (r['created_at'] ?? '') as String;
          final unread = (sender != _me) && ((r['seen'] as int? ?? 0) == 0);

          final subtitle = lastMsg;
          final titleText = otherUsername.isNotEmpty ? otherUsername : 'User • ${other.length >= 6 ? other.substring(0, 6) : other}';

          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(meId: _me!, otherId: other)),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: R.hp(1), horizontal: R.wp(1.5)),
              child: Row(
                children: [
                  // avatar
                  CircleAvatar(
                    radius: R.avatarSize() / 2,
                    backgroundImage: (otherPic != null && otherPic.isNotEmpty) ? NetworkImage(otherPic) : null,
                    child: (otherPic == null || otherPic.isEmpty) ? const Icon(Icons.person) : null,
                  ),
                  SizedBox(width: R.wp(3)),
                  // title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: TextStyle(
                            fontSize: R.scaledText(16),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: R.hp(0.3)),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: R.scaledText(13),
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: R.wp(3)),
                  // time + unread
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lastAt.isEmpty ? '' : _formatDateTime(lastAt),
                        style: TextStyle(fontSize: R.scaledText(11), color: Colors.grey[600]),
                      ),
                      SizedBox(height: R.hp(0.6)),
                      if (unread)
                        Container(
                          width: R.wp(3.8),
                          height: R.wp(3.8),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
